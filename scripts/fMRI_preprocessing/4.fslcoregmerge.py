#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Oct 29 12:14:26 2021
Prckids ME preprocessing Step 1
Coregister each run to the very first video run and echo 1
Then merge each echo1 video condition together, and do the same for echoes 2 and 3
!!PLEASE NOTE!!
*** You can press run file, no manual changes or edits needed to this script ***

Side note: If more than 6 runs/videos, please note this code will only merge and coregister 6 video runs. 
If you have more than 6 videos, you need to manually add any extra video runs beyond the 6 specified here

This script outputs files to the folder where the script is saved, you can delete those intermediate files

@author: shefalirai
"""

#**********************************************************************************************************************************************
#Please change the data paths below! 
#If intermediate files output to Desktop or where scripts are saved, you can delete them all

import nipype.interfaces.fsl as fsl
from nipype.interfaces.fsl import Merge
from nipype.interfaces.fsl import ExtractROI
import nipype.interfaces.afni as afni
import nipype.interfaces.ants as ants
import os
import time

#manually give input, reference and output paths
dir_start = "/Users/shefalirai/Downloads/bids-files/"

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 
participants = ['sub-shef_5echo']

#do you want to run on ses-1,, ses-2, ses-3, ses-4 or all? If all, type ['ses-1', 'ses-2', 'ses-3', 'ses-4']
imagesession = ['ses-1', 'ses-2']

#how many echoes do we have?
echoes=['echo-1', 'echo-2', 'echo-3', 'echo-4', 'echo-5']

#what steps do you want to run? 
steps = ['coregister1']
#steps = ['coregister1', 'coregister2','coregister3','coregister4','coregister5','coregister6','merge']
#coregister 1-6 for each video run 1-6
#merge to merge all video runs 1-6 into 1 final merged file


#specify reference Run 1 (we will only use Run 1 echo 1 for our reference EPI for all video runs)
run1_echo1_flirtreferenceepi='task-rest_echo-1_boldStcMcf.nii.gz'

#specify all video names for runs 1-6
run1_flirtinputepi='task-rest'
run1_flirtoutputepi='task-rest'

run2_flirtinputepi='task-DORA2'
run2_flirtoutputepi='task-DORA2'

run3_flirtinputepi='task-RX1'
run3_flirtoutputepi='task-RX1'

run4_flirtinputepi='task-RX2'
run4_flirtoutputepi='task-RX2'

run5_flirtinputepi='task-YT1'
run5_flirtoutputepi='task-YT1'

run6_flirtinputepi='task-YT2'
run6_flirtoutputepi='task-YT2'


#specify output merged file names
merged_file='task-allvideos_merged'

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = True

#**********************************************************************************************************************************************
#The code below doesn't need to be changed or altered, only change the file paths above!

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#get the current time
totaltimer = time.time()

# Run 1 echo 1 as your reference to coregister to Run 1 all other echoes (2 and 3)
for k in steps:
    
    if k == 'coregister1':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    reference_file = dir_in + person + "_" + j + "_" + run1_echo1_flirtreferenceepi
                    input_file = dir_in + person + "_" + j + "_" + run1_flirtinputepi + "_" + e + "_boldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + run1_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    matrix_file = dir_in + e + 'ref_to_Run1_mat'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Coregister did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt for coregistering is running on " + person + "_" + j + "_" + run1_flirtinputepi + "_" + e
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_matrix_file = matrix_file
                                myflirt.epi_base = 0
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_file = output_file
                                myflirt.epi_base = 0
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                               
                                x = "FLIRT probably created " + run1_flirtoutputepi
                            except Exception as e: print(e)


# Run 1 echo 1 as your reference to coregister to Run 2 all echoes
    if k == 'coregister2':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    reference_file = dir_in + person + "_" + j + "_" + run1_echo1_flirtreferenceepi
                    input_file = dir_in + person + "_" + j + "_" + run2_flirtinputepi + "_" + e + "_boldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + run2_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    matrix_file = dir_in + e + 'ref_to_Run2_mat'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Coregister did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt for coregistering is running on " + person + "_" + j + "_" + run2_flirtinputepi + "_" + e
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_matrix_file = matrix_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_file = output_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                               
                                x = "FLIRT probably created " + run2_flirtoutputepi
                                print(x)
                            except Exception as e: print(e)

# Run 1 echo 1 as your reference to coregister to Run 3 all echoes
    if k == 'coregister3':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    reference_file = dir_in + person + "_" + j + "_" + run1_echo1_flirtreferenceepi
                    input_file = dir_in + person + "_" + j + "_" + run3_flirtinputepi + "_" + e + "_boldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + run3_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    matrix_file = dir_in + e + 'ref_to_Run3_mat'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Coregister did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt for coregistering is running on " + person + "_" + j + "_" + run3_flirtinputepi + "_" + e
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_matrix_file = matrix_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_file = output_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                               
                                x = "FLIRT probably created " + run3_flirtoutputepi
                                print(x)
                            except Exception as e: print(e)


 
# Run 1 echo 1 as your reference to coregister to Run 4 all echoes
    if k == 'coregister4':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    reference_file = dir_in + person + "_" + j + "_" + run1_echo1_flirtreferenceepi
                    input_file = dir_in + person + "_" + j + "_" + run4_flirtinputepi + "_" + e + "_boldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + run4_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    matrix_file = dir_in + e + 'ref_to_Run4_mat'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Coregister did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt for coregistering is running on" + person + "_" + j + "_" + run4_flirtinputepi + "_" + e
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_matrix_file = matrix_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_file = output_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                               
                                x = "FLIRT probably created " + run4_flirtoutputepi
                                print(x)
                            except Exception as e: print(e)
            
# Run 1 echo 1 as your reference to coregister to Run 5 all echoes
    if k == 'coregister5':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    reference_file = dir_in + person + "_" + j + "_" + run1_echo1_flirtreferenceepi
                    input_file = dir_in + person + "_" + j + "_" + run5_flirtinputepi + "_" + e + "_boldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + run5_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    matrix_file = dir_in + e + 'ref_to_Run5_mat'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Coregister did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt for coregistering is running on " + person + "_" + j + "_" + run5_flirtinputepi + "_" + e
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_matrix_file = matrix_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_file = output_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                               
                                x = "FLIRT probably created " + run5_flirtoutputepi
                                print(x)
                            except Exception as e: print(e)
            
# Run 1 echo 1 as your reference to coregister to Run 6 all echoes
    if k == 'coregister6':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    reference_file = dir_in + person + "_" + j + "_" + run1_echo1_flirtreferenceepi
                    input_file = dir_in + person + "_" + j + "_" + run6_flirtinputepi + "_" + e + "_boldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + run6_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    matrix_file = dir_in + e + 'ref_to_Run6_mat'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Coregister did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt for coregistering is running on" + person + "_" + j + "_" + run6_flirtinputepi + "_" + e
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_matrix_file = matrix_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = "NIFTI_GZ"
                                myflirt.inputs.out_file = output_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                               
                                x = "FLIRT probably created " + run6_flirtoutputepi
                                print(x)
                            except Exception as e: print(e)


#Merge all coregistered echoes together 
    if k == 'merge':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + "/" + j + "/func/"
                    input_file1 = dir_in + person + "_" + j + "_" + run1_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    input_file2 = dir_in + person + "_" + j + "_" + run2_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    input_file3 = dir_in + person + "_" + j + "_" + run3_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    input_file4 = dir_in + person + "_" + j + "_" + run4_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    input_file5 = dir_in + person + "_" + j + "_" + run5_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    input_file6 = dir_in + person + "_" + j + "_" + run6_flirtoutputepi + "_" + e + "_flirtboldStcMcf.nii.gz"
                    output_file = dir_in + person + "_" + j + "_" + merged_file + "_" + e + "_flirtboldStcMcf.nii.gz"
                    if os.path.isfile(input_file6) == False:
                        x = "The last video run file doesn't exist please run coregistering script again: " + input_file6
                        print(x)
                    else:
                        doit = True
                        if replacer == False: 
                            if os.path.isfile(output_file) == True:
                                x = "FSL merge did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL merge is running"
                            print(x)
                            try:
                                merger=Merge()
                                merger.inputs.in_files=[input_file1, input_file2, input_file3, input_file4, input_file5, input_file6]
                                merger.inputs.dimension = 't'
                                merger.inputs.output_type= 'NIFTI_GZ'
                                merger.inputs.merged_file= output_file
                                merger.inputs.tr= 2
                                merger.run()

                                x = "Merge probably created " + output_file
                                print(x)
                            except Exception as e: print(e)
  
        
totaltimer = round(time.time()-totaltimer,3)
totaltimermin = round(totaltimer/60,3)
totaltimerhour = round(totaltimermin/60,3)
x = "All steps took " + str(totaltimer) + " s to run."
print(x)
x = "(which is " + str(totaltimermin) + " minutes)"
print(x)
x = "(which is " + str(totaltimerhour) + " hours)"
print(x)
x = 'The end date/time is ' + time.ctime()
print(x)

