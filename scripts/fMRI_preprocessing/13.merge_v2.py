#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Mon Nov 21 09:50:31 2022

@author: kgodfrey

this script will merge your preprocessed bold runs, your temporal masks, structural masks
it will also clean up the merged bold runs using the merged strucutral mask

"""

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

import time
import os
import nipype.interfaces.fsl as fsl
from nipype.interfaces.fsl import Merge

#what folder are your preprocessed images in?
#dir_start = '/Volumes/PKBackup/preprocessed/'
dir_start = '/Users/shefalirai/Desktop/Revisions_Remeaned_MNIwarped/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = ['sub-1973002C', 'sub-1973003C', 'sub-1973004C', 'sub-1973005C', 'sub-1973006C', 'sub-1973007C', 'sub-1973008C', 'sub-1973009C', 'sub-1973010C', 'sub-1973011C', 'sub-1973012C', 'sub-1973013C', 'sub-1973014C', 'sub-1973015C', 'sub-1973016C', 'sub-1973017C', 'sub-1973018C', 'sub-1973019C', 'sub-1973020C', 'sub-1973021C', 'sub-1973022C', 'sub-1973023C', 'sub-1973024C', 'sub-1973025C', 'sub-1973026C']
#participants =['sub-1973002P', 'sub-1973003P', 'sub-1973004P', 'sub-1973005P', 'sub-1973006P', 'sub-1973007P', 'sub-1973008P', 'sub-1973009P', 'sub-1973010P', 'sub-1973011P', 'sub-1973012P', 'sub-1973013P', 'sub-1973014P', 'sub-1973015P', 'sub-1973016P', 'sub-1973017P', 'sub-1973018P', 'sub-1973019P', 'sub-1973020P', 'sub-1973021P', 'sub-1973022P', 'sub-1973023P', 'sub-1973025P', 'sub-1973026P'] #003C no YT2
#participants =['sub-1973024P'] #024P ses-6 not ses-4

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))


#which tasks are we merging? (this script assumes that by specifying 'DORA' you have both DORA1 and DORA2)]
tasks = ['task-DORA','task-RX','task-YT']


#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-4']

#what folder are your inputs in?
startfolder = 'mni2mmwarp'

#what folder do you want the merged outputs to be saved?
mergefolder = 'mergeruns'

#regression folder for tmaskmergeinputs 
regressionfolder = 'regression'

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = False

#name of log book that output is saved to
logname = 'xoc_merge_v3.txt'
#do you want to save the log book?
savelog = False

steps = ['boldmerge']
#boldmerge = merge bold runs within tasks
#strcmaskmerge = merge strucutral masks within tasks
#tmaskmerge = merge temporal censoring masks witin tasks
#maskcleanup = clean up merged bold with merged structural mask


"""*****************"""
"""BOLDMERGE OPTIONS"""
"""*****************"""
#what files do you want to merge?
mergeinput = 'OCDetFltRegRem2mmMNIWarp'

"""*********************"""
"""STRCMASKMERGE OPTIONS"""
"""*********************"""

#what masks do you want to merge
maskmergeinput = 'OCDetFltRegRem2mmMNIWarpRef_mask'


#what do you want to call the merged mask?
maskmergeoutput = 'OCDetFltRegRem2mmMNIWarpRef_mask'

"""******************"""
"""TMASKMERGE OPTIONS"""
"""******************"""

#what is the name of the temporal masks to merge 
tmaskmergeinput = 'OCMASK_TEMPORAL'

#what do you want to call the merged mask?
tmaskmergeoutput = 'OCMASK_TEMPORAL'


"""*******************"""
"""MASKCLEANUP OPTIONS"""
"""*******************"""

#what files do you want to clean?
#from the mergeruns folder
cleaninput = 'OCDetFltRegRem2mmMNIWarp'

#what do you want the name of the output to be?
cleanoutput = 'OCDetFltRegRem2mmMNIWarpCl'

#which mask do you want to use?
# merged mask from the mergeruns folder
cleanmask = 'OCDetFltRegRem2mmMNIWarpRef_mask'

#get the current time
totaltimer = time.time()

#everything in log gets saved to the logbook. Text often gets appended to log
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())    

doit = True

os.chdir(dir_start)

for k in steps:
    
    if (k == 'boldmerge'):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                
                dir_in_func = dir_start + person + '/' + j + '/func/prckids-task/' 
                
                if not os.path.exists(dir_in_func + mergefolder):
                   os.makedirs(dir_in_func + mergefolder)
                   
                steptimer = time.time() 
                
                for task in tasks:
                        
                    input_file1 = dir_in_func + startfolder + '/' + person + '_' + j + '_' + task + '1_' + mergeinput + '.nii.gz' 
                    input_file2 =  dir_in_func + startfolder + '/' + person + '_' + j + '_' + task + '2_' + mergeinput + '.nii.gz' 
                    #output_file = dir_in_func + mergefolder + '/' + person + '_' + j + '_' + task + '_' + mergeinput + '.nii.gz'
                    
                    #On local computer for revisions
                    output_file = f'/Users/shefalirai/Desktop/Revisions_Remeaned_MNIwarped/{person}/{j}/func/prckids-task/mergeruns/{person}_{j}_{task}_{mergeinput}.nii.gz'

                    
                    x= "Merging runs for: " + person + " " + j + " " + task
                    print(x)
                    merger=Merge()
                    merger.inputs.in_files=[input_file1, input_file2]
                    merger.inputs.dimension = 't'
                    merger.inputs.output_type= 'NIFTI_GZ'
                    merger.inputs.merged_file= output_file
                    merger.inputs.tr= 2
                    merger.run()
                    x = "Merge probably created " + output_file
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
                             
    if (k == 'strcmaskmerge') & (doit == True):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                
                dir_in_func = dir_start + person + '/' + j + '/func/prckids-task/' 
                
                steptimer = time.time() 
                
                for task in tasks:

                    maskinputfile1 = dir_in_func + startfolder + '/' + person + '_' + j + '_' + task + '1_' + maskmergeinput + '.nii.gz' 
                    maskinputfile2 =  dir_in_func + startfolder + '/' + person + '_' + j + '_' + task + '2_' + maskmergeinput + '.nii.gz' 
                    maskoutput = dir_in_func + mergefolder + '/' + person + '_' + j + '_' + task + '_' + maskmergeoutput + '.nii.gz'
                    
                    x = "Generating new mask across runs for: " + person + " " + j + " " + task
                    print(x)
                    mymath = fsl.ImageMaths()
                    mymath.inputs.in_file = maskinputfile1
                    mymath.inputs.args = "-mul " + maskinputfile2
                    mymath.inputs.out_file = maskoutput 
                    mymath.run()
                    
                    x = "New mask probably created: " + maskoutput
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
    
    if (k == 'tmaskmerge') & (doit == True):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                
                dir_in_func = dir_start + person + '/' + j + '/func/prckids-task/' 
                
                steptimer = time.time() 
                
                for task in tasks:

                    tmaskinputfile1 = dir_in_func + regressionfolder + '/' + person + '_' + j + '_' + task + '1_' + tmaskmergeinput 
                    tmaskinputfile2 =  dir_in_func + regressionfolder + '/' + person + '_' + j + '_' + task + '2_' + tmaskmergeinput  
                    tmaskoutput = dir_in_func + mergefolder + '/' + person + '_' + j + '_' + task + '_' + tmaskmergeoutput + '.txt'
                    
                    x = "Generate new DORA temporal mask across runs for: " + person + " " + j
                
                    currentline = 0
                    if os.path.isfile(tmaskinputfile1) == True:
                        
                        #determine the timepoints marked for censoring
                        tmaskindex = []
                        
                        with open(tmaskinputfile1) as file:
                            for line in file:
                                if int(line) == 0:
                                   tmaskindex.append(0)
                                else: 
                                    tmaskindex.append(1)
                                currentline = currentline + 1 
                                
                    if os.path.isfile(tmaskinputfile2) == True:
                        #determine the timepoints marked for censoring
                        with open(tmaskinputfile2) as file:
                            for line in file:
                                if int(line) == 0:
                                   tmaskindex.append(0)
                                else: 
                                    tmaskindex.append(1)
                                currentline = currentline + 1 
                    
                    with open(tmaskoutput, 'w') as f:
                        for item in tmaskindex:
                            f.write("%s\n" % item)
                    f.close()   
                    
                    x = "Merged temporal mask probably created: " + tmaskoutput
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
    
    if k == 'maskcleanup':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    dir_in = dir_start + person + '/' + j + '/func/prckids-task/' + mergefolder 
                   
                    inputfile = dir_in + '/' + person + '_' + j + '_' + task + '_' + cleaninput + '.nii.gz'
                    inputmask = dir_in + '/' + person + '_' + j + '_' + task + '_' + cleanmask + '.nii.gz' 
                    outputfile = dir_in + '/' + person + '_' + j + '_' + task + '_' + cleanoutput + '.nii.gz'
                    
                    x = "Clean up running on: " + inputfile
                    print(x)
                    log.append(x)
                    
                    x = "Clean up is using this mask: " + inputmask
                    print(x)
                    log.append(x)
 
                    mymath = fsl.ImageMaths()
                    mymath.inputs.in_file = inputfile
                    mymath.inputs.args = "-mul " + inputmask
                    mymath.inputs.out_file = outputfile
                    mymath.run() 
                    
                    x = "Cleaned up file probably created: " + outputfile
                    print(x)
                    log.append(x)
                    
if savelog == True:                        
    with open(logname, 'a') as f:
        for item in log:
            f.write("%s\n" % item)
    f.close()  
