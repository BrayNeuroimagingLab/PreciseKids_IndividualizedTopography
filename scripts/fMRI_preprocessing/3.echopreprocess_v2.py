#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Preprocess all video echoes before coregistereing and merging videos together
!!PLEASE NOTE!!
*** You CANNOT press run file, manual changes are needed to this script ***
*** You MUST run this file 6 times manually for each video (Dora1, Dora2, YT1, YT2 etc.) ***
*** Rename all instances of "task-Dora1" to "task-DORA1" then "task-YT1" etc. for all 6 video names ***

Side note: only need to change line 251 if your total volumes per video are less or more than 200
# Kate: kept line 232 the same despite having 205 volumes

Created on Mon Apr  4 10:12:21 2022

@author: shefalirai


Update log V2 (Kate): 
Added a for loop so each task run did not have to be completed manually 
Removed 'samesesanat' and 'diffsesanatfolder' variables from program options as they were not used
Specified in all instances of 'inputfile' to use a *_boldDis.nii.gz file rather than *_bold.nii.gz file
"""


import nipype.interfaces.fsl as fsl
import os
import pandas as pd
import time
import nipype.interfaces.fsl as fsl
import nipype.interfaces.afni as afni
import nipype.interfaces.ants as ants
from nipype.interfaces.c3 import C3dAffineTool
import shutil
from shutil import copyfile
import smtplib, ssl


"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

#what directory are your images saved in?
dir_start = '/Users/shefalirai/Downloads/bids-files/'

#where the reference volumes file is saved
Location = '/Volumes/Prckids/xrefvolumes2.csv'

#the full pathway/name of the file that specifies the reference volumes for each 4D image
RefVolFile = '/Volumes/Prckids/xrefvolumes2.csv'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 
participants = ['sub-parker']

#what sessions do you want to run on? If all, type ["ses-1","ses-2", "ses-3", "ses-4"]
imagesession = ['ses-2']

#what tasks do you want to run on? e.g. ['task-DORA1', 'task-DORA2']
tasks = ['rsfMRI_run-1', 'rsfMRI_run-2', 'vanilla_run-1', 'vanilla_run-2', 'vanilla_run-3']


#if replacer is false, temprealign won't run if file already in reference volume list or if output file already exists
#if replacer is true, temprealign will run even if file already in reference volume list
replacer = False

#name of log book that output is saved to
logname = 'xechopreprocess.txt'

#what steps do you want to run? Possible steps are temprealign, refvol, volcount, mcflirt1, slicetime, mcflirt2
steps = ['temprealign','refvol', 'volcount','mcflirt1','slicetime','mcflirt2']
#temprealign = Use MCFLIRT to warp to first volume. Generate FD based on this. We don't use the realignment only FD.
#refvol = Look through FD to determine reference volumes
#volcount = read through FD list. Count how many volumes there are in 4D data
#mcflirt1 = generate motion estimates on 'uncorrected' data. ~1 minute per image
#slicetime = slicetime correction with FSL. Very fast
#mcflirt2 = rigid body realignment on slicetime corrected data. ~1 minute per image. The only actual realignment that happens


#get the current time
totaltimer = time.time()

#get a list of everything in the starting directory
#for indexing based on 'participants' variable 
participant_folders = sorted(os.listdir(dir_start))

#Start what will be added to the log book for this session
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())


#if your specified reference volume file doesn't exist, this creates it
if os.path.isfile(Location) == False:
    refdata = [('test',255)]
    df = pd.DataFrame(data = refdata, columns=['File', 'Ref_Volume'])
    
    os.chdir(dir_start)
    #save the data frame as a csv file
    df.to_csv(Location,index=False,header=True)
    
#Code here is based off of code in the Lancelot program. See there for more info

participant_folders = sorted(os.listdir(dir_start))

for k in steps:
    
    if k == 'temprealign':
        df = pd.read_csv(Location)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                        dir_in = dir_start + person + '/' + j + '/func/'
                        input_file = dir_in + person + '_' + j + '_' + t +  '_boldDis.nii.gz'
                        output_file = dir_in + person + '_' + j + '_' + t + '_boldMcFto0.nii.gz'
                        ref_name = person + '_' + j + '_' + t + '_boldMcFto0.nii.gz_rel.rms'
                        if os.path.isfile(input_file) == False:
                           input_file = dir_in + person + '_' + j + '_' + t + '.nii'
                        if os.path.isfile(input_file) == False:
                           x = "This file doesn't exist: " + input_file
                           print(x)
                           log.append(x)
                        else:
                            doit = True
                            if replacer == False:
                                if ref_name in files:
                                    x = "Mcflirt did not run, " + person + " " + j + "" + t + " is already in the reference list."
                                    print(x)
                                    log.append(x)
                                    doit = False
                            if doit == True:
                                if replacer == False:
                                    if os.path.isfile(dir_in + ref_name) == True:
                                        x = "McFlirt did not run; this file already exists " + ref_name
                                        print(x)
                                        log.append(x)
                                        doit = False                            
                            if doit == True:
                                steptimer = time.time()
        
                                x = "McFlirt is beginning to run on: " + person + " " + j + " " + t 
                                print(x)
                                log.append(x)
                                try:
                                    os.chdir(dir_in)
                                    mymcf = fsl.MCFLIRT()
                                    mymcf.inputs.in_file = input_file
                                    mymcf.inputs.out_file = output_file
                                    mymcf.inputs.save_mats = True
                                    mymcf.inputs.save_plots = True
                                    mymcf.inputs.save_rms = True
                                    mymcf.inputs.ref_vol = 0
                                    mymcf.run()                        
                                    
                                    x = "McFlirt probably created " + output_file
                                    print(x)
                                    log.append(x)      
                                except:
                                    x = "McFlirt failed."
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
                        

    if k == 'refvol':
        df = pd.read_csv(Location)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                        dir_in = dir_start + person + '/' + j + '/func/'
                        x = []
                        input_file = dir_in + person + '_' + j + '_' + t + '_boldMcFto0.nii.gz_rel.rms'
                        if os.path.isfile(input_file) == False:
                            if input_file in files:
                                x = "Refvol did not run. This file already in reference list (and also no longer exists): " + input_file
                                print(x)
                                log.append(x)
                            else:                        
                                x = "Refvol did not run. This file doesn't exist: " + input_file
                                print(x)
                                log.append(x)
                        else:                  
                            os.chdir(dir_in)
                            if not input_file in files:
                                f = open(input_file, "r")
                                for num in f:
                                    x.append(float(num))
                                #define the reference volume as the one with the smallest FD between
                                try:
                                    y = min(x[95:110]) #Kate: in the middle of 205 volumes for each prckids videos 
                                    refframes.append(x.index(y))
                                    files.append(input_file)
                                    x = person + " " + j + "" + t + " added to reference list. The reference volume is " + str(x.index(y))
                                    print(x)
                                    log.append(x)
                                except:
                                    x = "Refvol failed for " + person + " " + j + ". Perhaps the image was too short."
                                    print(x)
                                    log.append(x)                            
                            else:
                                x = "Refvol did not run, " + person + " " + j + " is already in the reference list."
                                print(x)
                                log.append(x)                        
    
            #create a data frame with the file name and its reference volume
            refdata = list(zip(files,refframes))
            df = pd.DataFrame(data = refdata, columns=['File', 'Ref_Volume'])
    
            os.chdir(dir_start)
            #print(df)
            #save the data frame as a csv file
            df.to_csv(Location,index=False,header=True)


    if k == 'volcount':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                        dir_in = dir_start + person + '/' + j + '/func/'
                        fdlist = []
                        input_file = person + '_' + j + '_' + t +'_boldMcFto0.nii.gz_rel.rms'
                        if os.path.isfile(dir_in + input_file) == True:
                            os.chdir(dir_in)
                            f = open(input_file, "r")
                            for num in f:
                                fdlist.append(float(num))
                            x = input_file + " has this many volumes: " + str(len(fdlist))
                            print(x)
                            log.append(x)
                        else:
                            x = "this file does not exist: " + input_file
                            print(x)
                            log.append(x)                    


    if k == 'mcflirt1':
        #df is the dataframe that is read in that states the reference volume for each 4D volume
        df = pd.read_csv(RefVolFile)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        #loop through all the participants listed
        for i in participants:
            #person = participant_folders[i]
            person = i
            #loop through all the sessions listed (ses-1, ses-2, ses-3, ses-4, or all)
            for j in imagesession:
                for t in tasks:
                        #define the reference volume for the particular 4D image
                        dir_in = dir_start + person + '/' + j + '/func/'
                        ref_name = person + '_' + j + '_' + t + '_boldMcFto0.nii.gz_rel.rms'
                        reffer = dir_in + ref_name
                        #define the directory for the particular 4D image
                        #what's the name of the input 4D volume?
                        input_file = dir_in + person + '_' + j + '_' + t + '_boldDis.nii.gz'
                        #what's the name of the output 4D volume after motion realignment?
                        output_file = dir_in + person + '_' + j + '_' + t + '_boldMcf.nii.gz'
                        #check if the input file actually exists
                        if os.path.isfile(input_file) == False:
                            #if not, check again with .nii instead of .nii.gz
                            #this is a way of accepting files named both .nii or .nii.gz
                            input_file = dir_in + person + '_' + j + '_' + t + '_boldDis.nii'
                        if os.path.isfile(input_file) == False:
                            #put in the log that the input file doesn't exist, so the step didn't run
                            x = "This file doesn't exist: " + input_file
                            print(x)
                            log.append(x)
                        else:
                            #if this variable becomes false, the step won't run
                            doit = True
                            #check if we're supposed to replace files that already exist
                            if replacer == False:
                                if os.path.isfile(output_file) == True:
                                    x = "McFlirt1 did not run; file already exists for " + output_file
                                    print(x)
                                    log.append(x)
                                    #changing doit to false means the step won't run
                                    doit = False
                            try:
                                #determine which line of the reference volume file has the kid in question
                                indexnumber = files.index(reffer)
                                refvolume = refframes[indexnumber]                    
                            except Exception as e: print(e)    
                            if doit == True:
                                #define the current time
                                steptimer = time.time()
        
                                x = "McFlirt1 is beginning to run."
                                print(x)
                                log.append(x)
                                try:
                                    #change the directory
                                    os.chdir(dir_in)
                                    #woooo nipype code
                                    mymcf = fsl.MCFLIRT()
                                    mymcf.inputs.in_file = input_file
                                    mymcf.inputs.out_file = output_file
                                    mymcf.inputs.save_mats = True
                                    mymcf.inputs.save_plots = True
                                    mymcf.inputs.save_rms = True
                                    mymcf.inputs.ref_vol = refvolume
                                    mymcf.run()                        
                                    
                                    x = "McFlirt1 probably created " + output_file
                                    print(x)
                                    log.append(x)      
                                except:
                                    #if something went wrong with all the nipype stuff, this keeps the program running
                                    #so we can try other kids/steps without crashing the whole program
                                    x = "McFlirt1 failed."
                                    print(x)
                                    log.append(x)
                                #calculate the time it took the program to run by taking the current time and subtracting the old time
                                #the '3' rounds it to 3 decimal places. Or maybe 3 sig digs. I forget
                                steptimer = round(time.time()-steptimer,3)
                                x = "Individual step took " + str(steptimer) + " s to run."
                                print(x)
                                log.append(x)
                                #convert the time to minutes
                                steptimermin = round(steptimer/60,3)
                                x = "(which is " + str(steptimermin) + " minutes)"
                                print(x)
                                log.append(x)


    if k == 'slicetime':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                        dir_in = dir_start + person + '/' + j + '/func/'
                        dir_in = dir_start + person + '/' + j + '/func/'
                        input_file = dir_in + person + '_' + j + '_' + t + '_boldDis.nii.gz'
                        output_file = dir_in + person + '_' + j + '_' + t +'_boldStc.nii.gz'
                        if os.path.isfile(input_file) == False:
                            input_file = dir_in + person + '_' + j + '_' + t + '_boldDis.nii.gz'
                        if os.path.isfile(input_file) == False:
                            x = "This file doesn't exist: " + input_file
                            print(x)
                            log.append(x)
                        else:
                            doit = True
                            if replacer == False:
                                if os.path.isfile(output_file) == True:
                                    x = "Slicetime Correction did not run; file already exists for " + output_file
                                    print(x)
                                    log.append(x)
                                    doit = False
                            if doit == True:
                                steptimer = time.time()
        
                                x = "Slice Time Correction is beginning to run."
                                print(x)
                                log.append(x)
                                try:
                                    os.chdir(dir_in)
                                    fslSlice = fsl.SliceTimer()
                                    fslSlice.inputs.in_file = input_file
                                    fslSlice.inputs.out_file = output_file
                                    #apparently "interleaved" is how scans are collected at the ACH
                                    fslSlice.inputs.interleaved = True
        
                                    fslSlice.run()                      
                                    
                                    x = "Slice Time Correction probably created " + output_file
                                    print(x)
                                    log.append(x)      
                                except:
                                    x = "Slice Time Correction failed."
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


    if k == 'mcflirt2':
        df = pd.read_csv(RefVolFile)
        files = list(df['File'])
        refframes = list(df['Ref_Volume'])
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for t in tasks:
                        dir_in = dir_start + person + '/' + j + '/func/'
                        ref_name = person + '_' + j + '_' + t + '_boldMcFto0.nii.gz_rel.rms'
                        reffer = dir_in + ref_name
                        input_file = dir_in + person + '_' + j + '_' + t + '_boldStc.nii.gz'
                        output_file = dir_in + person + '_' + j + '_' + t + '_boldStcMcf.nii.gz'
                        if os.path.isfile(input_file) == False:
                            x = "This file doesn't exist: " + input_file
                            print(x)
                            log.append(x)
                        else:
                            doit = True
                            if replacer == False:
                                if os.path.isfile(output_file) == True:
                                    x = "McFlirt2 did not run; file already exists for " + output_file
                                    print(x)
                                    log.append(x)
                                    doit = False
                            try:
                                #determine which line of the reference volume file has the kid in question
                                indexnumber = files.index(reffer)
                                refvolume = refframes[indexnumber]                    
                            except:
                                x = "McFlirt2 did not run. No reference volume specified."
                                print(x)
                                log.append(x)
                                doit = False
                            if doit == True:
                                steptimer = time.time()
        
                                x = "McFlirt2 is beginning to run."
                                print(x)
                                log.append(x)
                                try:
                                    os.chdir(dir_in)
                                    mymcf = fsl.MCFLIRT()
                                    mymcf.inputs.in_file = input_file
                                    mymcf.inputs.out_file = output_file
                                    mymcf.inputs.save_mats = True
                                    mymcf.inputs.save_plots = True
                                    mymcf.inputs.save_rms = True
                                    mymcf.inputs.ref_vol = refvolume
                                    mymcf.run()                        
                                    
                                    x = "McFlirt2 probably created " + output_file
                                    print(x)
                                    log.append(x)      
                                except:
                                    x = "McFlirt2 failed."
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


#subtract the new current time from the old current time. Also convert to minutes. Add to log
totaltimer = round(time.time()-totaltimer,3)
totaltimermin = round(totaltimer/60,3)
totaltimerhour = round(totaltimermin/60,3)
x = "All steps took " + str(totaltimer) + " s to run."
print(x)
log.append(x)
x = "(which is " + str(totaltimermin) + " minutes)"
print(x)
log.append(x)
x = "(which is " + str(totaltimerhour) + " hours)"
print(x)
log.append(x)

x = 'The end date/time is ' + time.ctime()
print(x)
log.append(x)

os.chdir(dir_start)
#add a couple blank lines to the log list, to make it look nicer
log.append('')
log.append('')

#open the log file, add the log list to the file
#'a' means append. You could also write a new file every time, if you wanted
with open(logname, 'a') as f:
    for item in log:
        f.write("%s\n" % item)
f.close()                    






