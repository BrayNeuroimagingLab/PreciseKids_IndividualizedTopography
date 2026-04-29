#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FSL ExtractRoi to split/decompose tedana output of optimally combined file in 6 video runs
!!PLEASE NOTE!!
*** You can press run file, no manual changes or edits needed to this script ***


Side note: This script will decompose in the SAME order used from fslcoregmerge.py file

@author: shefalirai

Update Log

V1.2 
Kate updated code to specify that runs are 205 volumes (previously 195)
"""

import nipype.interfaces.fsl as fsl
from nipype.interfaces.fsl import ExtractROI
import nipype.interfaces.afni as afni
import nipype.interfaces.ants as ants
import os
import argparse
import shutil
import time


#what directory are your images saved in?
dir_start = '/Volumes/Prckids/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = ['sub-1973026C']
participant_folders = sorted(os.listdir(dir_start))

#what sessions do you want to run on? If all, type imagesession = ['ses-1','ses-2', 'ses-3', 'ses-4']
imagesession = ['ses-1','ses-2','ses-3','ses-4']
#imagesession = ['ses-3']

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = False

OCinput='dn_ts_OC_motion'

#Order matters!
#video files to decompose to
Dora1OCoutput= 'task-DORA1_OC_motion'
Dora2OCoutput= 'task-DORA2_OC_motion'
RX1OCoutput= 'task-RX1_OC_motion'
RX2OCoutput= 'task-RX2_OC_motion'
YT1OCoutput= 'task-YT1_OC_motion'
YT2OCoutput= 'task-YT2_OC_motion'


                    
for i in participants:
    #person = participant_folders[i]
    person = i
    for j in imagesession:
        dir_in = dir_start + person + '/' + j + '/func/'
        input_file = dir_in + person + '_' + j + '_' + OCinput + '.nii.gz'
        output_file = dir_in + person + '_' + j + '_' + YT2OCoutput + '.nii.gz'
        if os.path.isfile(input_file) == False:
            x = "This file doesn't exist: " + input_file
            print(x)
            doit = False
        else:
            doit = True
            if replacer == False:
                if os.path.isfile(output_file) == True:
                    x = "FSL Extract ROI did not decompose; file already exists for " + output_file
                    print(x)
                    doit = False                
        if doit == True:
            x = "FSL ExtractROI is beginning to decompose videos for: " + person + ' ' + j
            print(x)
            try:
                os.chdir(dir_in)
                fslroi = ExtractROI()
                fslroi.inputs.in_file = input_file
                fslroi.inputs.roi_file = dir_in +  person + "_" + j + "_" + Dora1OCoutput + ".nii.gz"
                fslroi.inputs.output_type = "NIFTI_GZ" 
                fslroi.inputs.t_min = 0
                fslroi.inputs.t_size = 205
                fslroi.run()
                fslroi = ExtractROI()
                fslroi.inputs.in_file = input_file
                fslroi.inputs.roi_file = dir_in +  person + "_" + j + "_" + Dora2OCoutput + ".nii.gz"
                fslroi.inputs.output_type = "NIFTI_GZ" 
                fslroi.inputs.t_min = 205
                fslroi.inputs.t_size = 205
                fslroi.run()
                fslroi = ExtractROI()
                fslroi.inputs.in_file = input_file
                fslroi.inputs.roi_file = dir_in +  person + "_" + j + "_" + RX1OCoutput + ".nii.gz"
                fslroi.inputs.output_type = "NIFTI_GZ" 
                fslroi.inputs.t_min = 410
                fslroi.inputs.t_size = 205
                fslroi.run()
                fslroi = ExtractROI()
                fslroi.inputs.in_file = input_file
                fslroi.inputs.roi_file = dir_in +  person + "_" + j + "_" + RX2OCoutput + ".nii.gz"
                fslroi.inputs.output_type = "NIFTI_GZ" 
                fslroi.inputs.t_min = 615
                fslroi.inputs.t_size = 205
                fslroi.run()
                fslroi = ExtractROI()
                fslroi.inputs.in_file = input_file
                fslroi.inputs.roi_file = dir_in +  person + "_" + j + "_" + YT1OCoutput + ".nii.gz"
                fslroi.inputs.output_type = "NIFTI_GZ" 
                fslroi.inputs.t_min = 820
                fslroi.inputs.t_size = 205
                fslroi.run()
                fslroi = ExtractROI()
                fslroi.inputs.in_file = input_file
                fslroi.inputs.roi_file = dir_in +  person + "_" + j + "_" + YT2OCoutput + ".nii.gz"
                fslroi.inputs.output_type = "NIFTI_GZ" 
                fslroi.inputs.t_min = 1025
                fslroi.inputs.t_size = 205
                fslroi.run()
                x = "FSL ROI probably decomposed OC file into 6 video runs"
                print(x)
                
            except Exception as e: print(e)
            


#Wrap up the program



        
        