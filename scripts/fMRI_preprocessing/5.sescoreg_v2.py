#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sun Mar  6 14:55:37 2022

This script coregisters sessions 2,3,4 to flirted session 1
!!PLEASE NOTE!!
*** You can press run file, no manual changes or edits needed to this script ***


This script outputs files to the folder where the script is saved, you can delete those intermediate files

@author: shefalirai

Update Log V2

Kate added replacer arguement
"""

import nipype.interfaces.fsl as fsl
from nipype.interfaces.fsl import Merge
from nipype.interfaces.fsl import ExtractROI
import nipype.interfaces.afni as afni
import nipype.interfaces.ants as ants
import os
import time

#manually give input, reference and output paths
dir_start = '/Users/shefalirai/Downloads/bids-files/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
# participants = list(range(1, 59))
participants = ['sub-neta']

#do you want to run on ses-1,, ses-2, ses-3, ses-4 or all? If all, type ['ses-1', 'ses-2', 'ses-3', 'ses-4']
imagesession = ['ses-1','ses-2']

#how many echoes do we have?
echoes=['echo-1', 'echo-2', 'echo-3']

#what steps do you want to run? 
steps = ['sescoregister']

#specify the template session 1 files
#NEED SESSION 1 echo 1 merged file as reference
ses1_flirtreferenceepi = 'task-rest'

#specify input merged file names
merged_file = 'task-rest'

#specify output flirted file names
ses_matrix_file = 'ses_ref_mat'
sesmerged_output = 'task-rest_mergedses'

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = False

#get the current time
totaltimer = time.time()

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

# Coregister sessions to session 1
for k in steps:
    
    if k == 'sescoregister':
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for e in echoes:
                    dir_in = dir_start + person + '/' + j + '/func/'
                    reference_file = dir_start + person + '/' + 'ses-1/func/' + person + '_ses-1_' + ses1_flirtreferenceepi + '_' + 'echo-1' + '_flirtboldStcMcf.nii.gz'
                    input_file = dir_in + person + '_' + j + '_' + merged_file + '_' + e + '_flirtboldStcMcf.nii.gz'
                    output_matrix_file = dir_in + person + '_' + j + '_' + e + ses_matrix_file
                    output_file = dir_in + person + '_' + j + '_' + sesmerged_output + '_' + e + '_flirtboldStcMcf.nii.gz'
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "FLIRT did not run; file already exists for " + output_file
                                print(x)
                                doit = False
                        if doit == True:
                            x = "FSL Flirt is running on: " + person + "_" + j + "_" + e + "_flirtboldStcMcf.nii.gz"
                            print(x)
                            try:
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.output_type = 'NIFTI_GZ'
                                myflirt.inputs.out_matrix_file = output_matrix_file
                                myflirt.run()
                                myflirt = fsl.FLIRT()
                                myflirt.inputs.reference = reference_file
                                myflirt.inputs.apply_xfm = True
                                myflirt.inputs.in_matrix_file = output_matrix_file
                                myflirt.inputs.in_file = input_file
                                myflirt.inputs.output_type = 'NIFTI_GZ'
                                myflirt.inputs.out_file = output_file
                                myflirt.run()
                                x = "FLIRT probably created " + output_file
                                print(x)
                            except Exception as e: print(e)
        
        
#subtract new current time from old current time, convert
totaltimer = round(time.time()-totaltimer,3)
totaltimermin = round(totaltimer/60,3)
totaltimerhour = round(totaltimermin/60,3)
x = "All steps took " + str(totaltimer) + " s to run."
print(x)
x = "(which is " + str(totaltimermin) + " minutes)"
print(x)
x = "(which is " + str(totaltimerhour) + " hours)"
print(x)      
        
        