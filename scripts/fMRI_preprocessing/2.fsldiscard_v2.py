#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue May 10 15:41:25 2022

Prckids ME preprocessing Step 1
Remove first 5 dummy volumes (first 10 seconds) from all run echoes

@author: shefalirai

Update log v2 (Kate):
Discarded timeseries saved in new *_boldDis.nii.gz file, to avoid accidently running step twice
Option provided to delete original *_bold.nii.gz file 
Added first_vol and vol_length as user-specified variables at beginning of code to be fed into t_min and t_size, respectively, 
aimed to reduce chance of user error or confusion in the future, and make code more robust for other studies. 
Created loop to cycle through tasks  
"""

"""
"""




#**********************************************************************************************************************************************
#Please change the data paths below! 

import nipype.interfaces.fsl as fsl
from nipype.interfaces.fsl import Merge
from nipype.interfaces.fsl import ExtractROI
import nipype.interfaces.afni as afni
import nipype.interfaces.ants as ants
import os

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

#manually give input directory where your images are stored
dir_start = '/Users/shefalirai/Downloads/bids-files/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 
participants = ['sub-parker']

#what sessions do you want to run on? If all, type ['ses-1','ses-2', 'ses-3', 'ses-4']
imagesession = ['ses-2']


#what tasks do you want to run on?
tasks = ['rsfMRI_run-1', 'rsfMRI_run-2', 'vanilla_run-1', 'vanilla_run-2', 'vanilla_run-3']

#what is the first volume you want to keep?
#note, fsl is base 0, so first_vol = 5 will keep the 6th volume in a series and discard volumes 0, 1, 2, 3, 4
first_vol = 5 

#how many volumes total do you want to keep?
#for precise kids, we want to keep 205 volumes of the original 210 volume series
vol_length = 140

#do you want to delete the original *_bold.nii.gz file that contains dummy volumes? 
#can remove to save some local storage, as originals are located on lab server
remove_original = False

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = False



#**********************************************************************************************************************************************
#The code below doesn't need to be changed or altered, user specifications above!

participant_folders = sorted(os.listdir(dir_start))

#Remove dummy volumes from all your runs and echoes
for i in participants:
    #person = participant_folders[i]
    person = i
    for j in imagesession:
        for t in tasks: 
                dir_input = dir_start + person + '/' + j + '/func/'
                input_file = dir_input + person + '_' + j + '_' + t + '_bold.nii.gz'
                output_file = dir_input + person + '_' + j + '_' + t + '_boldDis.nii.gz'
                if os.path.isfile(input_file) == False:
                    x = "This file doesn't exist: " + input_file
                    print(x)
                    doit = False
                if os.path.isfile(output_file) == True:
                    x = "FSL ExtractROI didn't run, output file already exists for: " + person + "_" + j + "_" + t + "_" 
                    print(x)
                    doit = False
                else:
                    doit = True
                    if doit == True:
                        x = "FSL ExtractROI is running on: " + person + "_" + j + "_" + t + "_bold.nii.gz"
                        print(x)
                        try:
                            fslroi = ExtractROI()
                            fslroi.inputs.in_file = dir_input + person + '_' + j + '_' + t + '_bold.nii.gz'
                            fslroi.inputs.roi_file = dir_input + person + '_' + j + '_' + t + '_boldDis.nii.gz'
                            fslroi.inputs.t_min = first_vol
                            fslroi.inputs.t_size = vol_length 
                            fslroi.run()
                            x = "Fslroi probably removed 5 dummy volumes from: " + person + " " + j + " " + t + " " 
                            print(x)
                            if remove_original == True:
                               os.remove(dir_input + person + '_' + j + '_' + t + '_bold.nii.gz')
                               y = "Removed file: " + dir_input + person + "_" + j + "_" + t + "_bold.nii.gz"
                               print(y)
                        except Exception as e: print(e)

                                
                        
                   
                

