#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Feb  8 14:34:36 2023

@author: kgodfrey

export PATH=$PATH:/Users/kgodfrey/antsbin
export PATH=$PATH:/Users/kgodfrey/abin
export PATH=$PATH:/Applications/Convert3DGUI.app/contents/bin

cd /Users/kgodfrey/DboldStcMcfuments/preciseKIDS/ME_PreprboldStcMcfessing


***** READ ME!!!! *****

this script will take your 4D preprboldStcMcfessed image and move it to 2mm MNI space (templateimage)

first, in 'strct2mmMNIwarp' it generates a warping matrix which contains 
the math for moving the subject specific anatomical image into 2mm MNI

second, in 'bold2mmMNIwarp' it warps your bold image to 2mm MNI
it does this by providing how bold reference was warped to structural (boldStcMcfRefBbr.h5; from 'boldStcMcfpreprboldStcMcfess')
and then by providing how structural was warped to 2mm MNI ("transformT1wFltmeanto2mmMNI"; from strct2mmMNIwarp step above)

third, it gets the reference volume from the warped bold (split step), and binarizes to make a mask (mathsmask step)

this code will likely work improperly if the tedana step is taken out of the workflow, particularly mathsmask

Update Log V2 (Shefali):
Add session if statements within each for loop, no need to prboldStcMcfess 1 session at a time for each subject


"""

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""
import os
import time
import nipype.interfaces.ants as ants
import nipype.interfaces.afni as afni
import nipype.interfaces.fsl as fsl
import shutil
from shutil import copyfile
import pandas as pd
import traceback

#what directory are your images saved in?
dir_start = '/Volumes/PKBackup/preprocessed/'

#note: can make 2mm MNI and 2mm MNI mask using 'create2mmMNI.py'

#path to 2mm MNI template
templateimage = '/Users/shefalirai/Desktop/prckids_preprocess/mni/MNI152_T1_2mm.nii.gz'

#path to 2mm MNI mask
templatemask = '/Users/shefalirai/Desktop/prckids_preprocess/mni/MNI152_T1_2mm_mask.nii.gz'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = ['sub-1973002C', 'sub-1973003C', 'sub-1973004C', 'sub-1973005C', 'sub-1973006C', 'sub-1973007C', 'sub-1973008C', 'sub-1973009C', 'sub-1973010C', 'sub-1973011C', 'sub-1973012C', 'sub-1973013C', 'sub-1973014C', 'sub-1973015C', 'sub-1973016C', 'sub-1973017C', 'sub-1973018C', 'sub-1973019C', 'sub-1973020C', 'sub-1973021C', 'sub-1973022C', 'sub-1973023C', 'sub-1973024C', 'sub-1973025C', 'sub-1973026C']
#participants =['sub-1973002P', 'sub-1973003P', 'sub-1973004P', 'sub-1973005P', 'sub-1973006P', 'sub-1973007P', 'sub-1973008P', 'sub-1973009P', 'sub-1973010P', 'sub-1973011P', 'sub-1973012P', 'sub-1973013P', 'sub-1973014P', 'sub-1973015P', 'sub-1973016P', 'sub-1973017P', 'sub-1973018P', 'sub-1973019P', 'sub-1973020P', 'sub-1973021P', 'sub-1973022P', 'sub-1973023P', 'sub-1973025P', 'sub-1973026P'] #003C no YT2
#participants =['sub-1973024P'] #024P ses-6 not ses-4

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#for loop with new if statement to find where anat folder with T1w image is lboldStcMcfated
all_sessions = [0,1,2,3] #all sessions for participant

#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-4']

#what tasks do you want to run this on?
tasks = ['task-DORA1','task-DORA2','task-RX1','task-RX2','task-YT1','task-YT2']

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = True

#name of subfolder where outputs are saved 
warpfolder = 'mni2mmwarp/'

#name of regression folder where inputs are saved
regfolder = 'regression/'

#name of log book that output is saved to
logname = 'xepi_mni2mmwarp.txt'
#do you want to save to the log book?
savelog = True

#name of summary log book saved to
summarylogname = 'xepi_mni2mmwarp.txt'
#do you want to save to the summary log book?
savesummarylog = True

#what steps do you want to run?
steps = ['bold2mmMNIwarp']
#summary = get summary output of preprboldStcMcfessing decisions
#strct2mmMNIwarp = warp structural to 2mm MNI using ANTS registration, ~20 minutes per image
#bold2mmMNIwarp = warp bold to 2mm MNI
#split = get reference volume for warped timeseries
#mathsmask = make reference volume into a mask
#filecleanup = remove files if desired


"""***********************"""
"""STRCT2mmMNIWARP OPTIONS"""
"""***********************"""

arinputmoving = "T1wFltmeanAbfcBe"
aroutput = "T1wFltmeanAbfcBe2mmMNI"

armatrixoutputname = "transformT1wFltmeanto2mmMNI"
#the outputed matrix will add .h5 to the above name"
#you'll also generate the inverse matrix that has added inverse.h5 to the above name

"""**********************"""
"""BOLD2mmMNIWARP OPTIONS"""
"""**********************"""
#input bold timeseries file you want to warp to MNI 
inputimage = 'OCDetFltRegRem'

#bold image following warp to MNI
warpedimage = 'OCDetFltRegRem2mmMNIWarp'

#warpmatrixstrc = how T1w was referenced to MNI space, generated in 'strct2mmMNIwarp' step 
warpmatrixstrc = 'transformT1wFltmeanto2mmMNI.h5' 

#warpmatrixfunc = how the EPI reference volume was converted to T1, generated in 'boldStcMcfpreprboldStcMcfess' script
warpmatrixfunc = 'OCRefBbr.h5' #EPIref to T1mean

"""*************"""
"""SPLIT OPTIONS"""
"""*************"""

#this is the file we will be splitting, to extract the reference volume
splitinput = 'OCDetFltRegRem2mmMNIWarp'

#this is the name of the output reference volume, will be binarized to make a mask 
splitoutput = 'OCDetFltRegRem2mmMNIWarpRef'

#what file has the reference volumes? 
RefVolFile = '/Volumes/Prckids/xrefvolumes2.csv'

"""*****************"""
"""MATHSMASK OPTIONS"""
"""*****************"""

#this is a single volume indexed by mathsmaskvol, which will be binarized to make a mask
mathmaskinput = 'OCDetFltRegRem2mmMNIWarpRef'

#what is the output mask called?
mathmaskoutput = 'OCDetFltRegRem2mmMNIWarpRef_mask'


"""*******************"""
"""FILECLEANUP OPTIONS"""
"""*******************"""

#keeping these files (especially the warped 4D prior to resample)
#will likely exhaust lboldStcMcfal storage
#however you may wish to skip this step to facilitate debugging

#what files would you like to remove? 
to_remove = ['OCDetFltRegRem2mmMNIWarpRef']

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
        #a = -1
        for i in participants:
             person = i
             #person = i
             for j in all_sessions: 
                 ses = sorted(os.listdir(dir_start + person))
                 session = ses[j]
                 #person = i
                 
                 #for each person, move to the next anatomical session in the list
                 #a = a + 1
                 
                 x = "Warp to 2mm MNI starting for: " + person
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
            
            
    
    if (k == 'strct2mmMNIwarp') & (endit == False):
        #a = -1
        for i in participants:
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session 
                    print(x)
                    dir_in = dir_start + person + "/" + session + "/anat/"
                    input_file = dir_in + person + "_" +  arinputmoving + ".nii.gz" #no session + '_' for parent participants!
                    output_file = dir_in + person + "_" + aroutput + ".nii.gz"
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    if os.path.isfile(templateimage) == False:
                        x = "Your 2mm MNI template doesn't exist: " + templateimage
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Ants Registration did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)

                            x = "ANTs Registration will now try to run. Registration? I prefer Regisphilbin."
                            print(x)
                            log.append(x)
                            try:
                                myar = ants.Registration()
                                myar.inputs.fixed_image = templateimage
                                myar.inputs.fixed_image_masks = templatemask
                                myar.inputs.moving_image = input_file
                                # myar.inputs.output_warped_image = output_file
                                #for some reason, this decided to stop working??? So now I rename the default output
                            
                                #kirk barely understands anything in this section
                                myar.inputs.collapse_output_transforms = True                        
                                myar.inputs.num_threads = 1
                                myar.inputs.output_inverse_warped_image=True
                                myar.inputs.output_warped_image=True
                                myar.inputs.sigma_units=['vox']*3
                                myar.inputs.transforms=['Rigid', 'Affine', 'SyN']
                                myar.inputs.winsorize_lower_quantile=0.005
                                myar.inputs.winsorize_upper_quantile=0.995
                                myar.inputs.convergence_window_size=[10]
                                myar.inputs.metric_weight=[1.0]*3
                                myar.inputs.number_of_iterations=[[1000, 500, 250, 100],[1000, 500, 250, 100],[100, 70, 50, 20]]
                                myar.inputs.radius_or_number_of_bins=[32, 32, 4]
                                myar.inputs.sampling_percentage=[0.25, 0.25, 1]
                                myar.inputs.sampling_strategy=['Regular','Regular','None']
                                myar.inputs.shrink_factors=[[8, 4, 2, 1]]*3
                                myar.inputs.smoothing_sigmas=[[3, 2, 1, 0]]*3
                                myar.inputs.transform_parameters=[(0.1,),(0.1,),(0.1, 3.0, 0.0)]
                                myar.inputs.convergence_threshold=[1e-06]   
                                myar.inputs.use_histogram_matching=True
                                myar.inputs.metric=['MI', 'MI', 'CC']
                                myar.inputs.write_composite_transform=True
                                myar.inputs.initial_moving_transform_com = True
                            
                                myar.run()
                                #rename all the output names from their defaults to names we've specified
                                os.rename('transform_Warped.nii.gz',output_file)
                                os.rename('transformComposite.h5',armatrixoutputname + '.h5')
                                os.rename('transformInverseComposite.h5',armatrixoutputname + 'inverse.h5')
                                os.rename('transform_InverseWarped.nii.gz',armatrixoutputname + 'inverse.nii.gz')    
                                x = "ANTs Registration probably created " + output_file
                                print(x)
                                log.append(x)
                            except Exception as e: print(e)
                                # x = "ANTs Registration failed."
                                # print(x)
                                # log.append(x)
                            steptimer = round(time.time()-steptimer,3)
                            steptimermin = round(steptimer/60,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            log.append(x)
                            print(x)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)
            

    if (k == 'bold2mmMNIwarp') & (endit == False):
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
                            #define file names for this specific kid
                            dir_in_func = dir_start + person + '/' + j + '/func/prckids-task/'
                            dir_in_anat = dir_start + person + '/' + session + '/anat/'
                            warpdir = dir_start + person + '/' + j + '/func/prckids-task/' + warpfolder

                            imagefile = dir_in_func + regfolder + person + '_' + j + '_' + t + '_' + inputimage + '.nii.gz'
                            #warpedimagefile = dir_in_func + warpfolder + person + '_' + j + '_' + t + '_' + warpedimage + '.nii.gz'
                            
                            # FOR REVISIONS
                            revision_root = '/Users/shefalirai/Desktop/Revisions_Remeaned_MNIwarped'
                            revision_warpdir = os.path.join(revision_root, person, j, 'func/prckids-task/mni2mmwarp/')
                            #folder if doesn't exist
                            if not os.path.exists(revision_warpdir):
                                os.makedirs(revision_warpdir)
                            warpedimagefile = os.path.join(
                                revision_warpdir,
                                f"{person}_{j}_{t}_{warpedimage}.nii.gz")

                            functransform = dir_start + person + '/' + j + '/func/' + person + '_' + j + '_' + t + '_' + warpmatrixfunc
                            
                            steptimer = time.time() 
                            
                            if not os.path.exists(warpdir):
                               os.makedirs(warpdir)

                            #check if needed files exist
                            if os.path.isfile(imagefile) == False:
                                x = "This file doesn't exist: " + imagefile
                                print(x)
                                log.append(x)
                                doit = False
                                
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
                                        doit = False # Kate changed from doit = True
                                
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
                                        
                                    except Exception as e:
                                        x = f"Warp to MNI failed for: {person} {j} {t}\nError: {e}\nTraceback:\n{traceback.format_exc()}"
                                        print(x)
                                        log.append(x)
                    
                                   
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
                            dir_in = dir_start + person + '/' + j + '/func/prckids-task/'
                            filenamesinRefVolFile = t + '_boldMcFto0.nii.gz_rel.rms'
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
                            dir_in = dir_start + person + '/' + j + '/func/prckids-task/' + warpfolder
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
                            dir_in_func = dir_start + person + '/' + j + '/func/prckids-task/' + warpfolder
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