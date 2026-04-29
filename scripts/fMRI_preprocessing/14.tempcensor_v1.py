#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Feb 15 13:26:47 2023

@author: kgodfrey
"""

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

import shutil
import nilearn
import os
import nibabel as nib
import numpy as np

#what directory are your images saved in?
dir_start = '/Volumes/Prckids/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
participants = [7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,
               31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,53,54,55,56]
#participants =[9] #003C no YT2
#participants =[52] #024P ses-6 not ses-4

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-4']

#what tasks do you want to run this on?
tasks = ['task-DORA','task-RX','task-YT']

#what folder are you in?
folder = 'mergeruns'

#do you want to censor the first volume from each run?
#this script makes the assumption that your runs are 205 volumes long
#if this assumption isn't true, will need to modify
censorfirst = True

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = False

censorinput = 'OCDetFltRegNewMStrcWarpCl.nii.gz'

censoroutput = 'OCDetFltRegNewMStrcWarpClTc.nii.gz'

tmask = 'OCMASK_TEMPORAL.txt'

doit = True

for i in participants:
    person = participant_folders[i]
    #person = i
    for j in imagesession:
        for t in tasks:
            dir_in = dir_start + person + '/' + j + '/func/' + folder + '/' 
            input_file = dir_in + person + '_' + j + '_' + t + '_' + censorinput
            output_file = dir_in + person + '_' + j + '_' + t + '_' + censoroutput
            input_tmask = dir_in + person + '_' + j + '_' + t + '_' + tmask
            
            if os.path.isfile(input_file) == False:
                x = "This file doesn't exist: " + input_file
                print(x)
                #log.append(x)
            else:
                doit = True
                if replacer == False:
                    if os.path.isfile(output_file) == True:
                        x = "Temporal censor did not run, file already exists: " + output_file
                        print(x)
                        doit = False          
            if doit == True:
                x = "Temporal censoring is beginning to run on: " + person + " " + j + " " + t
                print(x)
                try:
                    #load the input file
                    #image = nilearn.image.load_img(input_file)
                    image = nib.load(input_file)
                    
                    #get data from the input file
                    image_data = image.get_fdata()

                    #load the mask
                    if os.path.isfile(input_tmask) == True:
                        #determine the timepoints marked for censoring
                        index = []
                        currentline = 0
                        with open(input_tmask) as file:
                            for line in file:
                                if int(line) == 0:
                                   index.append(0)
                                else: 
                                    index.append(1)
                                currentline = currentline + 1  
                                
                    #print(index)
                    
                    if censorfirst == True:
                        
                        #fsl is base 0 system, so this specifies we
                        #don't keep the first volume of run 1
                        index[0] = 0
                        
                        #specify that you don't keep the 206th volume
                        #which is the first volume of run 2
                        index[205] = 0 #need to comment this line index[205] if missing second run of any task
                        
                    #print(index)
                    
                    index_bool = list(map(bool,index))
                    #print(index_bool)

                    #index the data in the 4th demnision based on the mask boolian
                    image_data_kept = image_data[:,:,:,index_bool]
                    
                    #trying to save the data
                    #get original data array shape from the original header
                    image.header.get_data_shape()
                    #construct new empty header
                    empty_header = nib.Nifti1Header()
                    empty_header.get_data_shape()
                    
                    image_to_save = nib.Nifti1Image(image_data_kept,image.affine,empty_header)
                    image_to_save.header.get_data_shape()

                    nib.save(image_to_save,output_file)
                    
                except Exception as e: print(e)
                