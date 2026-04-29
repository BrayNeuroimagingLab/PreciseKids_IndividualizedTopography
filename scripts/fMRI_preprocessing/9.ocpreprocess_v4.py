#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""

Created on Mon Apr  4 10:37:21 2022

Update Log V2 (Kate):
i. update to manually check for splitinput + "00" versus splitinput + "0" to prevent failure, no manual adjustments needed to address split failure
ii. added loop to go through tasks, each task doesn't have to be run manually
iv. added anat_ses variable, to specify which anatomical session is to be used for each person

Update Log V3 (Kate):
i. now using fsl maths to make a mask of the reference volume, rather than bet
    the bet tool was not intended for mask generation, and we can get the same results 
    with less computational power using fsl maths
    bet and betcons steps are depreciated and can be removed
    
*Reminder*  
Manually create anat_ses list variable in line 57 so it corresponds to the T1 anat folder
for each participant. For example: 002C best T1 is in session 4, 003C best T1 is in session 1 then...
participants=['sub-1973002C', 'sub-1973003C']
anat_ses=['ses-4', 'ses-1']

Update Log V4 (Shefali):
Add session if statements within each for loop, no need to process 1 session at a time for each subject


SUB-NOTE: Participant 003C is missing ses-4 YT2 and 024P has a ses-6 and no ses-4

"""

"""***********"""
"""RANDOM INFO"""
"""**************
To run every step you probably need the following structural images:
Brain extracted structural image - eg T1wAbfcBe
Eroded CSF in native structural space - eg T1wAbfcBeCSF_Erode
Eroded WM in native structural space - eg T1wAbfcBeWM_Erode
WM binary in native structural space - eg T1wAbfcBeWM_binary
    
You can guess and check using: 
os.listdir(dir_start)[x]
(where x is some number, perhaps 20)

*** For Afni it seems like you need to add to path always before running spyder. To avoid error: 3dmask_tool command not found ***
Type bash first then:
bash-3.2$ export PATH=$PATH:/Applications/Convert3DGUI.app/contents/bin
bash-3.2$ export PATH=$PATH:/Users/kgodfrey/antsbin
bash-3.2$ export PATH=$PATH:/Users/kgodfrey/abin
bash-3.2$ spyder
Then run this script

@author: shefalirai
"""

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""
#what directory are your images saved in?
dir_start = '/Volumes/Prckids/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = ['sub-1973026C']
#participants =[9] #003C no YT2
 #participants =[52] #024P ses-6 not ses-4

#what session are each participants structural images in?  
#this variable is a list which respectively matches 'participants' above
#anat_ses = ['ses-4']

#for loop with new if statement to find where anat folder with T1w image is located
all_sessions = [0,1,2,3] #all sessions for participant

#what tasks do you want to run this on?
tasks = ['task-DORA1', 'task-DORA2', 'task-RX1', 'task-RX2', 'task-YT1', 'task-YT2']

#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-4']

#the full pathway/name of the file that specifies the reference volumes for each 4D image
#these are created in echopreprocess
RefVolFile = '/Volumes/Prckids/xrefvolumes2.csv'

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = True

#name of log book that output is saved to
logname = 'xocpreprocess.txt'
savelog = True

#summary log book
summarylogname = 'xocpreprocess_summary.txt'
savesummarylog = True

#what steps do you want the program to run? The steps are run in the order listed
#for full preprocessing type:
steps = ['summary', 'split', 'mathsmask','bbr','cxfm','axfm','maskupdate','cleanup']
#summary = generate summary of preprocessing choices to be saved to summary log.
#split = split 4D volume into 3D volumes. Isolate reference volume. Very fast
#mathsmask = binarize the reference volume to create a mask. Very fast.
#bbr = warp EPI image to structural image using boundary based registration. Uses FLIRT. ~12 minutes per image.
#cxfm = reverses the fsl formated single transformation matrix from above step to instead warp structural to EPI. Uses FLIRT. 1s per scan
#axfm = warps the structural image to the functional image using the output of cxfm. Uses FLIRT. 30s per scan
#maskupdate = update CSF and WM masks (mostly CSF). 10s per scan
#cleanup = delete junk files

#removed (Bet originally not intended for mask creation, we can do this more easily and less)
#bet = use FSL Bet to remove non-brain data from reference volume. Very fast
#betcons = use FSL Bet to only remove what is definitely non-brain. More conservative than your one uncle


"""*************"""
"""SPLIT OPTIONS"""
"""*************"""

splitinput = 'dn_ts_OC'
splitoutput = 'OCRef'

"""***************"""
"""FSL BET OPTIONS"""
"""***************"""

#the higher betfrac the more is removed along edges of an image
#betfrac = 0.3

#try lower betfrac
betfrac = 0.1

#will also spit out a mask using the output name with "_mask" on the end
betinput = 'OCRef'
betoutput = 'OCRefBet'

"""****************************"""
"""FSL BET CONSERVATIVE OPTIONS"""
"""****************************"""

#betcfrac = 0.1

#trying lower betcfrac
betcfrac = 0.05

betcinput = 'OCRef'
betcoutput = 'OCRefConsbet'

"""***************"""
"""MATHSMASK OPTIONS"""
"""***************"""

mathmaskinput = 'OCRef'
mathmaskoutput = 'OCRef_mask'


"""*****************"""
"""FLIRT BBR OPTIONS"""
"""*****************"""

#Warp EPIref to T1
bbrinput = 'OCRef'
bbroutput = 'OCRefBbr'

#bbrreference is the name of the brain extracted structural image
bbrreference = "T1wFltmeanAbfcBe"

#bbrwm is a binary version of the white matter of the above listed brain extracted image
bbrwm = "T1wFltmeanAbfcBeWM_binary" 

#what DOF do you want to use for FLIRT bbr?
#ciric et al says to use 9 DOF. Though FSL default is 12...
bbrdof = 9


"""*************************"""
"""cxfm: CONVERT/INVERSE XFM """
"""*************************"""

cxfminput = 'OCRefBbr_mat'
cxfmoutput = 'OCRefBbr_matinv'

#this reverses a fsl formated transformation matrix using FLIRT


"""***********************"""
"""axfm: Apply XFM OPTIONS"""
"""***********************"""

#warp T1w to functional space
axfminput = 'T1wFltmeanAbfcBe'
axfmoutput = 'OCT1wFltmeanAbfcBe_func'

#warp structural CSF to functional space
axfmcsfinput = 'T1wFltmeanAbfcBeCSF_Erode'
axfmcsfoutput = 'OCT1wFltmeanAbfcBeCSF_Erode_func'

#warp structural WM to functional space
axfmwminput = 'T1wFltmeanAbfcBeWM_Erode'
axfmwmoutput = 'OCT1wFltmeanAbfcBeWM_Erode_func'

axfmreference = 'OCRef'
axfmmatrix = 'OCRefBbr_matinv'


"""******************"""
"""maskupdate OPTIONS"""
"""******************"""

mucsfinput = 'OCT1wFltmeanAbfcBeCSF_Erode_func'
mucsfoutput = 'OCMASKCSF'

muwminput = 'OCT1wFltmeanAbfcBeWM_Erode_func'
muwmoutput = 'OCMASKWM'

#whole brain mask
mumask = 'OCRef_mask'

"""*****************************************"""
"""ANYTHING BELOW HERE DOESN'T NEED CHANGING"""
"""**********(OR SO KIRK HOPES)*************"""
"""*****************************************"""

import nipype.interfaces.fsl as fsl
import nipype.interfaces.afni as afni
import nipype.interfaces.ants as ants
from nipype.interfaces.c3 import C3dAffineTool
import os
import pandas as pd
import time
import shutil
from shutil import copyfile
import smtplib, ssl


#get the current time
totaltimer = time.time()

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#everything in log gets saved to the logbook. Text often gets appended to log
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())

#summary log book
logsummary = ["*************************************************"]
logsummary.append('Starting log for ' + time.ctime())


#the big loop of steps. Each step follows the same basic format

for k in steps:
    
    if k == 'summary':
       a = -1
       for i in participants:
            #person = participant_folders[i]
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session
                    print(x)
                    log.append(x)
                    x = "Settings you've entered:"
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "Your directory is: " + dir_start
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "Your person is: " + person
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "You are running the following tasks: " + str(tasks)
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "You are running the following sessions: " + str(imagesession)
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "Your anatomical session is: " + session
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "Your structural reference for registration is: " + person + '_' + session + '_' + bbrreference
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    x = "Your degrees of freedom for FLIRT brain based registration is: " + str(bbrdof)
                    print(x)
                    log.append(x)
                    logsummary.append(x)
                    if replacer == False:
                        x = "You will not overwrite existing files"
                        print(x)
                        log.append(x)
                        logsummary.append(x)
                    else: 
                        x = "You will overwrite existing files"
                        print(x)
                        log.append(x)
                        logsummary.append(x)
                        
                    log.append('')
                    log.append('')
                    logsummary.append('')
                    logsummary.append('')
          
    
    if k == 'split':
        df = pd.read_csv(RefVolFile)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks: 
                    dir_in = dir_start + person + '/' + j + '/func/'
                    filenamesinRefVolFile = t + '_echo-2_boldMcFto0.nii.gz_rel.rms'
                    reffer = dir_in + person + '_' + j + '_' + filenamesinRefVolFile
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + splitinput + '.nii.gz'
                    output_file = dir_in + person + '_' + j + '_' + t + '_' + splitoutput + '.nii.gz'
    
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
              
    if k == 'mathsmask':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks: 
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mathmaskinput + '.nii.gz'
                    output_mask = dir_in + person + '_' + j + '_' + t + '_' + mathmaskoutput + '.nii.gz'
                    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_mask) == True:
                                x = "Math mask did not run; file already exists for " + output_mask
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            x = "Maths Mask is begining to run on: " + input_file
                            print(x)
                            log.append(x)
                            
                            mymath = fsl.ImageMaths()
                            mymath.inputs.in_file = input_file
                            mymath.inputs.out_file = output_mask
                            mymath.inputs.args = "-bin"
                            mymath.run() 
                            
                            x = "FSL probably created: " + output_mask
                            print(x)
                            log.append(x)
    
    if k == 'bet':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks: 
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + betinput + '.nii.gz'
                    output_file = dir_in + person + '_' + j + '_' + t + '_' + betoutput + '.nii.gz'
                    output_mask = dir_in + person + '_' + j + '_' + t + '_' + betoutput + '_mask.nii.gz'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "BET did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
    
                            x = "Place your BETs. BET is beginning to run on: " + person + "_" + j + "_" + betinput + ".nii.gz"
                            print(x)
                            log.append(x)
                            try:
                                os.chdir(dir_in)
                                mybet = fsl.BET()
                                mybet.inputs.in_file = input_file
                                #specify the fractional intensity for BET
                                mybet.inputs.frac = betfrac
                                mybet.inputs.robust = True   
                                mybet.inputs.mask = True
                                mybet.inputs.out_file = output_file
                                mybet.inputs.threshold = True
                                mybet.run()
                                
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = output_mask
                                mymath.inputs.out_file = output_mask
                                mymath.inputs.args = "-fillh"
                                mymath.run()
                                
                                x = "BET probably created " + output_file
                                print(x)
                                log.append(x)
                            except:
                                x = "BET failed."
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
                             
    if k == 'betcons':    
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + betcinput + '.nii.gz'
                    output_file = dir_in + person + '_' + j + '_' + t + '_' + betcoutput + '.nii.gz'
                    output_mask = dir_in + person + '_' + j + '_' + t + '_' + betcoutput + '_mask.nii.gz'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "BET did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
    
                            x = "Place your BETs. Conservative BET is beginning to run on: " + person + '_' + j + '_' + t + '_' + betcinput + '.nii.gz'
                            print(x)
                            log.append(x)
                            try:
                                os.chdir(dir_in)
                                mybet = fsl.BET()
                                mybet.inputs.in_file = input_file
                                #specify the fractional intensity for BET
                                mybet.inputs.frac = betcfrac
                                mybet.inputs.robust = True   
                                mybet.inputs.mask = True
                                mybet.inputs.out_file = output_file
                                mybet.inputs.threshold = True
                                mybet.run()
                                
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = output_mask
                                mymath.inputs.out_file = output_mask
                                mymath.inputs.args = "-fillh"
                                mymath.run()
                                
                                x = "BET conservative probably created " + output_file
                                print(x)
                                log.append(x)
                            except:
                                x = "BET failed."
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
   
    if k == 'bbr':
        for i in participants:
            person = i
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
                            
                            #bbrreference is the name of the brain extracted structural image
                            bbrreference = 'T1wFltmeanAbfcBe'
                            
                            #bbrwm is a binary version of the white matter of the above listed brain extracted image
                            bbrwm = 'T1wFltmeanAbfcBeWM_binary' 
                        
                            input_file = dir_in + person + '_' + j + '_' + t + '_' + bbrinput + '.nii.gz'
                            output_file = dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '.nii.gz'
                            output_mask1 = dir_in + person + '_' + j + '_' + t + '_' + bbroutput + '_mask.nii.gz'
                            
                            #this program assumes the structural image and its WM are saved in a folder with BIDS naming setup
                            input_reference = dir_start + '/' + person + '/' + session + '/anat/' + person + "_" + session + "_" + bbrreference + '.nii.gz'
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
            
                                        # myflirt = fsl.FLIRT()
                                        # myflirt.inputs.in_file = input_file
                                        # myflirt.inputs.reference = input_reference
                                        # myflirt.inputs.out_file = output_file2
                                        # #ciric et al says to use 9 DOF. Though FSL default is 12...
                                        # myflirt.inputs.dof = 9
                                        # myflirt.inputs.out_matrix_file = dir_in + person + flirtoutput + "_mat"
                                        # #bbr = boundary based registration
                                        # myflirt.run()
                                        
                
                                        # c3 = C3dAffineTool()
                                        # c3.inputs.source_file = input_file
                                        # c3.inputs.reference_file = input_reference
                                        
                                        # c3.inputs.itk_transform = dir_in + person + bbroutput + ".h5"
                                        # c3.inputs.transform_file = dir_in + person + bbroutput + "_mat"
                                        
                                        # c3.inputs.fsl2ras = True
                                        # c3.run()                            
                  
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
                
            

    if k == 'cxfm':
        for i in participants:
            #person = participant_folders[i]
            person= i
            for j in imagesession:
                for t in tasks: 
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + cxfminput
                    output_file = dir_in + person + '_' + j + '_' + t + '_' + cxfmoutput
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Convert XFM did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
    
                            x = "Convert XFM will now try to run on: " + person + "_" + j + "_" + t + "_" + cxfminput
                            print(x)
                            log.append(x)
                            
                            try:
                                invt = fsl.ConvertXFM()
                                invt.inputs.in_file = input_file
                                invt.inputs.invert_xfm = True
                                invt.inputs.out_file = output_file
                                invt.run()
      
                                x = "Convert XFM probably created " + output_file
                                print(x)
                                log.append(x)
                                
                            except:
                                x = "Convert XFM failed."
                                print(x)
                                log.append(x)
                                
                            steptimer = round(time.time()-steptimer,3)
                            steptimermin = round(steptimer/60,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            log.append(x)
                            print(x)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)

    if k == 'axfm':
       # a = -1 
        for i in participants:
            person = i
            for j in all_sessions: 
                ses = sorted(os.listdir(dir_start + person))
                session = ses[j]
                if os.path.exists(dir_start + person + "/" + session + "/anat/"):
                    x = "found anat folder in " + session + " AXFM is running now"
                    print(x)
                    #person = i
                    #a = a + 1
                    for j in imagesession:
                        for t in tasks: 
                            
                            #index the variable anat_ses with subject specific location of structural files
                           # anatj = anat_ses[a]
                        
                            dir_in = dir_start + person + '/' + j + '/func/'
                            dir_in_anat = dir_start + person + '/' + session + '/anat/'
                            input_file1 = dir_in_anat + person + '_' + session + '_' + axfminput + '.nii.gz'
                            output_file1 = dir_in + person + '_' + j + '_' + t + '_' + axfmoutput + '.nii.gz'
                                    
                            input_file2 = dir_in_anat + person + '_' + axfmcsfinput + '.nii.gz'
                            intermediate2_1 = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfoutput + 'junk1.nii.gz' 
                            intermediate2_2 = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfoutput + 'junk2.nii.gz' 
                            output_file2 = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfoutput + '.nii.gz' 
                            
                            input_file3 = dir_in_anat + person + '_' + axfmwminput + '.nii.gz'
                            intermediate3_1 = dir_in + person + '_' + j + '_' + t + '_' + axfmwmoutput + 'junk1.nii.gz'  
                            intermediate3_2 = dir_in + person + '_' + j + '_' + t + '_' + axfmwmoutput + 'junk2.nii.gz'  
                            output_file3 = dir_in + person + '_' + j + '_' + t + '_' + axfmwmoutput + '.nii.gz'          
                            
                            input_matrix = dir_in + person + '_' + j + '_' + t + '_' + axfmmatrix
                            input_reference = dir_in + person + '_' + j + '_' + t + '_' + axfmreference + '.nii.gz'
                            
                            if os.path.isfile(input_file1) == False:
                                x = "This file doesn't exist: " + input_file1
                                print(x)
                                log.append(x) 
                            
                            else:
                                doit = True
                                if replacer == False:
                                    if os.path.isfile(output_file3) == True:
                                        x = "Apply XFM did not run; file already exists for " + output_file3
                                        print(x)
                                        log.append(x)
                                        doit = False
                                
                                if doit == True:
                                    steptimer = time.time()
                                    os.chdir(dir_in)
                                    
                                    x = "Apply XFM will now try to run on: " + person + '_' + j + '_' + t
                                    print(x)
                                    log.append(x)                        
                                    
                                    try:
                                        myflirt = fsl.FLIRT()
                                        myflirt.inputs.reference = input_reference
                                        myflirt.inputs.apply_xfm = True
                                        myflirt.inputs.in_matrix_file = input_matrix
                                        
                                        myflirt.inputs.in_file = input_file1
                                        myflirt.inputs.out_file = output_file1
                                        myflirt.run()
                                        
                                        myflirt.inputs.in_file = input_file2
                                        myflirt.inputs.out_file = intermediate2_1
                                        myflirt.run()
                                        
                                        myflirt.inputs.in_file = input_file3
                                        myflirt.inputs.out_file = intermediate3_1
                                        myflirt.run()
                                        
                                        #after warping, remove low threshold for both CSF/WM
                                        myrlt = fsl.Threshold()
                                        myrlt.inputs.use_robust_range = True
                                        myrlt.inputs.use_nonzero_voxels = True
                                        
                                        myrlt.inputs.thresh = 10
                                        myrlt.inputs.in_file = intermediate2_1
                                        myrlt.inputs.out_file = intermediate2_2
                                        myrlt.run()
                                        
                                        myrlt.inputs.thresh = 60
                                        myrlt.inputs.in_file = intermediate3_1
                                        myrlt.inputs.out_file = intermediate3_2
                                        myrlt.run()
                                        
                                        #convert images to binaries
                                        mybin = fsl.UnaryMaths()
                                        mybin.inputs.operation = 'bin'
                                        mybin.inputs.in_file = intermediate2_2
                                        mybin.inputs.out_file = output_file2
                                        mybin.run()
                                        
                                        mybin.inputs.in_file = intermediate3_2
                                        mybin.inputs.out_file = output_file3
                                        mybin.run()
                                        
                                        x = "Apply XFM probably created " + output_file1
                                        print(x)
                                        log.append(x)
                                    
                                    except:
                                        x = "Apply XFM failed."
                                        print(x)
                                        log.append(x)
                                        
                                    steptimer = round(time.time()-steptimer,3)
                                    steptimermin = round(steptimer/60,3)
                                    x = "Individual step took " + str(steptimer) + " s to run."
                                    log.append(x)
                                    print(x)
                                    x = "(which is " + str(steptimermin) + " minutes)"
                                    print(x)
                                    log.append(x)
            

    if k == 'maskupdate':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks: 
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_csfmask = dir_in + person + '_' + j + '_' + t + '_' + mucsfinput + '.nii.gz'
                    output_csfmask = dir_in + person + '_' + j + '_' + t + '_' + mucsfoutput + '.nii.gz'
                    input_wmmask = dir_in + person + '_' + j + '_' + t + '_' + muwminput + '.nii.gz'
                    output_wmmask = dir_in + person + '_' + j + '_' + t + '_' + muwmoutput + '.nii.gz'
                    input_brainmask = dir_in + person + '_' + j + '_' + t + '_' + mumask + '.nii.gz'                
                    
                    input_brainmask_erode = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'erode.nii.gz'
                    input_brainmask_upview = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'upview.nii.gz'
                    input_brainmask_upview_down = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'junk.nii.gz'
                    input_brainmask_upview_down_mat = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'upview_mat'
                               
                                
                    if os.path.isfile(input_csfmask) == False:
                        x = "This file doesn't exist: " + input_csfmask
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_csfmask) == True:
                                x = "Update masks did not run; file already exists for " + output_csfmask
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
                            
                            x = "Update masks will now try to run on: " + person + '_' + j + '_' + t
                            print(x)
                            log.append(x)                        
                            try:
                                """
                                The first 6 steps are literally the stupidest fix, but the only one that would work.
                                Their purpose is to create an eroded whole brain mask to limit CSF to tissue near ventricle
                                -roi increases the field of view
                                -erosion then erodes the sides of the mask. The increased  field of view allows for the
                                bottom to also be eroded
                                -then myflirt1 warps the original expanded field of view image back to the original image
                                (this literally changes nothing, cause they're the same image, but gives us a transformation matrix)
                                -myflirt2 then warps the eroded image back into the same space as the original image
                                -rlt removes the low threshold artifact from the warping process
                                """
                                
                                roi = fsl.ExtractROI()
                                roi.inputs.in_file = input_brainmask
                                roi.inputs.roi_file = input_brainmask_upview
                                roi.inputs.x_min = -5
                                roi.inputs.x_size = 101
                                roi.inputs.y_min = -5
                                roi.inputs.y_size = 119
                                roi.inputs.z_min = -5
                                roi.inputs.z_size = 101
                                roi.run()
                                
                                erosionM = afni.MaskTool()
                                erosionM.inputs.in_file = input_brainmask_upview
                                erosionM.inputs.out_file = input_brainmask_erode
                                erosionM.inputs.outputtype = 'NIFTI_GZ'
                                erosionM.inputs.dilate_inputs = '-7'
                                erosionM.inputs.args = "-overwrite"
                                erosionM.run()
                                
                                myflirt1 = fsl.FLIRT()
                                myflirt1.inputs.reference = input_brainmask
                                myflirt1.inputs.in_file = input_brainmask_upview
                                myflirt1.inputs.out_file = input_brainmask_upview_down
                                myflirt1.inputs.out_matrix_file = input_brainmask_upview_down_mat
                                myflirt1.run()
                                
                                myflirt2 = fsl.FLIRT()
                                myflirt2.inputs.reference = input_brainmask
                                myflirt2.inputs.apply_xfm = True
                                myflirt2.inputs.in_matrix_file = input_brainmask_upview_down_mat                            
                                myflirt2.inputs.in_file = input_brainmask_erode
                                myflirt2.inputs.out_file = input_brainmask_erode
                                myflirt2.run()
                                
                                myrlt = fsl.Threshold()
                                myrlt.inputs.use_robust_range = True
                                myrlt.inputs.use_nonzero_voxels = True
                                myrlt.inputs.thresh = 1
                                myrlt.inputs.in_file = input_brainmask_erode
                                myrlt.inputs.out_file = input_brainmask_erode
                                myrlt.run()
                                
                                #create the CSF mask by multiplying the eroded brainmask by the original CSF mask
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = input_brainmask_erode
                                mymath.inputs.out_file = output_csfmask
                                mymath.inputs.args = "-mul " + input_csfmask
                                mymath.run()
                                
                                #create the WM mask by multiplying the original brainmask by the original WM mask
                                #this probably changes nothing, but perhaps there was a bad functional<-->structural alignment
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = input_brainmask
                                mymath.inputs.out_file = output_wmmask
                                mymath.inputs.args = "-mul " + input_wmmask
                                mymath.run()
                                
                                x = "Update masks probably created " + output_wmmask
                                print(x)
                                log.append(x)
                                
                            except:
                                x = "Update masks failed."
                                print(x)
                                log.append(x)
                                
                            steptimer = round(time.time()-steptimer,3)
                            steptimermin = round(steptimer/60,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            log.append(x)
                            print(x)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)        

    if k == 'cleanup':
        x = "Now deleting junk extra files."
        print(x)
        log.append(x) 
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                    dir_in = dir_start + person + '/' + j + '/func/'
                    
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfinput + '_flirt.mat'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
    
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmwminput + '_flirt.mat'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
    
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfminput + '_flirt.mat'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
                        
                                           
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfinput + '_funcjunk1.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)   
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfinput + '_funcjunk2.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file) 
                        
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfoutput + 'junk1.nii.gz' 
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file) 
                    
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmcsfoutput + 'junk2.nii.gz' 
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file) 
                        
        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmwminput + '_funcjunk1.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file) 
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mucsfinput + '_funcjunk2.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file) 
                        
                    
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmwmoutput + 'junk1.nii.gz' 
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file) 
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + axfmwmoutput + 'junk2.nii.gz' 
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)    
                
        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'erode_flirt.mat'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'erode.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'junk.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'upview_mat'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
                        
                    input_file = dir_in + person + '_' + j + '_' + t + '_' + mumask + 'upview.nii.gz'
                    if os.path.isfile(input_file) == True:
                        os.remove(input_file)
                          
                    dir_in_input = dir_in + "split"
                    if os.path.exists(dir_in_input):
                        shutil.rmtree(dir_in_input)
                        

#We've escaped the big loop. Let's wrap up this program.
  

#subtract the new current time from the old current time. Also convert to minutes. Add to log
totaltimer = round(time.time()-totaltimer,3)
totaltimermin = round(totaltimer/60,3)
totaltimerhour = round(totaltimermin/60,3)
x = "All steps took " + str(totaltimer) + " s to run."
print(x)
log.append(x)
logsummary.append(x)
x = "(which is " + str(totaltimermin) + " minutes)"
print(x)
log.append(x)
logsummary.append(x)
x = "(which is " + str(totaltimerhour) + " hours)"
print(x)
log.append(x)
logsummary.append(x)

x = 'The end date/time is ' + time.ctime()
print(x)
log.append(x)

os.chdir(dir_start)
logsummary.append(x)
#add a couple blank lines to the log list, to make it look nicer
log.append('')
log.append('')
logsummary.append('')
logsummary.append('')

#open the log file, add the log list to the file
#'a' means append. You could also write a new file every time, if you wanted
if savelog == True:
    with open(logname, 'a') as f:
        for item in log:
            f.write("%s\n" % item)
    f.close()         

if savesummarylog == True:
    with open(summarylogname, 'a') as f:
        for item in logsummary:
            f.write("%s\n" % item)
    f.close()            
