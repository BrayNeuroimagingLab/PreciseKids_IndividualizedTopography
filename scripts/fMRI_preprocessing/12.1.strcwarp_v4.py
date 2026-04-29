#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Feb  8 14:34:36 2023

@author: kgodfrey

add relevant programs to your user specific path:

export PATH=$PATH:/Users/kgodfrey/antsbin
export PATH=$PATH:/Users/kgodfrey/abin
export PATH=$PATH:/Applications/Convert3DGUI.app/contents/bin



***** READ ME!!!! *****

this script will take your 4D preprocessed image and will warp it to a 
2mm brain extracted subject specific anatomical image

anatomical image was generated using 'createBe2mm.py' script

Update Log V4 (Shefali):
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

#what do you want to warp your epi image to?
#from subject anatomical folder
templateimage = 'T1wFltmeanAbfcBe2mm'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = ['sub-1973026C']
#participants =[15] #003C no YT2
#participants =[58] #024P ses-6 not ses-4


#get a list of everything in the starting directory
#participant_folders = sorted(os.listdir(dir_start))

#what respective session are your participants structural images in?  
#this variable is a list which matches the length of 'participants' above
#anat_ses = ['ses-4']

#for loop with new if statement to find where anat folder with T1w image is located
all_sessions = [0,1,2,3] #all sessions for participant

#what tasks do you want to run this on?
tasks = ['task-DORA1', 'task-DORA2', 'task-RX1', 'task-RX2', 'task-YT1', 'task-YT2']

#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-4']


#name of subfolder where outputs will be saved 
warpfolder = 'strcwarp_newversion/'

#name of folder where your inputs are
regfolder = 'regression_newversion/'

#name of log book that output is saved to
logname = 'xepi_warp_v3.txt'
#do you want to save to the log book?
savelog = True

#name of summary log book saved to
summarylogname = 'xepi_warp_summary_v3.txt'
#do you want to save to the summary log book?
savesummarylog = True

"""*****************"""
"""REFWARP OPTIONS"""
"""*****************"""

#Warp EPIref to T1 using boundary based registration
bbrinput = 'OCRef'
bbroutput = 'OCRefBbr2mm'

#bbrwm is a binary version of the white matter for the template image
bbrwm = "T1wFltmeanAbfcBeWM_binary2mm" 

#what DOF do you want to use for FLIRT bbr?
#ciric et al says to use 9 DOF. Though FSL default is 12...
bbrdof = 9


"""*****************"""
"""BOLDWARP OPTIONS"""
"""*****************"""
#input bold timeseries file you want to warp to MNI 
inputimage = 'OCDetFltRegNewM'

#bold image following warp to MNI
warpedimage = 'OCDetFltRegNewMStrcWarp'

#EPIref to T1, generated in refwarp step
warpmatrixfunc = 'OCRefBbr2mm.h5' 


"""*************"""
"""SPLIT OPTIONS"""
"""*************"""

#this is the file we will be splitting, to extract the reference volume
splitinput = 'OCDetFltRegNewMStrcWarp'

#this is the name of the output reference volume, will be binarized to make a mask 
splitoutput = 'OCDetFltRegNewMStrcWarpRef'

#what file has the reference volumes? 
RefVolFile = '/Volumes/Prckids/xrefvolumes2.csv'

"""*****************"""
"""MATHSMASK OPTIONS"""
"""*****************"""

#this is a single volume indexed by mathsmaskvol, which will be binarized to make a mask
mathmaskinput = 'OCDetFltRegNewMStrcWarpRef'

#what is the output mask called?
mathmaskoutput = 'OCDetFltRegNewMStrcWarpRef_mask'

"""*******************"""
"""FILECLEANUP OPTIONS"""
"""*******************"""

#what files would you like to remove? 
to_remove = ['OCDetFltRegNewMStrcWarp','OCDetFltRegNewMStrcWarpRsRef']

#what steps do you want to run?
steps = ['summary','refwarp', 'boldwarp', 'split', 'mathsmask']

#summary = get summary of preprocessing decisions, save to summary log
#refwarp = warp reference volume to 2mm Be structural
#boldwarp = warp bold to 2mm Be structural, using warping matrix from refwarp step
#split = split warped bold to get reference volume
#mathsmask = binarize reference volume to make a mask

#get a list of everything in the starting directory
#participant_folders = sorted(os.listdir(dir_start))

replacer = False

#get the current time
totaltimer = time.time()

#everything in log gets saved to the logbook. Text often gets appended to log
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())   

#everything in log gets saved to the logbook. Text often gets appended to log
summarylog = ["*************************************************"]
summarylog.append('Starting log for ' + time.ctime())   

endit = False

for idx, k in enumerate(steps):
    if (k == 'summary') & (endit == False):
        #a = -1
        for i in participants:
             #person = participant_folders[i]
             person = i
             for j in all_sessions: 
                 ses = sorted(os.listdir(dir_start + person))
                 session = ses[j]
                 if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                     
                     #for each person, move to the next anatomical session in the list
                    #a = a + 1
                     
                     x = "Warp to Be structural starting for: " + person
                     print(x)
                     summarylog.append(x)
                     
                     x = "You are running the following tasks: " + str(tasks)
                     print(x)
                     log.append(x)
                     summarylog.append(x)
                     
                     x = "You are running the following sessions: " + str(imagesession)
                     print(x)
                     log.append(x)
                     
                     x = "You are warping to the following template: " + person + '_' + session + '_' + templateimage + '.nii.gz'
                     print(x)
                     log.append(x)
                     summarylog.append(x)
                     
                     x = "Your func to T1 warping matrix is: " + warpmatrixfunc
                     print(x)
                     log.append(x)
                     summarylog.append(x)
                     
                     print('')
                     log.append('')
                     log.append('')
                     
                     summarylog.append('')
                     summarylog.append('')
            
    if (k == 'refwarp') & (endit == False):
        a = -1
        for i in participants:
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session + " Refwarp is running"
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in = dir_start + person + '/' + j + '/func/'
                            warpdir = dir_in + warpfolder 
                            
                            if not os.path.exists(warpdir):
                               os.makedirs(warpdir)
                        
                            input_file = dir_in + person + '_' + j + '_' + t + '_' + bbrinput + '.nii.gz'
                            output_file = dir_in  + person + '_' + j + '_' + t + '_' + bbroutput + '.nii.gz'
                            output_mask1 = dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '_mask.nii.gz'
                            
                            #this program assumes the structural image and its WM are saved in a folder with BIDS naming setup
                            input_reference = dir_start + '/' + person + '/' + session + '/anat/' + person + "_" + templateimage + '.nii.gz'
                            input_wm = dir_start + '/' + person + '/' + session + '/anat/' + person + "_" + bbrwm + ".nii.gz"               
           
                            if os.path.isfile(input_file) == False:
                                x = "This file doesn't exist: " + input_file
                                print(x)
                                log.append(x)
                            else:
                                doit = True
                                if replacer == False:
                                    if os.path.isfile(output_file) == True:
                                        x = "FLIRT did not run; file already exists for " + output_file
                                        print(x)
                                        log.append(x)
                                        doit = False
                                if doit == True:
                                    steptimer = time.time()
                                    os.chdir(dir_in)
            
                                    x = "FSL will now try to FLIRT with you on file: " + person + "_" + j + "_" + t + "_" + bbrinput + ".nii.gz"
                                    print(x)
                                    log.append(x)
                                    try:
                                        os.chdir(dir_in)
                                        myflirt = fsl.FLIRT()
                                        myflirt.inputs.in_file = input_file
                                        myflirt.inputs.reference = input_reference
                                        myflirt.inputs.out_file = output_file
                                        #ciric et al says to use 9 DOF. Though FSL default is 12...
                                        myflirt.inputs.dof = bbrdof
                                        myflirt.inputs.out_matrix_file = dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '_mat'
                                        #bbr = boundary based registration
                                        myflirt.inputs.cost = 'bbr'
                                        myflirt.inputs.wm_seg = input_wm
                                        myflirt.run()
                                        
                
                                        c3 = C3dAffineTool()
                                        c3.inputs.source_file = input_file
                                        c3.inputs.reference_file = input_reference
                                        
                                        c3.inputs.itk_transform = dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '.h5'
                                        c3.inputs.transform_file = dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '_mat'
                                        
                                        c3.inputs.fsl2ras = True
                                        c3.run()
                                        
                                        shutil.move(dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '.nii.gz', warpdir + person + '_' + j + '_' + t + '_' + bbroutput + '.nii.gz')
                                        shutil.move(dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '.h5', warpdir + person + '_' + j + '_' + t + '_' + bbroutput + '.h5')
                                        shutil.move(dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '_mat', warpdir + person + '_' + j + '_' + t + '_' + bbroutput + '_mat')
            
                                        x = "FLIRT probably created " + output_file
                                        print(x)
                                        log.append(x)
                                        
                                    except Exception as e: print(e)
                                    
                                    steptimer = round(time.time()-steptimer,3)
                                    steptimermin = round(steptimer/60,3)
                                    x = "Individual step took " + str(steptimer) + " s to run."
                                    log.append(x)
                                    print(x)
                                    x = "(which is " + str(steptimermin) + " minutes)"
                                    print(x)
                                    log.append(x)
                    

    if (k == 'boldwarp') & (endit == False):
        #a = -1
        for i in participants:
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session 
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in_func = dir_start + person + '/' + j + '/func/'
                            #define file names for this specific kid
                            dir_in_anat = dir_start + person + '/' + session + '/anat/'
                            warpdir = dir_start + person + '/' + j + '/func/' + warpfolder

                            imagefile = dir_in_func + regfolder + person + '_' + j + '_' + t + '_' + inputimage + '.nii.gz'
                            warpedimagefile = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warpedimage + '.nii.gz'
                            
                            templatefile = dir_in_anat + person + '_' + templateimage + '.nii.gz'
                            functransform = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warpmatrixfunc
                            
                            if not os.path.exists(warpdir):
                               os.makedirs(warpdir)

                            steptimer = time.time()               
                            if os.path.isfile(imagefile) == False:
                                x = "This file doesn't exist: " + imagefile
                                print(x)
                                log.append(x)
                                
                            if os.path.isfile(templatefile) == False:
                                x = "Your template doesn't exist: " + templatefile
                                print(x)
                                log.append(x)
                            
                            if os.path.isfile(functransform) == False:
                                x = "Your functional transformation matrix doesn't exist: " + functransform
                                print(x)
                                
                            else:
                                doit = True
                                
                                if replacer == False:
                                    if os.path.isfile(warpedimagefile) == True:
                                        x = "Apply Transforms did not run; file already exists for " + warpedimagefile
                                        print(x)
                                        log.append(x)
                                        doit = False # Kate changed from doit = True
                                
                                if doit == True:    
                                    os.chdir(dir_in_func)
                                    
                                    try: 
                                        x = "Applying Transforms for standard FLIRT on: " + person + " " + j + " " + t
                                        print(x)
                                        log.append(x)
                                        
                                        x = "Warping to template: " + templatefile
                                        print(x)
                                        log.append(x)
                                        
                                        print("4D FLIRT warp")
                                        #This step will warp your 4D timeseries to MNI space
                                        myaat = ants.ApplyTransforms()
                                        #input image is bold to be moved into MNI
                                        myaat.inputs.input_image = imagefile  
                                        #set reference image as MNI space 
                                        myaat.inputs.reference_image = templatefile
                                        #this is applying some of the math already done to move into MNI
                                        #warpmatrixstrc = path + 'transformT1wFltmeantoMNI.h5' #T1w to MNI
                                        #functransform2 = path + 'OCRefBetBbr.h5'#EPIref to T1
                                        myaat.inputs.transforms = [functransform]
                                        #for some reason image type 3 means it's 4D
                                        myaat.inputs.input_image_type = 3
                                        myaat.inputs.output_image = warpedimagefile
                                        myaat.run()   
                                        
                                        x = "Warp to Be structural probably created: " + warpedimagefile
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
                                        x = "Warp 2 Be structural failed"
                                        print(x)
                    
                                                                                     
    if (k== 'split') & (endit == False):
        df = pd.read_csv(RefVolFile)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        for i in participants:
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session 
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
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session 
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in = dir_start + person + '/' + j + '/func/' + warpfolder
                            #bold_ref_file = dir_in + person + '_' + j + '_' + t + '_' + mathmaskref + 'MaskRef.nii.gz'
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
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session 
                    print(x)
                    #loop through each anatomical session in the list for correct path
                    for j in imagesession:
                        for t in tasks: 
                            dir_in_func = dir_start + person + '/' + j + '/func/' + warpfolder
                             
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
    ##unsure of this code below, not in steps needed above
    # if (k == 'makemasks') & (endit == False):
    #     a = -1
    #     for i in participants:
    #         person = participant_folders[i]
    #         for j in all_sessions: 
    #             ses = sorted(os.listdir(dir_start + person))
    #             session = ses[j]
    #             if os.path.exists(dir_start + person + "/" + session + "/anat/"):
    #                 x = "found anat folder in " + session + " BBR is running now"
    #                 print(x)
    #                 #loop through each anatomical session in the list for correct path
    #                 for j in imagesession:
    #                     for t in tasks: 
    #                         dir_in_func = dir_start + person + '/' + j + '/func/' 
    #                         dir_in_anat = dir_start + person + '/' + session + '/anat/'
                            
    #                         #imagefile = dir_in_func + warpfolder + person + '_' + j + '_' + task + '_' + maskcleaninputimage + '.nii.gz'
    #                         #outputfile = dir_in_func + warpfolder + person + '_' + j + '_' + task + '_' + maskcleanoutputimage + '.nii.gz'
                            
    #                         #passed into ants.ApplyTransforms() to warp bold reference to Be structural
    #                         ref_file = dir_in_func + person + '_' + j + '_' + t + '_' + inputref + '.nii.gz'
    #                         templatefile = dir_in_anat + person + '_' + templateimage + '.nii.gz'
    #                         functransform = dir_in_func + person + '_' + j + '_' + t + '_' + warpmatrixfunc
    #                         refwarpfile = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warpref + '.nii.gz'
                            
    #                         #resample reference to match bold file
    #                         refwarprsfile = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warprsref + '.nii.gz'
                            
    #                         #outputs of create mask steps
    #                         refwarprsbetfile = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warprsbetref + '.nii.gz'
    #                         strcmaskflt = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warprsbetref + '_mask.nii.gz'
    #                         strcmaskfltfill = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warprsbetref + '_maskfill.nii.gz'
                                
                            
    #                         if os.path.isfile(ref_file) == False:
    #                             x = "Your reference volume file doesn't exist': " + ref_file
    #                             print(x)
    #                             log.append(x)
                                
    #                         if os.path.isfile(templatefile) == False:
    #                             x = "Your structural warping template file doesn't exist': " + templatefile 
    #                             print(x)
    #                             log.append(x)
                            
    #                         if os.path.isfile(functransform) == False:
    #                             x = "Your functional warping matrix does not exist: " + functransform
    #                             print(x)
    #                             log.append(x)
    #                         try: 
    #                             steptimer = time.time() 
                                
    #                             print("Warping Reference Volume to Be Structural")
    #                             #this takes the Reference volume from the timeseries and warps it to MNI space
    #                             #call Ants Apply Transforms
    #                             myaat = ants.ApplyTransforms()
    #                             #input is brain extracted reference volume
    #                             myaat.inputs.input_image = ref_file
    #                             #assign template, MNI
    #                             myaat.inputs.reference_image = templatefile
    #                             #this is applying some of the math already done to move into MNI
    #                             #warpmatrixstrc = path + 'transformT1wFltmeantoMNI.h5' #T1w to MNI
    #                             #functransform = path + 'OCRefBetBbr.h5'#EPIref to T1
    #                             myaat.inputs.transforms = [functransform]
                                
    #                             #output is brain extracted reference image, warped to MNI space
    #                             myaat.inputs.output_image = refwarpfile
    #                             myaat.run()
                                
    #                             x = "Warp probably created: " + refwarpfile
    #                             print(x)
    #                             log.append(x)
                                
    #                             x = "Resampling Reference Volume to 2mm"
    #                             print(x)
    #                             #this takes the warped reference and resamples it to match bold resolution
    #                             myflirt = fsl.FLIRT()
    #                             myflirt.inputs.in_file = refwarpfile
    #                             myflirt.inputs.reference = refwarpfile
    #                             myflirt.inputs.output_type = "NIFTI_GZ"
    #                             myflirt.inputs.apply_isoxfm = 2.0
    #                             myflirt.inputs.no_search = True
    #                             myflirt.inputs.out_file = refwarprsfile
    #                             myflirt.run()
    #                             x = "FLIRT probably created: " + refwarprsfile
    #                             print(x)
    #                             log.append(x)
                                                                         
    #                             print("BET the Reference Volume")
    #                             #This applies fsl.BET to the reference image, to generate an output mask
    #                             mybet = fsl.BET()
    #                             #warpedimagefileflt = path + 'OCDetFltRegRemArflt'
    #                             mybet.inputs.in_file = refwarprsfile
    #                             #specify the fractional intensity for BET
    #                             #this should probably be at the top as a user specified option
    #                             # OLD: mybet.inputs.frac = 0.35
    #                             mybet.inputs.frac = 0.35
    #                             mybet.inputs.robust = True   
    #                             mybet.inputs.mask = True
    #                             #warpedimagefileflt = path + 'OCDetFltRegRemArflt'
    #                             #overwrite
    #                             mybet.inputs.out_file = refwarprsbetfile
    #                             mybet.inputs.threshold = True
    #                             mybet.run()
    #                             x = "Bet probably created: " + refwarprsbetfile
    #                             print(x)
    #                             log.append(x)
                               
    #                             print("Fill holes mask")
    #                             mymath = fsl.ImageMaths()
    #                             #mnimaskflt = path + 'OCDetFltRegRemArflt' + '_mask.nii.gz'
    #                             mymath.inputs.in_file = strcmaskflt
    #                             mymath.inputs.out_file = strcmaskfltfill
    #                             mymath.inputs.args = "-fillh"
    #                             mymath.run()   
    #                             x = "FSL probably created: " + strcmaskfltfill
    #                             print(x)
    #                             log.append(x)
                                
    #                             steptimer = round(time.time()-steptimer,3)
    #                             x = "Individual step took " + str(steptimer) + " s to run."
    #                             print(x)
    #                             log.append(x)
    #                             steptimermin = round(steptimer/60,3)
    #                             x = "(which is " + str(steptimermin) + " minutes)"
    #                             print(x)
    #                             log.append(x)
                    
    #                         except: 
                            
    #                             x = "Make masks failed for: " + person + ' ' + j + ' ' + t
    #                             print(x)
    #                             log.append(x)
                    
