
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Edited March 15, 2022 for prckids


Created on Tue Jul 21 17:22:13 2020
@author: shefalirai


Update Logs: 

Update Log V2 (Kate)
Added task loop, so the script will loop through each task rather than being run manually
Added ischild arguement, rather than manually changing lines throughout the rest of the script to specify adult or child templates
Script will manually check for existance of 2mm MNI adult and NIHPD child templates, and if not it will create them
Added anat_ses variable, which will provide a list to specify what folder has the anatomical data
    Replaced 'samesesanat' variable for finding anatomical folder
Added assignTR step, so script will still work if 'test' step is not run
    Assumes that all subjects have the same TRs
Script now saves a separate 'summary log' with only major preprocessing decisions to be referenced if needed

Update Log V3 (Kate + Shefali)
Have removed resamplemaster and templatear arguements which previously referenced different MNI template resolutions
    No using a single templateimage variable, which will use the same MNI throughout the script
    
Update Log V4 (Kate)
Removed sections to generate 2mm MNI template (no longer using)
Specifying what template will be used by all steps under general program options

Update Log V5 (Kate)
Moved warp to MNI to be it's own step, to make the preprocessing pipeline more clear
Added 'newmean' step - to assign the same mean to all runs, useful for concatenation
Updated filterhmpinput to 'echo-2_boldStcMcf.nii.gz.par' to use slice time corrected estimates
    Before we were using 'echo-2_boldMcf.nii.gz.par'

Update Log V6 (Kate)
filterhmpinput returned to to 'echo-2_boldMcf.nii.gz.par', to use raw data estimates prior to slicetime correction, based on 
    Power, J. D., Plitt, M., Kundu, P., Bandettini, P. A., & Martin, A. (2017). Temporal interpolation alters motion in fMRI scans: 
    Magnitudes and consequences for artifact detection. PloS One, 12(9), e0182939–e0182939. https://doi.org/10.1371/journal.pone.0182939

export PATH=$PATH:/Users/kgodfrey/antsbin
export PATH=$PATH:/Users/kgodfrey/abin
export PATH=$PATH:/Applications/Convert3DGUI.app/contents/bin
cd /Users/kgodfrey/Documents/preciseKIDS/ME_Preprocessing


"""

import argparse
import shutil
import os
from re import search

"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""

#what directory are your images saved in?
dir_start = '/Volumes/PKBackup/preprocessed/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
#participants = ['sub-1973002C', 'sub-1973003C', 'sub-1973004C', 'sub-1973005C', 'sub-1973006C', 'sub-1973007C', 'sub-1973008C', 'sub-1973009C', 'sub-1973010C', 'sub-1973011C', 'sub-1973012C', 'sub-1973013C', 'sub-1973014C', 'sub-1973015C', 'sub-1973016C', 'sub-1973017C', 'sub-1973018C', 'sub-1973019C', 'sub-1973020C', 'sub-1973021C', 'sub-1973022C', 'sub-1973023C', 'sub-1973024C', 'sub-1973025C', 'sub-1973026C']
#participants =['sub-1973002P', 'sub-1973003P', 'sub-1973004P', 'sub-1973005P', 'sub-1973006P', 'sub-1973007P', 'sub-1973008P', 'sub-1973009P', 'sub-1973010P', 'sub-1973011P', 'sub-1973012P', 'sub-1973013P', 'sub-1973014P', 'sub-1973015P', 'sub-1973016P', 'sub-1973017P', 'sub-1973018P', 'sub-1973019P', 'sub-1973020P', 'sub-1973021P', 'sub-1973022P', 'sub-1973023P', 'sub-1973025P', 'sub-1973026P'] #003C no YT2
participants =['sub-1973024P'] #024P ses-6 not ses-4


#get a list of everything in the starting directory
participant_folders = sorted(os.listdir(dir_start))

#what sessions do you want to run this on?
imagesession = ['ses-1','ses-2','ses-3','ses-6']

#what tasks do you want to run this on?
tasks = ['task-DORA1','task-DORA2','task-RX1','task-RX2','task-YT1','task-YT2']

#what is your tr? used for fourier transform steps
tr = 2

#fs is a constant for fourier transform, based on tr
fs = 1/tr

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = False

#name of subfolder where outputs are saved 
regfolder = '/regression/'

#name of log book that output is saved to
logname = 'regression_v2hmp.txt'
#do you want to save to the log book?
savelog = True

#name of summary log book saved to
summarylogname = 'xocregression_v2hmp.txt'
#do you want to save to the summary log
savesummarylog = True

steps = ['remean']
#steps = ['test','createtmask','makedetrendreg','rundetrendreg','filterall','gs','ns','filterhmp','makereg','runreg','newmean']
#This part is if you want volume smoothing, ,currently not using
#steps = ['smooth'] #DO NOT RUN IF PREPROCESSING other than template matching!

"""general steps"""
    #test = examine if input files exist
    #createtmask = create temporal mask

"""detrend steps - removing linear and quadratic trend, and demean, via linear regression"""
    #makedetrendreg - make excel file with regression data
    #rundetrendreg - run detrend on whole brain

"""filter steps - run a bandpass filter via fft and ifft"""
    #filterall - filter the whole brain

"""signal steps"""
    #gs - find the global signal after filtering
    #ns - find the signal for CSF and WM after filtering

"""filter HMP"""
    #filterhmp - detrends + interpolates + filters HMP data
    #no longer interpolating HMP data

"""regression steps"""
    #makereg - make excel file with all regression data
    #runreg - run full regression on whole brain    

"""remean steps"""
    #remean - add the mean to the output of the last step


"""*********************************"""
"""test: test that first file exists"""
"""also makes summary log with all  """
"""regression decisions             """
"""*********************************"""
#go to test step and adjust to save all 
#regression decisions for later reference


"""*****************************************"""
"""createtmask: create temporal mask OPTIONS"""
"""*****************************************"""
#head motion estimations, based on filtered power method
tmaskinput = 'echo-2_PowerFDFlt0.15_v2.csv'

#output is a binary list with 0 = discard, 1 = keep
tmaskoutput = 'OCMASK_TEMPORAL'

#anything above this value is marked for censoring
tmaskthreshold = 0.15


"""**********************"""
"""MAKEDETRENDREG OPTIONS"""
"""**********************"""
#temporal mask file
mdtmaskname = 'OCMASK_TEMPORAL'

#name of regressors file that is saved. Saved to regression subfolder
mdregname = 'OCdetrend.csv'


"""*********************"""
"""RUNDETRENDREG OPTIONS"""
"""*********************"""
#file you want to run it on. From the main folder
rdimagename = 'OC.nii.gz'

#spatial mask file. From the main folder
#rdmaskname = 'OCRefConsbet_mask.nii.gz'
rdmaskname = 'OCRef_mask.nii.gz'

#temporal mask file. In the regression subfolder
rdtmaskname = 'OCMASK_TEMPORAL'

#output file of just the residuals. Saved to regression subfolder
rdimagenameoutput = 'OCDet.nii.gz'

#output file of the means. Saved to regression subfolder
rdmeanfile = 'OC_Mean.nii.gz'

#input of all regressors. From the regression subfolder
rdreginput = 'OCdetrend.csv'


"""**************"""
"""FILTER OPTIONS"""
"""**************"""
#file you want to run it on. From regression subfolder
filterimagename = 'OCDet.nii.gz'

#spatial mask file
#filtermaskname = 'OCRefConsbet_mask.nii.gz'
filtermaskname = 'OCRef_mask.nii.gz'

#output file of just the residuals. Saved to regression subfolder
filterimagenameoutput = 'OCDetFlt.nii.gz'

#FILTERING SPECS
#highpass
lowcut = 0.01
#lowpass
highcut = 0.08


"""*******************************************"""
"""gs: fslmeants to find global signal OPTIONS"""
"""*******************************************"""
#input file - from the regression subfolder
gsinput = 'OCDetFlt.nii.gz'

#spatial whole brain mask
#gsmask = 'OCRefBet_mask.nii.gz'
gsmask = 'OCRef_mask.nii.gz'

#name of the file with the mean signal at each time point. To regression subfolder
gsoutput = 'OCsignalglobal'


"""*********************************************"""
"""ns: fslmeants to find nuisance signal OPTIONS"""
"""*********************************************"""
#input file - from the regression subfolder
nsinput = 'OCDetFlt.nii.gz'

#CSF and WM spatial masks
nscsfmask = 'OCMASKCSF.nii.gz'
nswmmask = 'OCMASKWM.nii.gz'

#names of the files with the mean signal at each time point. To regression subfolder
nsoutputCSF = 'OCsignalCSFnuisance'
nsoutputWM = 'OCsignalWMnuisance'


"""*****************"""
"""filterhmp OPTIONS"""
"""*****************"""
#this code assumes that you want to use the same detrending as in the "detrend" step

#and that your filtering low and high pass are the same
#and your temporal mask is the same

#text file with 6 head alignment estimates
filterhmpinput = 'echo-2_boldMcf.nii.gz.par'

#output file of just the residuals. Saved to regression subfolder
filterhmpoutput = 'echo-2_boldMcf.nii.gz.par_flt.csv'


"""***************"""
"""MAKEREG OPTIONS"""
"""***************"""
#text file with 6 head alignment estimates
regheadmotionname = 'echo-2_boldMcf.nii.gz.par_flt.csv'

#temporal mask name
regtmaskname = 'OCMASK_TEMPORAL'

#white matter signal text file - from regression directory
regwmname = 'OCsignalWMnuisance'
#csf signal text file - from regression directory
regcsfname = 'OCsignalCSFnuisance'
#text file with global signal - from regression directory
regglobalsigname = 'OCsignalglobal'

#name of regressors file that is saved
regname = 'OCregressors.csv'


"""**************"""
"""RUNREG OPTIONS"""
"""**************"""
#file you want to run it on
regimagename = 'OCDetFlt.nii.gz'

#mask file
#regmaskname = 'OCRefConsbet_mask.nii.gz'
regmaskname = 'OCRef_mask.nii.gz'

#output file of just the residuals
regimagenameoutput = 'OCDetFltReg.nii.gz'

#input of all regressors
reginput = 'OCregressors.csv'


"""**************"""
"""REMEAN OPTIONS"""
"""**************"""
#file you want to run it on
remeanimagename = 'OCDetFltReg.nii.gz'

#mean file
remeanmean = 'OC_Mean.nii.gz'

#output file
remeanoutput = 'OCDetFltRegRem.nii.gz'

"""**************"""
"""NEWMEAN OPTIONS"""
"""**************"""

#first we will take the spatial mask, which has 0's and 1's 
#and multiply it by the new mean to get a mask of the new mean to be added.

#spatial whole brain mask, from the main folder
#same mask as used in the 'detrend' step to make original mean mask
newmean_maskinput = 'OCRef_mask.nii.gz'

#new mean mask file, same shape as spatial mask which has mean to be added 
newmean_maskoutput = 'OCRefNewM_mask.nii.gz'

#what do you want the new mean to be?
newmean = '1000'

#what is the input timeseries file?
newmeaninput = 'OCDetFltReg.nii.gz'

#what is the output file?
newmeanoutput = 'OCDetFltRegNewM.nii.gz'


"""****************"""
"""SMOOTH OPTIONS"""
"""****************"""
#file you want to run it on
smoothinput = 'OCDetFltRegNewM.nii.gz'

#output file
smoothoutput = 'OCDetFltRegNewMSm.nii.gz'


"""*****************************************"""
"""ANYTHING BELOW HERE DOESN'T NEED CHANGING"""
"""**********(OR SO KIRK HOPES)*************"""
"""*****************************************"""

import nipype.interfaces.fsl as fsl
import nipype.interfaces.ants as ants
from nipype.interfaces import afni
import os
import numpy as np
import pandas as pd
import nibabel as nib
import statsmodels.api as sm
#import matplotlib.pyplot as plt
import time
from scipy.fftpack import fft, ifft
import csv
#Kate removed the following due to a depreciated warning:
#from astropy.stats import LombScargle
#instead used:    
from astropy.timeseries import LombScargle

"""
person = participant_folders[0]
j = imagesession[0]
dir_in = dir_start + person + "/" + j + "/func/"
input_file = dir_in + person + "_" + j + "_" + rdimagename
img = nib.load(input_file)
image_data = img.get_fdata()
header_stuff = img.header
tr = header_stuff['pixdim'][4]
fs = 1/tr
print(fs)
"""

endit = False

#check if your template image exists
#if os.path.isfile(templateimage) == False: 
#   print("Your template image doesn't exist")
#   endit = True
   
   
#get the current time
totaltimer = time.time()

#everything in log gets saved to the logbook. Text often gets appended to log
log = ["*************************************************"]
log.append('Starting log for ' + time.ctime())
log.append('')      

#everything in log gets saved to the logbook. Text often gets appended to log
summarylog = ["*************************************************"]
summarylog.append('Starting log for ' + time.ctime())   
summarylog.append('')   


for k in steps: 
    
    if (k == 'test') & (endit == False):
       #a = -1
       for i in participants:
           #person = participant_folders[i]
           person = i
           #a = a + 1
          
           dir_in = dir_start + person + '/' + imagesession[0] + '/func/'
           input_file = dir_in + person + '_' + imagesession[0] + '_' + tasks[0] + '_' + rdimagename
           #input_anat_ses = dir_in + person + '_' + anat_ses[a]
           if replacer == True:
              print("You will replace any old files that already exist")
           else:
              print("You will not replace any old files that already exist")
              print("")
      
              print("Checking your inputs:")
              
           if os.path.isfile(input_file) == True:
              print("Your first input file exists! It is " + input_file) 
              
           else:
             print("Your first input file does not exist. It should be")
             print(input_file)
             endit = True
    
           x = ""
           print(x)
           log.append(x)
           
           x = "Settings you've entered:"
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "Your directory is: " + dir_start
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "Your person is: " + person
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "You are running the following tasks: " + str(tasks)
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "You are running the following sessions: " + str(imagesession)
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "You specified your tr as: " + str(tr)
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "Your temporal mask threshold is: " + str(tmaskthreshold)
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "Your highcut filtering threshold is: " + str(highcut)
           print(x)
           log.append(x)
           summarylog.append(x)
           
           x = "Your lowcut filtering threshold is: " + str(lowcut)
           print(x)
           log.append(x)
           summarylog.append(x)

           x = "Your new mean value is: " + str(newmean)
           print(x)
           log.append(x)
           summarylog.append(x)
           
           #add a couple of blank lines to the log lists, make them look nicer
           log.append('')
           log.append('')
           
           summarylog.append('')
           summarylog.append('')
                         
    if (k == 'createtmask') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks: 
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + person + '_' + j + '_' + task + '_' + tmaskinput                
                    regdir = dir_in + regfolder
                    
                    #check if regression subfolder exists, if not then make it
                    if not os.path.exists(regdir):
                       os.makedirs(regdir)
                    #specify output file path which includes the regression directory   
                    output_file = regdir + person + '_' + j + '_' + task + '_' + tmaskoutput
    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Temporal mask did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            x = "Temporal mask is beginning to run on: " + person + '_' + j + '_' + task + '_' + tmaskinput 
                            print(x)
                            log.append(x)
                            try:
                                fd = []
                                with open(input_file) as file:
                                    csv_reader = csv.reader(file)
                                    next(file)
                                    for line in csv_reader:
                                        fd.append(float(line[1]))
                                
                                binarybad = []
                                for i in range(len(fd)):
                                    if fd[i] > tmaskthreshold:
                                        binarybad.append(0)
                                    else:
                                        binarybad.append(1)                            
    
                                with open(output_file, 'w') as f:
                                    for item in binarybad:
                                        f.write("%s\n" % item)
                                f.close()                             
                                
                                x = "Temporal mask probably created " + output_file
                                print(x)
                                log.append(x)
                            # except:
                            #     x = "Temporal mask failed."
                            #     print(x)
                            #     log.append(x)
                            except Exception as e: print(e)
                            
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)
                            steptimermin = round(steptimer/60,3)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)        
    
    if (k == 'makedetrendreg') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/'
                    tmaskfile = dir_in + regfolder + person + '_' + j + '_' + task + '_' + mdtmaskname
                    regoutput = dir_in + regfolder + person + '_' + j + '_' + task + '_' + mdregname
    
                    if os.path.isfile(tmaskfile) == False:
                        x = "This file doesn't exist: " + tmaskfile
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(regoutput) == True:
                                x = "Make detrend data did not run; file already exists for " + regoutput
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            #find the current time
                            steptimer = time.time()
                                            
                            timelist = []
                            timelist2 = []
            
                            #increases by 1 for each volume in time series. Added to timelist and timelist2
                            currenttime = 0
                                      
                            #read in temporal mask
                            #also create a list of timepoints, ie 0, 1, 2, 3, 4, 5, etc
                            with open(tmaskfile, 'r') as file:
                                for line in file:
                                    if int(line) == 1:
                                        timelist.append(currenttime)
                                        timelist2.append(currenttime**2)
                                    currenttime = currenttime + 1
            
                            #create a dataframe of the time series, global signal, motion parameters, and the time course
                            allregressorsDF = pd.DataFrame(
                                {'Time' : timelist - np.mean(timelist),
                                 'Time2' : timelist2 - np.mean(timelist2)
                                })
                            
                            #add a constant to dataframe
                            allregressorsDF = sm.add_constant(allregressorsDF)
                                            
                            #save regressors as a CSV file
                            allregressorsDF.to_csv(regoutput)
                            x = "Detrend data saved to " + regoutput
                            log.append(x)
                            print(x)
                            
                            #find the final time, save info to log
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)    
                                 
    if (k == 'rundetrendreg') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + person + '_' + j + '_' + task + '_' + rdimagename
                    input_mask = dir_in + person + '_' + j + '_' + task + '_' + rdmaskname
                    
                    regdir = dir_in + regfolder
                    input_reg = regdir + person + '_' + j + '_' + task + '_' + rdreginput
                    output_file = regdir + person + '_' + j + '_' + task + '_' + rdimagenameoutput
                    mean_output = regdir + person + '_' + j + '_' + task + '_' + rdmeanfile
                    tmaskfile = regdir + person + '_' + j + '_' + task + '_' + rdtmaskname
    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    elif os.path.isfile(input_reg) == True:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Detrend did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
    
                            #find the current time
                            steptimer = time.time()
                            
                            #load the regression df
                            regdata = pd.read_csv(input_reg, index_col=0)
    
                            #load the temporal mask
                            tmask = []
                            with open(tmaskfile, 'r') as file:
                                for line in file:
                                    tmask.append(int(line))
                            
                            timelist = list(range(0,len(tmask)))
                            
                            subtimelist = []
                            missingtime = []
                            
                            for data in range(len(tmask)):
                                if tmask[data] == 1:
                                    subtimelist.append(timelist[data])
                                else:
                                    missingtime.append(timelist[data])
                            
                            fulltime = subtimelist+missingtime
                            
                            #load the image using some package I found called NiBabel
                            img = nib.load(input_file)
                            image_data = img.get_fdata()
                            new_data = image_data.copy()
                                  
                            #load the mask
                            img2 = nib.load(input_mask)
                            mask_data = img2.get_fdata()
                            mean_data = mask_data.copy()
                            
                            #get shape of image data
                            shape = image_data.shape
                            dim_x = shape[0]
                            dim_y = shape[1]
                            dim_z = shape[2]
                                
                            x = "Running the detrend for " + person + " " + j + " " + task
                            print(x)
                            log.append(x)
                            
                            numofvoxels = 0
                            #loop over every possible voxel in 3D space
                            for dimi in range(dim_x):
                                print("Running for x dimension slice " + str(dimi + 1) + " of " + str(dim_x) + " for " + person + " " + j + " " + task)
                                for dimj in range(dim_y):
                                    for dimk in range(dim_z):                              
                                        #only create model if voxel is in brain mask
                                        if mask_data[dimi][dimj][dimk] == 1:
                                            #load series
                                            currentseries = image_data[dimi][dimj][dimk]
                                                                                   
                                            subcurseries = []               
                                            missingseries = []
                                            
                                            for data in range(len(currentseries)):
                                                if tmask[data] == 1:
                                                    subcurseries.append(currentseries[data])
                                                else:
                                                    missingseries.append(0)
                                            
                                            mean = sum(subcurseries)/len(subcurseries)                                        
                                            
                                            timeseriesDF = pd.DataFrame(
                                                {'Time_Series': subcurseries
                                                })  
                                            y = timeseriesDF["Time_Series"] 
                                                 
                                            #create the model. Predict y (the time series) as a function of X (all the nuisance regressors)
                                            model = sm.OLS(y, regdata).fit()
                                            residuals = model.resid.tolist()
                                            #constant = model.params['const']
    
                                            numofvoxels = numofvoxels + 1
                                            
                                            fulldata = residuals+missingseries
                                            fulldata = [fulldata for _,fulldata in sorted(zip(fulltime,fulldata))]                                        
                                            
                                            new_data[dimi][dimj][dimk] = fulldata
                                            mean_data[dimi][dimj][dimk] = mean
                                            
                                            #for testing, this makes every voxel equal to the volume:
                                            #new_data[dimi][dimj][dimk] = [qq for qq in range(len(new_data[dimi][dimj][dimk]))]
                                        else:
                                            new_data[dimi][dimj][dimk] = [0]*len(tmask)
                                            mean_data[dimi][dimj][dimk] = 0
                                                  
                            #save image
                            regressor_img = nib.Nifti1Image(new_data, img.affine, img.header)
                            nib.save(regressor_img,output_file)
                            
                            mean_img = nib.Nifti1Image(mean_data, img2.affine, img2.header)
                            nib.save(mean_img,mean_output)                       
                            
                            x = "Number of voxels updated is " + str(numofvoxels)
                            print(x)
                            log.append(x)
                            
                            #find the final time, save info to log
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)
                            
                            steptimermin = round(steptimer/60,3)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)   
                            
                    else:
                        x = "This file doesn't exist: " + input_reg
                        print(x)
                        log.append(x)                    
   
    if (k == 'filterall') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/' + regfolder
                    input_file = dir_in + person + '_' + j + '_' + task + '_' + filterimagename
                    output_file = dir_in + person + '_' + j + '_' + task + '_' + filterimagenameoutput
                    input_mask = dir_start + person + '/' + j + '/func/' + person + '_' + j + '_' + task + '_' + filtermaskname
    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Filter did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            #find the current time
                            steptimer = time.time()
    
                            #load the image using some package I found called NiBabel
                            img = nib.load(input_file)
                            image_data = img.get_fdata()
                            new_data = image_data.copy()
                                  
                            #load the mask
                            img = nib.load(input_mask)
                            mask_data = img.get_fdata()
                            
                            #get shape of image data
                            shape = image_data.shape
                            dim_x = shape[0]
                            dim_y = shape[1]
                            dim_z = shape[2]
    
                            #length of time series
                            N = shape[3]
    
                            #this spits out the timepoints. 0, 2.5, 5, 7.5 etc
                            t = np.linspace(0.0, N/fs-1/fs, N)
    
                            #this creates an x axis from 0 to half of fs. This x axis has half as many points as N
                            tf = np.linspace(0.0,fs/2,int(N/2))
    
                            #define upper and lower frequencies
                            lowpass_freq = highcut
                            highpass_freq = lowcut
    
                            #create a matrix of 0s equal to the length of the timecourse
                            F = np.zeros((N))
                            
                            #define where on the list of 0s is the maximum freq
                            lowidx = int(N / 2) + 1
                            if lowpass_freq > 0:
                                lowidx = np.round(float(lowpass_freq) / fs * N)
                            
                            #define where on the list of 0s is the minimum freq
                            highidx = 0
                            if highpass_freq > 0:
                                highidx = np.round(float(highpass_freq) / fs * N)
                            
                            #put the frequencies between the low and highpoint as 1s (so they're accepted)
                            F[int(highidx):int(lowidx)] = 1
                            #also include the frequencies on the other end. So instead of spots 2:5 of 100, spots 95:98 of 100
                            F = ((F + F[::-1]) > 0).astype(int)
    
    
                            x = "Filtering data for " + person + " " + j + " " + task
                            print(x)
                            log.append(x)
                            
                            numofvoxels = 0
                            numofmaskvoxels = 0
                            #loop over every possible voxel in 3D space
                            for dimi in range(dim_x):
                                print("Running for x dimension slice " + str(dimi + 1) + " of " + str(dim_x) + " for " + person + " " + j + " " + task)
                                for dimj in range(dim_y):
                                    for dimk in range(dim_z):
                                        #only filter if voxel is in brain mask
                                        if mask_data[dimi][dimj][dimk] == 1:
                                            currentseries = image_data[dimi][dimj][dimk]
                                            #this creates amplitude vs time data after a FFT filter. So FFT then an inverse FFT
                                            new_data[dimi][dimj][dimk] = np.real(ifft(fft(currentseries)*F))                                        
                                            numofvoxels = numofvoxels + 1
                                        else:
                                            new_data[dimi][dimj][dimk] = [0]*N
                                            numofmaskvoxels = numofmaskvoxels + 1
                            
                            #save image
                            regressor_img = nib.Nifti1Image(new_data, img.affine, img.header)
                            nib.save(regressor_img,output_file)
                            
                            x = "Number of voxels updated is " + str(numofvoxels)
                            print(x)
                            log.append(x)
                            
                            x = "Number of voxels in mask is " + str(numofmaskvoxels)
                            print(x)
                            log.append(x)
                            
                            #find the final time, save info to log
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)
                            steptimermin = round(steptimer/60,3)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)
                            
                            x = "Voxels per second is " + str(numofvoxels/steptimer)
                            print(x)
                            log.append(x)
              
    if (k == 'gs') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks: 
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + gsinput
                    input_mask = dir_in + person + '_' + j + '_' + task + '_' + gsmask
                    output_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + gsoutput
                    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "fslmeants did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
                            
                            x = "fslmeants will now try to run for global signal. Hopefully the mean time series is nice today."
                            print(x)
                            log.append(x)                        
                            try:
                                mygs = fsl.ImageMeants()
                                mygs.inputs.in_file = input_file
                                mygs.inputs.out_file = output_file  
                                mygs.inputs.mask = input_mask
                                mygs.run()
                                
                                x = "fslmeants probably created " + output_file
                                print(x)
                                log.append(x)
                            except:
                                x = "fslmeants failed."
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

    if (k == 'ns') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + nsinput
                    input_csfmask = dir_in + person + '_' + j + '_' + task + '_' + nscsfmask
                    input_wmmask = dir_in + person + '_' + j + '_' + task + '_' + nswmmask
                    
                    output_CSF = dir_in + regfolder + person + '_' + j + '_' + task + '_' + nsoutputCSF
                    output_WM = dir_in + regfolder + person + '_' + j + '_' + task + '_' + nsoutputWM
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_WM) == True:
                                x = "fslmeants did not run; file already exists for " + output_WM
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
                            
                            x = "fslmeants will now try to run for nuisance signal. Hopefully the mean time series is nice today."
                            print(x)
                            log.append(x)                        
                            try:
                                myns = fsl.ImageMeants()
                                myns.inputs.in_file = input_file
                                myns.inputs.out_file = output_CSF 
                                myns.inputs.mask = input_csfmask
                                myns.run()
                                
                                myns.inputs.out_file = output_WM 
                                myns.inputs.mask = input_wmmask
                                myns.run()
                                
                                x = "fslmeants probably created " + output_WM
                                print(x)
                                log.append(x)
                            # except:
                            #     x = "fslmeants failed."
                            #     print(x)
                            #     log.append(x)
                            except Exception as e: print(e)   
                            steptimer = round(time.time()-steptimer,3)
                            steptimermin = round(steptimer/60,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            log.append(x)
                            print(x)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)

    if (k == 'filterhmp') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    #define file names for this specific kid
                    dir_in = dir_start + person + '/' + j + '/func/'
                    headmotionfile = dir_in + person + '_' + j + '_' + task + '_' + filterhmpinput            
                    output_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + filterhmpoutput 
                    input_reg = dir_in + regfolder + person + '_' + j + '_' + task + '_' + rdreginput
                    tmaskfile = dir_in + regfolder + person + '_' + j + '_' + task + '_'  + rdtmaskname
    
    
                    if os.path.isfile(headmotionfile) == False:
                        x = "This file doesn't exist: " + headmotionfile
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Filter HMP did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:                     
                            x = "We will now try to detrend+filter HMP"
                            print(x)
                            log.append(x)
                            
                            #find the current time                        
                            steptimer = time.time()
                            os.chdir(dir_in)
    
            
                            #read in the detrend regression data
                            regdata = pd.read_csv(input_reg, index_col=0)
                    
                            #read in the temporal mask data
                            tmask = []
                            with open(tmaskfile, 'r') as file:
                                for line in file:
                                    tmask.append(int(line))
                            
                            #create a dictionary of different types of motion signals
                            motiondict = {
                                    'motionR_1' : [],
                                    'motionR_2' : [],
                                    'motionR_3' : [],
                                    'motionR_4' : [],
                                    'motionR_5' : [],
                                    'motionR_6' : []   
                            }        
                    
                            #read in head motion file, put data into dictionary
                            with open(headmotionfile) as file:
                                for line in file:
                                    splitted = line.split()
                                    #create head motion parameters and their  quadratic terms
                                    motiondict['motionR_1'].append(float(splitted[0]))
                                    motiondict['motionR_2'].append(float(splitted[1]))
                                    motiondict['motionR_3'].append(float(splitted[2]))
                                    motiondict['motionR_4'].append(float(splitted[3]))
                                    motiondict['motionR_5'].append(float(splitted[4]))
                                    motiondict['motionR_6'].append(float(splitted[5]))
                            
                            #define names of different types of motion data
                            rawmotion = ['motionR_1','motionR_2','motionR_3','motionR_4','motionR_5','motionR_6']
                            detmotion = ['motionR_1det','motionR_2det','motionR_3det','motionR_4det','motionR_5det','motionR_6det']
                            intmotion = ['motionR_1detint','motionR_2detint','motionR_3detint','motionR_4detint','motionR_5detint','motionR_6detint']
                            fltmotion = ['motionR_1detintflt','motionR_2detintflt','motionR_3detintflt','motionR_4detintflt','motionR_5detintflt','motionR_6detintflt']
                    
                            timelist = list(range(0,len(motiondict['motionR_1'])))
                            
                            #split time into points that are censored and points that aren't                        
                            subtimelist = []
                            missingtime = []
                            
                            for data in range(len(timelist)):
                                if tmask[data] == 1:
                                    #list of accepted timeseries
                                    subtimelist.append(timelist[data])
                                else:
                                    missingtime.append(timelist[data])          
                            fulltime = subtimelist+missingtime
                            
                            ###detrend the data###
                            for rr in rawmotion:
                                testseries = motiondict[rr]
                        
                                #divide the series up into points that are censored and points that aren't
                                subtestseries = []                
                                missingseries = []
                                   
                                for data in range(len(testseries)):
                                    if tmask[data] == 1:
                                        subtestseries.append(testseries[data])
                                    else:
                                        missingseries.append(0)
                                
                                #timeseries
                                timeseriesDF = pd.DataFrame(
                                    {'Time_Series': subtestseries
                                    })  
                        
                                y = timeseriesDF["Time_Series"]
                                                                           
                                #create the model. Predict y (the time series) as a function of X (all the nuisance regressors)
                                model = sm.OLS(y, regdata).fit()
                                residuals = model.resid.tolist()
                                
                                #recreate the full data with the residuals + the points marked for censoring
                                fulldata = residuals+missingseries
                                fulldata = [fulldata for _,fulldata in sorted(zip(fulltime,fulldata))]
                                
                                #add the detrend data to the motion dictionary
                                motiondict[rr+'det'] = fulldata                            
                    
                            ###interpolate the data###                
                            
                            #number of sample points
                            N = len(motiondict['motionR_1'])
                
                            #this spits out the timepoints. If fs=10 and N=500, then 0,0.1,0.2...49.8,49.9
                            t = np.linspace(0.0, N/fs-1/fs, N)
                            
                            #determine the timepoints marked for censoring
                            index = []
                            currentline = 0
                            with open(tmaskfile) as file:
                                for line in file:
                                    if int(line) == 0:
                                        index.append(currentline)
                                    currentline = currentline + 1
                            
                            #create the list of times that do not need censoring. To be fed into model
                            timesteps_subset = np.delete(t, index)
                
                            #missingtime is the timepoints that were interpolated. ie missing from timesteps_subset
                            #note this isn't the same missingtime I defined above. This is different. Yeah, sloppy code writing
                            #sue me. I'm too lazy to fix it
                            missingtime = []
                            for sec in t:
                                if sec not in list(timesteps_subset):
                                    missingtime.append(sec)
                            myInt = 1/fs
                            timepoints = [int(x / myInt) for x in missingtime]
                            
                            #alltime is the timepoints not interpolated + timepoints interpolated. Interpolated times at the end
                            alltime = list(timesteps_subset) + missingtime                        
                            
                   
                            #the frequencies to check for Lomb Scargle
                            frequency = np.linspace(0,0.2,700)
                            frequency = np.delete(frequency,0)
                                
                            for rr in detmotion:
                                testseries = motiondict[rr] 
                                                           
                                #don't interpolate if don't need interpolation. Save time. Create "interpolated data" regardless
                                if sum(index) == 0:
                                    x = "No interpolation needed for signal of " + person + " " + j + " " + task
                                    print(x)
                                    log.append(x)
                                    motiondict[rr+'int'] = testseries
                                else:             
                                    signalz = np.array(testseries)
                                    
                                    #remove the signals marked by temporal mask
                                    signal_subset = np.delete(signalz, index)
                                                    
                                    #see how well every frequency fits the timeseries
                                    power = LombScargle(timesteps_subset,signal_subset).power(frequency)
                                    
                                    frequency_bandpass = []
                                    frequency_low = []
                                    frequency_high = []
                                    power_bandpass = []
                                    power_low = []
                                    power_high = []
                    
                                    #sort based on lowpass and highpass
                                    for i in range(len(frequency)):
                                        if frequency[i] > 0.01:
                                            if frequency[i] < 0.08:
                                                frequency_bandpass.append(frequency[i])
                                                power_bandpass.append(power[i])
                                            else:
                                                frequency_high.append(frequency[i])
                                                power_high.append(power[i])
                                        else:
                                            frequency_low.append(frequency[i])
                                            power_low.append(power[i])                                                    
                                                                            
                                    #create the frequencies to interpolate from
                                    bandpass_list = [frequency_bandpass for _,frequency_bandpass in sorted(zip(power_bandpass,frequency_bandpass))]
                                    bandpass_list = bandpass_list[-30:]
                                    
                                    low_list = [frequency_low for _,frequency_low in sorted(zip(power_low,frequency_low))]
                                    low_list = low_list[-5:]
                                    
                                    high_list = [frequency_high for _,frequency_high in sorted(zip(power_high,frequency_high))]
                                    high_list = high_list[-15:]
                                    
                                    testnewlist = bandpass_list + low_list + high_list
                                    
                                    #create a dataframe of the best LS frequencies and their predictions for the signal value
                                    lsdf = pd.DataFrame({'time':t})
                                       
                                    for i in range(len(testnewlist)):
                                        y_fit = LombScargle(timesteps_subset,signal_subset).model(t,testnewlist[i])
                                        header = 'freq' + str(i)
                                        newdf = pd.DataFrame({header : y_fit- np.mean(y_fit)})
                                        lsdf = lsdf.join(newdf)
                                    
                                    lsdf = sm.add_constant(lsdf)
                                    
                                    #lsdfpartial is only the timepoints that do not require interpolation. It is fed into the model
                                    lsdfpartial = lsdf.copy()
                                    
                                    for i in range(len(lsdfpartial['time'])):
                                        if lsdfpartial['time'][i] not in timesteps_subset:
                                            lsdfpartial = lsdfpartial.drop([i]) 
                                    
                                    del lsdf['time']
                                    del lsdfpartial['time']
                                    lsdfpartial = lsdfpartial.reset_index(drop=True)
                                    
                                    timeseriesDF = pd.DataFrame(
                                        {'Time_Series': signal_subset
                                        })  
                                    y = timeseriesDF["Time_Series"]
                                        
                                    model = sm.OLS(y,lsdfpartial).fit()
                                    
                                    parameters = model.params
                                                                            
                                    #the interpolated data
                                    missing_predictions = []
                                    for py in timepoints:   
                                        missing_predictions.append(sum(lsdf.iloc[py]*parameters))
                                        
                                    #interpolated data
                                    #allpredictions = list(predictions) + missing_predictions
                                    allpredictions = list(signal_subset) + missing_predictions
                                    predictions_final = [allpredictions for _,allpredictions in sorted(zip(alltime,allpredictions))]                                        
                                    
                                    #add the interpolated data to the motion dictionary
                                    motiondict[rr+'int'] = predictions_final
                                                                                                        
                            ###filter the data###
                               
                            #definte the lowpass and highpass                                                                   
                            lowpass_freq = highcut
                            highpass_freq = lowcut
                            
                            #create a matrix of 0s equal to the length of the timecourse
                            F = np.zeros((N))
                            
                            #define where on the list of 0s is the maximum freq
                            lowidx = int(N / 2) + 1
                            if lowpass_freq > 0:
                                lowidx = np.round(float(lowpass_freq) / fs * N)
                            
                            #define where on the list of 0s is the minimum freq
                            highidx = 0
                            if highpass_freq > 0:
                                highidx = np.round(float(highpass_freq) / fs * N)
                            
                            #put the frequencies between the low and highpoint as 1s (so they're accepted)
                            F[int(highidx):int(lowidx)] = 1
                            #also include the frequencies on the other end. So instead of spots 2:5 of 100, spots 95:98 of 100
                            F = ((F + F[::-1]) > 0).astype(int)
                            
                            for rr in intmotion:
                                testseries = motiondict[rr]                                                 
                                #this creates amplitude vs time data after a FFT filter. So FFT then an inverse FFT
                                repaireddata = np.real(ifft(fft(testseries)*F))
                                
                                #add the repaired data to the motion dictionary
                                motiondict[rr+'flt'] = repaireddata          
    
                            #create a sub dictionary of just the filtered data. Save it
                            filterdict = dict((k, motiondict[k]) for k in fltmotion)
                            pd.DataFrame(filterdict).to_csv(output_file, index=False)         
                            
                            x = "Filtered data probably created: " + output_file
                            print(x)
                            log.append(x)
             
                            #find the final time, save info to log
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)       
                         
    if (k == 'makereg') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for p in imagesession:
                for task in tasks:
                    #define file names for this specific kid
                    dir_in = dir_start + person + '/' + p + '/func/'
                    headmotionfile = dir_in + regfolder + person + '_' + p + '_' + task + '_' + regheadmotionname
                    tmaskfile = dir_in + regfolder + person + '_' + p + '_' + task + '_' + regtmaskname
                    wmfile = dir_in + regfolder + person + '_' + p + '_' + task + '_' + regwmname
                    csffile = dir_in + regfolder + person + '_' + p + '_' + task + '_' + regcsfname
                    globalsigfile = dir_in + regfolder + person + '_' + p + '_' + task + '_' + regglobalsigname
                    regoutput = dir_in + regfolder + person + '_' + p + '_' + task + '_' + regname
    
    
                    if os.path.isfile(headmotionfile) == False:
                        x = "This file doesn't exist: " + headmotionfile
                        print(x)
                        log.append(x)
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(regoutput) == True:
                                x = "Make regression data did not run; file already exists for " + regoutput
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            #find the current time
                            steptimer = time.time()
                                            
                            #framewise displacement
                            tmask = []
                            with open(tmaskfile) as file:
                                for line in file:
                                    tmask.append(int(line))
                                  
                            #create dataframe for single timepoint censoring
                            #initially place tmask into dataframe for correct indexing
                            censordf = pd.DataFrame({'tmask':tmask})
                            for i in range(len(tmask)):
                                if tmask[i] == 0:
                                    dfcolumn = []
                                    for j in range(len(tmask)):
                                        dfcolumn.append(0)
                                    dfcolumn[i] = 1
                                    header = 'motion' + str(i)
                                    newdf = pd.DataFrame({header : dfcolumn})
                                    censordf = censordf.join(newdf)
                            del censordf['tmask']
            
                            #create some empty lists. 2 = squared, t = previous time point
                            #pad previous time point parameters with a zero
            
                            globalsig = []
                            globalsig2 = []
                            globalsigt = [0]
                            globalsig2t = [0]                
                            wmsig = []
                            wmsig2 = []
                            wmsigt = [0]
                            wmsig2t = [0]
                            csfsig = []
                            csfsig2 = []
                            csfsigt = [0]
                            csfsig2t = [0]
                            
                            
                            #read in head motion data, create quadratic terms and temporal derivatives
                            data = pd.read_csv(headmotionfile)
                            
                            motionR_1 = list(data.motionR_1detintflt)
                            motionR_2 = list(data.motionR_2detintflt)
                            motionR_3 = list(data.motionR_3detintflt)
                            motionR_4 = list(data.motionR_4detintflt)
                            motionR_5 = list(data.motionR_5detintflt)
                            motionR_6 = list(data.motionR_6detintflt)
                            motionR2_1 = [i ** 2 for i in motionR_1]
                            motionR2_2 = [i ** 2 for i in motionR_2]
                            motionR2_3 = [i ** 2 for i in motionR_3]
                            motionR2_4 = [i ** 2 for i in motionR_4]
                            motionR2_5 = [i ** 2 for i in motionR_5]
                            motionR2_6 = [i ** 2 for i in motionR_6]
                            
                            motionRt_1 = [0] + motionR_1[:-1]
                            motionRt_2 = [0] + motionR_2[:-1]
                            motionRt_3 = [0] + motionR_3[:-1]
                            motionRt_4 = [0] + motionR_4[:-1]
                            motionRt_5 = [0] + motionR_5[:-1]
                            motionRt_6 = [0] + motionR_6[:-1]
                            motionR2t_1 = [0] + motionR2_1[:-1]
                            motionR2t_2 = [0] + motionR2_2[:-1]
                            motionR2t_3 = [0] + motionR2_3[:-1]
                            motionR2t_4 = [0] + motionR2_4[:-1]
                            motionR2t_5 = [0] + motionR2_5[:-1]
                            motionR2t_6 = [0] + motionR2_6[:-1]
                                            
                                                            
                            #read in global signal, creating the list globalsig and expanded versions
                            #also create a list of timepoints, ie 0, 1, 2, 3, 4, 5, etc
                            with open(globalsigfile, 'r') as file:
                                for line in file:
                                    currentSig = float(line[:-1])
                                    globalsig.append(currentSig)
                                    globalsig2.append(currentSig**2)
                                    globalsigt.append(currentSig)
                                    globalsig2t.append(currentSig**2)
            
                            del globalsigt[-1]
                            del globalsig2t[-1]
            
                            #read in WM signal, creating the list wmsig and expanded versions
                            with open(wmfile, 'r') as file:
                                for line in file:
                                    currentSig = float(line[:-1])
                                    wmsig.append(currentSig)
                                    wmsig2.append(currentSig**2)
                                    wmsigt.append(currentSig)
                                    wmsig2t.append(currentSig**2)
            
                            del wmsigt[-1]
                            del wmsig2t[-1]
            
                            #read in CSF signal, creating the list csfsig and expanded versions
                            with open(csffile, 'r') as file:
                                for line in file:
                                    currentSig = float(line[:-1])
                                    csfsig.append(currentSig)
                                    csfsig2.append(currentSig**2)
                                    csfsigt.append(currentSig)
                                    csfsig2t.append(currentSig**2)
            
                            del csfsigt[-1]
                            del csfsig2t[-1]
                                
                            
                            #create a dataframe of the time series, global signal, motion parameters, and the time course
                            #presumably this will have to be changed when I start looking at different preprocessing steps
                            allregressorsDF = pd.DataFrame(
                                {'Global_Signal': globalsig - np.mean(globalsig),
                                 'Global_Signal2' : globalsig2 - np.mean(globalsig2),
                                 'Global_Signalt' : globalsigt - np.mean(globalsigt),
                                 'Global_Signal2t' : globalsig2t - np.mean(globalsig2t),
                                 'WM_Signal' : wmsig - np.mean(wmsig),
                                 'WM_Signal2' : wmsig2 - np.mean(wmsig2),
                                 'WM_Signalt' : wmsigt - np.mean(wmsigt),
                                 'WM_Signal2t' : wmsig2t - np.mean(wmsig2t),
                                 'CSF_Signal' : csfsig - np.mean(csfsig),
                                 'CSF_Signal2' : csfsig2 - np.mean(csfsig2),
                                 'CSF_Signalt' : csfsigt - np.mean(csfsigt),
                                 'CSF_Signal2t' : csfsig2t - np.mean(csfsig2t),
                                 'MotionR_1' : motionR_1 - np.mean(motionR_1),
                                 'MotionR_2' : motionR_2 - np.mean(motionR_2),
                                 'MotionR_3' : motionR_3 - np.mean(motionR_3),
                                 'MotionR_4' : motionR_4 - np.mean(motionR_4),
                                 'MotionR_5' : motionR_5 - np.mean(motionR_5),
                                 'MotionR_6' : motionR_6 - np.mean(motionR_6),
                                 'MotionR2_1' : motionR2_1 - np.mean(motionR2_1),
                                 'MotionR2_2' : motionR2_2 - np.mean(motionR2_2),
                                 'MotionR2_3' : motionR2_3 - np.mean(motionR2_3),
                                 'MotionR2_4' : motionR2_4 - np.mean(motionR2_4),
                                 'MotionR2_5' : motionR2_5 - np.mean(motionR2_5),
                                 'MotionR2_6' : motionR2_6 - np.mean(motionR2_6),
                                 'MotionRt_1' : motionRt_1 - np.mean(motionRt_1),
                                 'MotionRt_2' : motionRt_2 - np.mean(motionRt_2),
                                 'MotionRt_3' : motionRt_3 - np.mean(motionRt_3),
                                 'MotionRt_4' : motionRt_4 - np.mean(motionRt_4),
                                 'MotionRt_5' : motionRt_5 - np.mean(motionRt_5),
                                 'MotionRt_6' : motionRt_6 - np.mean(motionRt_6),
                                 'MotionR2t_1' : motionR2t_1 - np.mean(motionR2t_1),
                                 'MotionR2t_2' : motionR2t_2 - np.mean(motionR2t_2),
                                 'MotionR2t_3' : motionR2t_3 - np.mean(motionR2t_3),
                                 'MotionR2t_4' : motionR2t_4 - np.mean(motionR2t_4),
                                 'MotionR2t_5' : motionR2t_5 - np.mean(motionR2t_5),
                                 'MotionR2t_6' : motionR2t_6 - np.mean(motionR2t_6)
                                })
                            
                            #add a constant to dataframe
                            allregressorsDF = sm.add_constant(allregressorsDF)
                            
                            #add motion censoring to dataframe
                            allregressorsDF = allregressorsDF.join(censordf)
                            
                            #save regressors as a CSV file
                            allregressorsDF.to_csv(regoutput)
                            x = "All regressors saved to " + regoutput
                            print(x)
                            log.append(x)
                            
                            #find the final time, save info to log
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)    
                                 
    if (k == 'runreg') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks: 
                    #define file names for this specific kid
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + regimagename
                    input_mask = dir_in + person + '_' + j + '_' + task + '_' + regmaskname
                    input_reg = dir_in + regfolder + person + '_' + j + '_' + task + '_' + reginput
                    output_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + regimagenameoutput
    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x)
                    elif os.path.isfile(input_reg) == True:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Regression did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
    
                            #find the current time
                            steptimer = time.time()
                            
                            regdata = pd.read_csv(input_reg, index_col=0)
                            
                            #load the image using some package I found called NiBabel
                            img = nib.load(input_file)
                            image_data = img.get_fdata()
                            new_data = image_data.copy()
                                  
                            #load the mask
                            img = nib.load(input_mask)
                            mask_data = img.get_fdata()
                            
                            #get shape of image data
                            shape = image_data.shape
                            dim_x = shape[0]
                            dim_y = shape[1]
                            dim_z = shape[2]
                                
                            x = "Running the regression for " + person + " " + j + " " + task
                            print(x)
                            log.append(x)
                            
                            #loop over every possible voxel in 3D space
                            for dimi in range(dim_x):
                                print("Running for x dimension slice " + str(dimi + 1) + " of " + str(dim_x) + " for " + person + " " + j + " " + task)
                                for dimj in range(dim_y):
                                    for dimk in range(dim_z):
                                        #only create model if voxel is in brain mask
                                        if mask_data[dimi][dimj][dimk] == 1:
                                            #load the current series, put in data fram
                                            currentseries = image_data[dimi][dimj][dimk]
                                            timeseriesDF = pd.DataFrame(
                                                {'Time_Series': currentseries
                                                })  
                                            y = timeseriesDF["Time_Series"]                                        
                                            
                                            #create the model. Predict y (the time series) as a function of X (all the nuisance regressors)
                                            model = sm.OLS(y, regdata).fit()
                                            residuals = model.resid.tolist()
                                            new_data[dimi][dimj][dimk] = residuals
                                            
                                            #for testing, this makes every voxel equal to the volume:
                                            #new_data[dimi][dimj][dimk] = [qq for qq in range(len(new_data[dimi][dimj][dimk]))]
                                        else:
                                            new_data[dimi][dimj][dimk] = [0]*len(new_data[dimi][dimj][dimk])
                            
                            #save image
                            regressor_img = nib.Nifti1Image(new_data, img.affine, img.header)
                            nib.save(regressor_img,output_file)
                            
                            x = "Regression probably created: " + output_file
                            print(x)
                            log.append(x)
            
                            #find the final time, save info to log
                            steptimer = round(time.time()-steptimer,3)
                            x = "Individual step took " + str(steptimer) + " s to run."
                            print(x)
                            log.append(x)
                            
                            steptimermin = round(steptimer/60,3)
                            x = "(which is " + str(steptimermin) + " minutes)"
                            print(x)
                            log.append(x)   
                            
                    else:
                        x = "This file doesn't exist: " + input_reg
                        print(x)
                        log.append(x)                    

    if (k == 'remean') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks: 
                    #define file names for this specific kid
                    dir_in = dir_start + person + '/' + j + '/func/prckids-task/'
                    input_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + remeanimagename
                    input_mean = dir_in + regfolder + person + '_' + j + '_' + task + '_' + remeanmean
                    output_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + remeanoutput
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "Remean did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False # Kate changed from doit = True
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
                            
                            x = "Remean will now try to run on:" + person + " " + j + " " + task
                            print(x)
                            log.append(x) 
                            try:
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = input_file
                                mymath.inputs.out_file = output_file
                                mymath.inputs.args = "-add " + input_mean
                                mymath.run()
                                x = "Remean probably created " + output_file
                                print(x)
                                log.append(x)
                            except:
                                x = "Remean failed."
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
 
    if (k == 'newmean') & (endit == False):
               
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks:
                    #set directory as folder where files are stored
                    dir_in = dir_start + person + '/' + j + '/func/'
            
                    input_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + newmeaninput
                    output_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + newmeanoutput
                    
                    maskfile = dir_in + person + '_' + j + '_' + task + '_' + newmean_maskinput
                    maskmeanfile = dir_in + regfolder + person + '_' + j + '_' + task + '_' + newmean_maskoutput
                    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "New mean did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False # Kate changed from doit = True
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
                            
                            x = "New mean will now try to run on:" + input_file
                            print(x)
                            log.append(x)  
                            x = "New mean set to: " + newmean
                            print(x)
                            log.append(x)
                            
                            try:
                                x = "Creating new mean mask"
                                print(x)
                                
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = maskfile
                                mymath.inputs.out_file = maskmeanfile
                                mymath.inputs.args = "-mul " + newmean
                                mymath.run() 
                                
                                x = "Adding new mean to the time series"
                                print(x)
                                
                                mymath = fsl.ImageMaths()
                                mymath.inputs.in_file = input_file
                                mymath.inputs.out_file = output_file
                                mymath.inputs.args = "-add " + maskmeanfile
                                mymath.run()
                                
                                    
                                x = "New mean probably created " + output_file
                                print(x)
                                log.append(x)
                                
                            except:
                                x = "New mean failed."
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
 
    if (k == 'smooth') & (endit == False):
        for i in participants:
            #person = participant_folders[i]
            person = i
            for j in imagesession:
                for task in tasks: 
                    #define file names for this specific participant
                    dir_in = dir_start + person + '/' + j + '/func/'
                    input_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + smoothinput + '.nii.gz'
                    output_file = dir_in + regfolder + person + '_' + j + '_' + task + '_' + smoothoutput + '.nii.gz'
                    
                    if os.path.isfile(input_file) == False:
                        x = "This file doesn't exist: " + input_file
                        print(x)
                        log.append(x) 
                    else:
                        doit = True
                        if replacer == False:
                            if os.path.isfile(output_file) == True:
                                x = "smooth did not run; file already exists for " + output_file
                                print(x)
                                log.append(x)
                                doit = False
                        if doit == True:
                            steptimer = time.time()
                            os.chdir(dir_in)
                            
                            x = "smoothing will now try to run with 6mm kernel."
                            print(x)
                            log.append(x)                        
                            try:
                                sm = fsl.Smooth()
                                sm.inputs.in_file = input_file
                                sm.inputs.fwhm = 3.0
                                sm.run()
    
                                x = "smoothing probably created " + output_file
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


#Wrap up the program

#subtract the new current time from the old current time. Also convert to minutes. Add to log

totaltimer = round(time.time()-totaltimer,3)
totaltimermin = round(totaltimer/60,3)
totaltimerhour = round(totaltimermin/60,3)
x = "All steps took " + str(totaltimer) + " s to run."
print(x)
log.append(x)
summarylog.append(x)
x = "(which is " + str(totaltimermin) + " minutes)"
print(x)
log.append(x)
summarylog.append(x)
x = "(which is " + str(totaltimerhour) + " hours)"
print(x)
log.append(x)
summarylog.append(x)

x = 'The end date/time is ' + time.ctime()
print(x)
log.append(x)
summarylog.append(x)

os.chdir(dir_start)
#add a couple blank lines to the log list, to make it look nicer
log.append('')
log.append('')
summarylog.append('')
summarylog.append('')


if savelog == True: 
    #open the log file, add the log list to the file
    #'a' means append. You could also write a new file every time, if you wanted
    with open(logname, 'a') as f:
        for item in log:
            f.write("%s\n" % item)
    f.close()

if savesummarylog == True: 
    #open the log file, add the log list to the file
    #'a' means append. You could also write a new file every time, if you wanted
    with open(summarylogname, 'a') as f:
        for item in summarylog:
            f.write("%s\n" % item)
    f.close()                       
