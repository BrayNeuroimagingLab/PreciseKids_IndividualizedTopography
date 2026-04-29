#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed Sep 21 11:31:35 2022

@author: kgodfrey

To provide list of accepted components, must go to the last line of script in subprocess.call
Provide the list of all accepted components (green, red, and blue) after the --manacc arguement
Find components in desc-tedana_metrics.tsv file
"""

import os
import subprocess 
import shutil
import time

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

#what directory are your images saved in?
dir_start = '/Volumes/Prckids/'

#what participant do you want to run this on?
participant = 'sub-1973026C'

#what session are you manually running?
session = 'ses-1'

#what tedana output do you want copied to the main folder for future analysis?
#desc-optcomDenoised_bold.nii.gz recommended on tedana website
OC_output = 'desc-optcomDenoised_bold_strictmotion.nii.gz'

#rename = True will rename the output based on BIDs specification
rename = True
#what do you want the renamed tedana output to be?
OC_rename_output = 'dn_ts_OC_strictmotion.nii.gz.nii.gz'

#merged echo file names
merged_echo1 = "task-allvideos_mergedses_echo-1"
merged_echo2 = "task-allvideos_mergedses_echo-2"
merged_echo3 = "task-allvideos_mergedses_echo-3"

#echotimes
TE1 = '13'
TE2 = '32.3'
TE3 = '51.6'

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = True

#name of log book that output is saved to
logname = 'xtedana_manual.txt'

#get the current time
totaltimer = time.time()

# Aside from modifying the --manacc arguement, this code shouldn't need changing

dir_in = dir_start + participant + '/' + session + '/func/'
dir_out = dir_start + participant + '/' + session + '/func/tedana_strictmotion/'

input_file1 = dir_in + participant + '_' + session + '_' + merged_echo1 + '_flirtboldStcMcf.nii.gz'
input_file2 = dir_in + participant + '_' + session + '_' + merged_echo2 + '_flirtboldStcMcf.nii.gz'
input_file3 = dir_in + participant + '_' + session + '_' + merged_echo3 + '_flirtboldStcMcf.nii.gz'

tedana1_dir = dir_start + participant + '/' + session + '/func/tedana1/'
t2_map = dir_start + participant + '/' + session + '/func/tedana1/' + 'T2starmap.nii.gz'
mix_matrix = dir_start + participant + '/' + session + '/func/tedana1/' 'desc-ICA_mixing.tsv'
comp_table = dir_start + participant + '/' + session + '/func/tedana1/' 'desc-tedana_metrics.tsv'

#everything in log gets saved to the logbook. Text often gets appended to log
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())

sublog = ["*************************************************"]
sublog.append('Starting log for ' + time.ctime())


doit = True

if os.path.isdir(dir_out) == True:
    if replacer == False:
        x = "Manual tedana for " + participant + " " + session + " already run"
        print(x)
        doit = False
        
if doit == True:
    
    x = "Running manual tedana for " + participant + " " + session 
    print(x)
    log.append(x)
    sublog.append(x)
    
    os.chdir(dir_in)
    #subprocess.call(['tedana', '-d' , input_file1 , input_file2 , input_file3 , '-e', TE1, TE2, TE3, '--out-dir', dir_out, '--tedpca','aic', '--t2smap', t2_map, '--ctab', comp_table, '--manrej', '018', '000', '125', '128', '070', '048', '162', '073', '023', '122', '101','--mix', mix_matrix])
    subprocess.call(['ica_reclassify', '--manrej', '018', '000', '125', '128', '070', '048', '162', '073', '023', '122', '101', '/Volumes/Prckids/sub-1973026C/ses-1/func/tedana1' ])
    shutil.copy(dir_out + OC_output, dir_in)
    
    if rename == True:
       os.rename(dir_in + OC_output, dir_in + participant + '_' + session + '_' + OC_rename_output)
    
    x = "Manual tedana complete"
    log.append(x)
    print(x)
    
    x = "No components kept only removed for strict motion pipeline #2 "  #+ str(['001','002','003','011','013','014','016','029','031','033','035','037','039','042','044','047','049','051','052','054','058','064','065','068','069','070','071','074','075','076','078','079','080','081','082','083','084','090','091','092','098','099','103','104','105','112','120','121','124','128','129','130','131','132','133'])
    log.append(x)
    print(x)
        
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

with open(logname, 'a') as f:
    for item in log:
        f.write("%s\n" % item)
f.close()  




