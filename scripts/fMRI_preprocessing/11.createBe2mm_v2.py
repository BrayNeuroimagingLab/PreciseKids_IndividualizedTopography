#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Mar  2 09:10:53 2023

@author: kgodfrey

This script will create a 2mm version of the brain extracted structural image
which the final bold output will be warped to

V2 Log: Shefali
This version is for child participants with ses label in their brain extracted T1 image! Will error on parent files since no ses label is added to their T1 images. But this is an easy fix if needed. 
Removed anat_ses variable so we can loop through sessions to find correct anat folder for each participant, no need to write manually

Note: this script outputs intermediate .mat files in the path where this script is located if you run it through python/spyder, you can delete all those files. If you run through terminal, no intermediate files will be outputted.


"""

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""
import os


#what folder are your images stored in?
dir_start = '/Users/shefalirai/Downloads/bids-files/'

#which subjects do you want this to run on?
participants = ['sub-parker']

#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#for loop with new if statement to find where anat folder with T1w image is located
all_sessions = [0,1] #all sessions for participant

#which anatomical session is being used for each participant?
#should match 'participants' respectively
#anat_ses = ['ses-4']

#what is the structural input? brain extracted T1
struct_input = 'T1wFltmeanAbfcBe'

#what is the structural output? brain extracted T1 resampled to 2mm^3
struct_output = 'T1wFltmeanAbfcBe2mm'

#input white matter associated with struct_input
wmbinary_input = 'T1wFltmeanAbfcBeWM_binary'

#output white matter resampled to 2mm^3
wmbinary_output = 'T1wFltmeanAbfcBeWM_binary2mm'

#what threshold are we using for the 2mm white matter mask?
#anything below this threshold is discarded
threshold= "50"


from nipype.interfaces import fsl

#a = -1

#for person in participants:
for i in participants:
    #person = participant_folders[i]
    person = i
    for j in all_sessions: 
        ses = sorted(os.listdir(dir_start + person))
        session = ses[j]
        if os.path.exists(dir_start + person + "/" + session + "/anat/"):
            x = "found anat folder in " + session + " Resampling now"
            print(x)
            #a = a + 1
            #dir_in = dir_start + person + '/' + anat_ses[a] + '/anat/' 
            dir_in = dir_start + person + '/' + session + '/anat/'
            
            struct_inputfile = dir_in + person + '_' + struct_input + '.nii.gz'
            struct_outputfile = dir_in + person + '_' + struct_output + '.nii.gz'
            
            wmbinary_inputfile = dir_in + person + '_' + wmbinary_input + '.nii.gz'
            wmbinary_outputfile = dir_in + person + '_' + wmbinary_output + '.nii.gz'
            
            x = "FLIRT is resampling Be structural: " + struct_inputfile
            print(x)
            myflirt = fsl.FLIRT()
            myflirt.inputs.in_file = struct_inputfile
            myflirt.inputs.reference = struct_inputfile
            myflirt.inputs.output_type = "NIFTI_GZ"
            myflirt.inputs.apply_isoxfm = 2.0
            myflirt.inputs.no_search = True
            myflirt.inputs.out_file = struct_outputfile
            myflirt.run()
            x = "FLIRT probably created 2mm Be structural: " + struct_outputfile
            print(x)
            
            x = "FLIRT is resampling WM binary: " + wmbinary_inputfile
            print(x)
            myflirt = fsl.FLIRT()
            myflirt.inputs.in_file = wmbinary_inputfile
            myflirt.inputs.reference = wmbinary_inputfile
            myflirt.inputs.output_type = "NIFTI_GZ"
            myflirt.inputs.apply_isoxfm = 2.0
            myflirt.inputs.no_search = True
            myflirt.inputs.out_file = wmbinary_outputfile
            myflirt.run()
            x = "FLIRT probably created 2mm WM Mask: "
            print(x)
            
            x = "FSL is thresholding WM binary"
            print(x)
            mymath = fsl.ImageMaths()
            mymath.inputs.in_file = wmbinary_outputfile
            mymath.inputs.args = "-thrp " + threshold
            mymath.inputs.out_file = wmbinary_outputfile
            mymath.run() 
            x = "FSL thresholding complete"
            print(x)
            
            x = "FSL is making a mask of 2mm WM binary"
            print(x)
            mymath = fsl.ImageMaths()
            mymath.inputs.in_file = wmbinary_outputfile
            mymath.inputs.args = "-bin"
            mymath.inputs.out_file = wmbinary_outputfile
            mymath.run() 
            x = "Mask generation complete"
            print(x)

