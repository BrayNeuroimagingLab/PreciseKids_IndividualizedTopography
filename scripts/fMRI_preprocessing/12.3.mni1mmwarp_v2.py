#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Feb  8 14:34:36 2023

@author: kgodfrey

export PATH=$PATH:/Users/kgodfrey/antsbin
export PATH=$PATH:/Users/kgodfrey/abin
export PATH=$PATH:/Applications/Convert3DGUI.app/contents/bin

cd /Users/kgodfrey/Documents/preciseKIDS/ME_Preprocessing


***** READ ME!!!! *****

this script will take your 4D preprocessed image and move it to 2mm MNI space (templateimage)

first, in 'bold2mmMNIwarp' it warps your bold image to 1mm MNI
it does this by providing how bold reference was warped to structural (OCRefBbr.h5; from 'ocpreprocess')
and then by providing how structural was warped to 2mm MNI ("transformT1wFltmeantoMNI"; from 'strct_preprocess')

second, it gets the reference volume from the warped bold (split step), and binarizes to make a mask (mathsmask step)

this code will likely work improperly if the tedana step is taken out of the workflow, particularly mathsmask

Update Log V2 (Shefali):
Add session if statements within each for loop, no need to process 1 session at a time for each subject


"""

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

import os
import time
import nipype.interfaces.ants as ants
import nipype.interfaces.afni as afni
import nipype.interfaces.fsl as fsl
from nipype.interfaces.fsl import ImageMaths
from nipype.interfaces.fsl import ExtractROI
import pandas as pd
import shutil
from shutil import copyfile
from nipype.interfaces.c3 import C3dAffineTool


#what directory are your images saved in?
dir_start = '/Volumes/Prckids/'

#path to 1mm MNI template
templateimage = '/Users/shefalirai/Desktop/prckids_preprocess/mni/mni_icbm152_t1_tal_nlin_asym_09c.nii'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = [7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,
               31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,53,54,55,56]
#participants =[9] #003C no YT2
#participants =[52] #024P ses-6 not ses-4

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#for loop with new if statement to find where anat folder with T1w image is located
all_sessions = [0,1,2,3] #all sessions for participant

#what tasks do you want to run this on?
tasks = ['task-DORA1', 'task-DORA2', 'task-RX1', 'task-RX2', 'task-YT1', 'task-YT2']

#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-4']

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = True

#name of subfolder where outputs are saved 
warpfolder = 'mni1mmwarp/'

#name of regression folder where inputs are saved
regfolder = 'regression/'

#name of log book that output is saved to
logname = 'xepi_mni1mmwarp.txt'
#do you want to save to the log book?
savelog = True

#name of summary log book saved to
summarylogname = 'xepi_mni1mmwarp.txt'
#do you want to save to the summary log book?
savesummarylog = True

#what steps do you want to run?
steps = ['summary','bold1mmMNIwarp','split','mathsmask','filecleanup']
#summary = get summary output of preprocessing decisions
#bold1mmMNIwarp = warp bold to 1mm MNI
#split = get reference volume for warped timeseries
#mathsmask = make reference volume into a mask
#filecleanup = remove files if desired


"""**********************"""
"""BOLD2mmMNIWARP OPTIONS"""
"""**********************"""
#input bold timeseries file you want to warp to MNI 
inputimage = 'OCDetFltRegNewM'

#bold image following warp to MNI
warpedimage = 'OCDetFltRegNewM1mmMNIWarp'

#warpmatrixstrc = how T1w was referenced to MNI space, generated in 'strct2mmMNIwarp' step 
warpmatrixstrc = 'transformT1wFltmeantoMNI.h5' 

#warpmatrixfunc = how the EPI reference volume was converted to T1, generated in 'ocpreprocess' script
warpmatrixfunc = 'OCRefBbr.h5' #EPIref to T1mean

"""*************"""
"""SPLIT OPTIONS"""
"""*************"""

#this is the file we will be splitting, to extract the reference volume
splitinput = 'OCDetFltRegNewM1mmMNIWarp'

#this is the name of the output reference volume, will be binarized to make a mask 
splitoutput = 'OCDetFltRegNewM1mmMNIWarpRef'

#what file has the reference volumes? 
RefVolFile = '/Volumes/Prckids/xrefvolumes2.csv'

"""*****************"""
"""MATHSMASK OPTIONS"""
"""*****************"""

#this is a single volume indexed by mathsmaskvol, which will be binarized to make a mask
mathmaskinput = 'OCDetFltRegNewM1mmMNIWarpRef'

#what is the output mask called?
mathmaskoutput = 'OCDetFltRegNewM1mmMNIWarpRef_mask'


"""*******************"""
"""FILECLEANUP OPTIONS"""
"""*******************"""

#keeping these files (especially the warped 4D prior to resample)
#will likely exhaust local storage
#however you may wish to skip this step to facilitate debugging

#what files would you like to remove? 
to_remove = ['OCDetFltRegNewM1mmMNIWarpRef']



import os
import time
import nipype.interfaces.ants as ants
import nipype.interfaces.afni as afni
import nipype.interfaces.fsl as fsl
import shutil
from shutil import copyfile
import pandas as pd

#get the current time
totaltimer = time.time()

#everything in log gets saved to the logbook. Text often gets appended to log
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())   

#everything in log gets saved to the logbook. Text often gets appended to log
summarylog = ["*************************************************"]
summarylog.append('Starting log for ' + time.ctime())   

endit = False

for k in steps:
    
    if (k == 'summary') & (endit == False):
        a = -1
        for i in participants:
             person = participant_folders[i]
             #person = i
             for j in all_sessions: 
                 ses = sorted(os.listdir(dir_start + person))
                 session = ses[j]
                 x = "Warp to 1mm MNI starting for: " + person
                 print(x)
                 summarylog.append(x)
                 
                 x = "You are warping to the following template: " + templateimage
                 print(x)
                 log.append(x)
                 summarylog.append(x)
                 
                 x = "You are running the following tasks: " + str(tasks)
                 print(x)
                 log.append(x)
                 summarylog.append(x)
                 
                 x = "You are running the following sessions: " + str(imagesession)
                 print(x)
                 log.append(x)
                 
                 x = "Your anatomical session is: " + session
                 print(x)
                 log.append(x)
                 summarylog.append(x)
                 
                 log.append('')
                 log.append('')
                 
                 summarylog.append('')
                 summarylog.append('')
            
            

    if (k == 'bold1mmMNIwarp') & (endit == False):
        #a = -1
        for i in participants:
            person = participant_folders[i]
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session + " BBR is running now"
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in_func = dir_start + person + '/' + j + '/func/'
                            dir_in_anat = dir_start + person + '/' + session + '/anat/'
                            warpdir = dir_start + person + '/' + j + '/func/' + warpfolder

                            imagefile = dir_in_func + regfolder + person + '_' + j + '_' + t + '_' + inputimage + '.nii.gz'
                            warpedimagefile = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warpedimage + '.nii.gz'

                            functransform = dir_in_func + person + '_' + j + '_' + t + '_' + warpmatrixfunc
                            
                            steptimer = time.time()  
                            
                            if not os.path.exists(warpdir):
                               os.makedirs(warpdir)

                            #check if needed files exist             
                            if os.path.isfile(imagefile) == False:
                                x = "This file doesn't exist: " + imagefile
                                print(x)
                                log.append(x)
                            if os.path.isfile(templateimage) == False:
                                x = "This file doesn't exist: " + templateimage
                                print(x)
                                log.append(x)
                                doit = False
                                
                            if os.path.isfile(functransform) == False:
                                x = "This file doesn't exist: " + functransform
                                print(x)
                                log.append(x)
                                doit = False
                                
                            else:
                                doit = True
                                
                                if replacer == False:
                                    if os.path.isfile(warpedimagefile) == True:
                                        x = "Apply Transforms did not run; file already exists for " + warpedimagefile
                                        print(x)
                                        log.append(x)
                                        doit = False
                                
                                if doit == True:    
                                    os.chdir(dir_in_func)
                                    
                                    try: 
                                        x = "Applying Transforms for standard FLIRT on: " + person + " " + j + " " + t
                                        print(x)
                                        log.append(x)
                                        
                                        x = "Warping to template: " + templateimage
                                        print(x)
                                        log.append(x)
                                        
                                        
                                        print("4D FLIRT warp")
                                        #This step will warp your 4D timeseries to MNI space
                                        myaat = ants.ApplyTransforms()
                                        #input image is bold to be moved into MNI
                                        myaat.inputs.input_image = imagefile  
                                        #set reference image as MNI space 
                                        myaat.inputs.reference_image = templateimage
                                        #this is applying some of the math already done to move into MNI
                                        #warpmatrixstrc = path + 'transformT1wFltmeantoMNI.h5' #T1w to MNI
                                        #functransform2 = path + 'OCRefBetBbr.h5'#EPIref to T1
                                        myaat.inputs.transforms = [dir_in_anat + warpmatrixstrc,functransform]
                                        #for some reason image type 3 means it's 4D
                                        myaat.inputs.input_image_type = 3
                                        myaat.inputs.output_image = warpedimagefile
                                        myaat.run()    
                                        
                                        x = "Warp to MNI probably created: " + warpedimagefile
                                        print(x)
                                        log.append(x)
                                        
                                        steptimer = round(time.time()-steptimer,3)
                                        x = "Individual step took " + str(steptimer) + " s to run."
                                        print(x)
                                        log.append(x)
                                        steptimermin = round(steptimer/60,3)
                                        x = "(which is " + str(steptimermin) + " minutes)"
                                        print(x)
                                        log.append(x)
                                        
                                    except: 
                                        x = "Warp to MNI failed for: " + person + ' ' + j + ' ' + t
                                        print(x)
                                        log.append(x)
                                           
                            
                    
    if (k== 'split') & (endit == False):
        df = pd.read_csv(RefVolFile)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        for i in participants:
            person = participant_folders[i]
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session + " BBR is running now"
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in = dir_start + person + '/' + j + '/func/'
                            filenamesinRefVolFile = t + '_echo-2_boldMcFto0.nii.gz_rel.rms'
                            reffer = dir_in + person + '_' + j + '_' + filenamesinRefVolFile
                            
                            input_file = dir_in + warpfolder + person + '_' + j + '_' + t + '_' + splitinput + '.nii.gz'
                            output_file = dir_in + warpfolder + person + '_' + j + '_' + t + '_' + splitoutput + '.nii.gz'
            
                            if os.path.isfile(input_file) == False:
                                x = "This file doesn't exist: " + input_file
                                print(x)
                                log.append(x)
                            else:
                                doit = True
                                if replacer == False:
                                    if os.path.isfile(output_file) == True:
                                        x = "Split did not run; file already exists for " + output_file
                                        print(x)
                                        log.append(x)
                                        doit = False
                                try:
                                    #determine which line of the reference volume file has the kid in question
                                    indexnumber = files.index(reffer)
                                    refvolume = refframes[indexnumber]                    
                                except:
                                    x = "Split did not run. No reference volume specified."
                                    print(x)
                                    log.append(x)
                                    doit = False
                                if doit == True:
                                    steptimer = time.time()
            
                                    x = "Split is beginning to run on: " + person + "_" + j + "_" + t + "_" + splitinput + ".nii.gz"
                                    print(x)
                                    log.append(x)
                                    try:
                                        os.chdir(dir_in)
                                        mysplit = fsl.Split()
                                        mysplit.inputs.dimension = 't'
                                        mysplit.inputs.in_file = input_file
                                        #define a directory for the splitted 4D image
                                        mysplit.inputs.out_base_name = dir_in + 'split/' + person + '_' + j + '_' + t + '_' + splitinput
                
                                        #create the splitted directory, if it doesn't already exist
                                        if not os.path.exists(dir_in + 'split/'):
                                            os.makedirs(dir_in + 'split/')                      
                    
                                        mysplit.run()
                                        
                                        if os.path.isfile(dir_in + 'split/' + person + '_' + j + '_' + t + '_' + splitinput + '00' + str(refvolume) + '.nii.gz') == True: 
                                           copyfile(dir_in + 'split/' + person + '_' + j + '_' + t + '_' + splitinput + '00' + str(refvolume) + '.nii.gz', output_file)
                                        if os.path.isfile(dir_in + 'split/' + person + '_' + j + '_' + t + '_' + splitinput + '0' + str(refvolume) + '.nii.gz') == True:
                                           copyfile(dir_in + 'split/' + person + '_' + j + '_' + t + '_' + splitinput + '0' + str(refvolume) + '.nii.gz', output_file)
            
                                        x = "Split probably created " + output_file
                                        print(x)
                                        log.append(x)
                                        
                                        dir_split = dir_in + 'split'
                                        if os.path.exists(dir_split):
                                            shutil.rmtree(dir_split)
                                        
                                    except Exception as e: print(e)
                                        # x = "Split failed."
                                        # print(x)
                                        # log.append(x)
                                    steptimer = round(time.time()-steptimer,3)
                                    x = "Individual step took " + str(steptimer) + " s to run."
                                    print(x)
                                    log.append(x)
                                    steptimermin = round(steptimer/60,3)
                                    x = "(which is " + str(steptimermin) + " minutes)"
                                    print(x)
                                    log.append(x)
                                    
                    
    if (k == 'mathsmask'):
        for i in participants:
            person = participant_folders[i]
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session + " BBR is running now"
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in = dir_start + person + '/' + j + '/func/' + warpfolder
                            ref_file = dir_in + person + '_' + j + '_' + t + '_' + mathmaskinput + '.nii.gz'
                            mask_outfile = dir_in + person + '_' + j + '_' + t + '_' + mathmaskoutput + '.nii.gz'
                            
                            if os.path.isfile(ref_file) == False:
                                x = "This file doesn't exist: " + ref_file
                                print(x)
                                log.append(x)
                            else:
                                doit = True
                                if replacer == False:
                                    if os.path.isfile(mask_outfile) == True:
                                        x = "Math mask did not run; file already exists for " + mask_outfile
                                        print(x)
                                        log.append(x)
                                        doit = False
                                if doit == True:
                                    steptimer = time.time()
                                    x = "Math mask is begining to run on: " + ref_file
                                    print(x)
                                    log.append(x)
                                    
                                    print("Making mask from single volume")
                                    mymath = fsl.ImageMaths()
                                    mymath.inputs.in_file = ref_file
                                    mymath.inputs.out_file = mask_outfile
                                    mymath.inputs.args = "-bin"
                                    mymath.run() 
                                    
                                    print("Fill holes mask")
                                    mymath = fsl.ImageMaths()
                                    #mnimaskflt = path + 'OCDetFltRegRemArflt' + '_mask.nii.gz'
                                    mymath.inputs.in_file = mask_outfile
                                    mymath.inputs.out_file = mask_outfile
                                    mymath.inputs.args = "-fillh"
                                    mymath.run()   
                                    x = "FSL probably created: " + mask_outfile
                                    print(x)
                                    log.append(x)
                    
                                                            
    if (k == 'filecleanup') & (endit == False):
        for i in participants:
            person = participant_folders[i]
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session + " BBR is running now"
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in_func = dir_start + person + '/' + j + '/func/' + warpfolder
                            remove_path = dir_in_func + dir_in_func + j + t
                            
                            for remove in to_remove: 
                                remove_file = dir_in_func + person + '_' + j + '_' + t + '_' + remove + '.nii.gz'
                                os.remove(remove_file)
                    
                    


#Wrap up the program
#subtract the new current time from the old current time. Also convert to minutes. Add to log

totaltimer = round(time.time()-totaltimer,3)
totaltimermin = round(totaltimer/60,3)
totaltimerhour = round(totaltimermin/60,3)

x = "All steps took " + str(totaltimer) + " s to run."
print(x)
log.append(x)
summarylog.append(x)

x = "(which is " + str(totaltimermin) + " minutes)"
print(x)
log.append(x)
summarylog.append(x)

x = "(which is " + str(totaltimerhour) + " hours)"
print(x)
log.append(x)
summarylog.append(x)

x = 'The end date/time is ' + time.ctime()
print(x)
log.append(x)
summarylog.append(x)

os.chdir(dir_start)
#add a couple blank lines to the log list, to make it look nicer
log.append('')
log.append('')


if savelog == True: 
    #open the log file, add the log list to the file
    #'a' means append. You could also write a new file every time, if you wanted
    with open(logname, 'a') as f:
        for item in log:
            f.write("%s\n" % item)
    f.close()

if savesummarylog == True: 
    #open the log file, add the log list to the file
    #'a' means append. You could also write a new file every time, if you wanted
    with open(summarylogname, 'a') as f:
        for item in summarylog:
            f.write("%s\n" % item)
    f.close()                       
