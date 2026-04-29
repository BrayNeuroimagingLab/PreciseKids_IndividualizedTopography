#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
FD estimates using echo 2 since the OC file will be denoised using tedana
Looks at Motion Parameters
Created on Fri Jun  7 10:47:42 2019

@author: Kirk

Update Log V2 (Kate):
script will now loop through all tasks, without manually running the script once per task
fdmcflirt now specified to be 1/2 of fdpower
changed general program options to ask user for the tr
updated script so bad volumes are saved to a single .csv file (badvolscsv_all variable), 
    rather than each subject having their own .csvfile
    
Update Log V3 (Kate)
script now running by using power fd estimates prior to slicetime correction *_boldMcf rather than following slicetime correction (*_boldStcMcf), based on:
    Power, J. D., Plitt, M., Kundu, P., Bandettini, P. A., & Martin, A. (2017). Temporal interpolation alters motion in fMRI scans: Magnitudes and consequences 
    for artifact detection. PloS One, 12(9), e0182939–e0182939. https://doi.org/10.1371/journal.pone.0182939
"""


"""***********************"""
"""GENERAL PROGRAM OPTIONS"""
"""***********************"""
#what directory are your images saved in?
dir_start = '/Users/shefalirai/Downloads/bids-files/'

#what participants do you want this to run on? e.g. [1,2,3] or list(range(1,4))
#this is based on the files in the directory. 0 = first file in directory
#participants = [13,14,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,
#             31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,53,54,55,56,57,59,60,61,62]
participants =['sub-parker'] #026C 
#participants =[15] #003C no YT2
#participants =[58] #024P ses-6 not ses-4


#do you want to run on ses-1, ses-2, ses-3, ses-4 or all? If all, type ['ses-1', 'ses-2', 'ses-3', 'ses-4']
imagesession = ['ses-2']

#what tasks do you want to run on? e.g. ['task-DORA1', 'task-DORA2']
tasks = ['rsfMRI_run-1', 'rsfMRI_run-2']

#text file with 6 head alignment estimates
filterhmpinput = 'boldMcf.nii.gz.par'

#mcflirt FD values. For comparison
fdfileinput = 'boldMcf.nii.gz_rel.rms'

#Power FD output with filtering
fdfileoutput = 'PowerFDFlt0.15_v2.csv'

#Bad volumes for all participants output file 
#Rename if you want to save and compare different thresholds
badvolcsv_all = dir_start + 'PowerFDFlt0.15_v2.csv'

#what is your TR in seconds? used for fourier transform to calculate powerfdflt
tr = 0.8 ##vanilla is 2 #tr = 0.8 for rsfmri

#filtering threshold. Anything within this range is what you want to keep
highcut = 0.08
lowcut = 0.01

#Kate used power 0.2 for adults-only analysis
#threshold for fdmcflirt. 0.2 or 0.25 are good choices for kids, 0.1 or 0.15 is good for adults
fd1thres = 0.1
#threshold for fdpower. double fdmcflirt is good. 
fd2thres = 0.15

#Kate used power 0.3 for 2group analysis
#threshold for fdmcflirt. 0.2 or 0.25 are good choices for kids, 0.1 or 0.15 is good for adults
#fd1thres = 0.15
#threshold for fdpower. double fdmcflirt is good. 
#fd2thres = 0.3

#if replacer is false, the program won't run if output image already exists
#if replacer is true, the program will write over outputs that already exist
replacer = True

"""*****************************************"""
"""ANYTHING BELOW HERE DOESN'T NEED CHANGING"""
"""**********(OR SO KIRK HOPES)*************"""
"""*****************************************"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import time
from scipy.stats import linregress
from scipy.fftpack import fft, ifft

os.chdir(dir_start)
participant_folders = sorted(os.listdir(dir_start))

#check if your summary bad volumes document exists, if not it creates it
if os.path.isfile(badvolcsv_all) == False:
    example_voldata = [('test','test','test','test','test','test','test')]
    df = pd.DataFrame(data = example_voldata, columns=['person','ses', 'task','BadvolMCFLIRT','BadvolPower','BadvolPowerFltY','Power&PowerFltDiff'])
    
    os.chdir(dir_start)
    #save the data frame as a csv file
    df.to_csv(badvolcsv_all,index=False,header=True)


for i in participants:
    #person = participant_folders[i] 
    person = i
    badvolsFD_flirt = []
    badvolsFD_power = []
    badvolsFD_poweryflt = [] 
    subj = []
    seslist = []
    tasklist = []
    #for t in tasks:
    for j in imagesession:
        for t in tasks:
            subj.append(person)
            seslist.append(j)
            tasklist.append(t) 
            #define file names for this specific kid
            dir_in = dir_start + person + "/" + j + "/func/"
            headmotionfile = dir_in + person + "_" + j + "_" + t + "_" + filterhmpinput            
            fdfile = dir_in + person + "_" + j + "_" + t + "_" + fdfileinput 
            fdsavefile = dir_in + person + "_" + j + "_" + t + "_" + fdfileoutput 
            
            doit = True
            
            """
            if os.path.isfile(fdsavefile) == True:
                if replacer == False:
                    x = "PowerFD did not run, file already exists: " + fdsavefile
                    print(x)
                    doit= False
            """
                    
            if doit == True: 
                rawmotion = ['rot_x','rot_y','rot_z','trans_x','trans_y','trans_z']
                        
                md = {
                        'rot_x' : [],
                        'rot_y' : [],
                        'rot_z' : [],
                        'trans_x' : [],
                        'trans_y' : [],
                        'trans_z' : []   
                }
        
                mdc =  {
                        'rot_x' : [],
                        'rot_y' : [],
                        'rot_z' : [],
                        'trans_x' : [],
                        'trans_y' : [],
                        'trans_z' : [],
                        'trans_yflt' : []
                }
                
                currentline = 0
                with open(headmotionfile) as file:
                    for line in file:
                        #if currentline < 434:
                        splitted = line.split()
                        #create head motion parameters
                        md['rot_x'].append(float(splitted[0]))
                        md['rot_y'].append(float(splitted[1]))
                        md['rot_z'].append(float(splitted[2]))
                        md['trans_x'].append(float(splitted[3]))
                        md['trans_y'].append(float(splitted[4]))
                        md['trans_z'].append(float(splitted[5]))
                        currentline = currentline + 1
                            
                N = len(md['rot_x'])
                
                #assign fs (the sampling frequency) to be 1/tr
                fs = 1/tr
                
                tf = np.linspace(0.0,fs/2,int(N/2))
                alltime = list(range(0,N))        
           
               
        
        
                os.chdir(dir_in)
        
        
        
                
                                                                                            
                ###filter the data###
                   
                #define the lowpass and highpass                                                                   
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
                
                for rr in rawmotion:
                    testseries = md[rr]                                                 
                    #this creates amplitude vs time data after a FFT filter. So FFT then an inverse FFT
                    repaireddata = np.real(ifft(fft(testseries)*F))
                    
                    #add the repaired data to the motion dictionary
                    md[rr+'flt'] = repaireddata          
                   
                
                timelist = list(range(0,N))
                timelist2 = list(range(0,N))
                alltime = list(range(0,N))
                
                #calculate change in HMP from timepoint to timepoint. Convert angles (in radians) to mm by assuming 50 mm head radius
                for i in timelist:
                    mdc['rot_x'].append(abs((md['rot_x'][i]-md['rot_x'][i-1])*50))
                    mdc['rot_y'].append(abs((md['rot_y'][i]-md['rot_y'][i-1])*50))
                    mdc['rot_z'].append(abs((md['rot_z'][i]-md['rot_z'][i-1])*50))
                    mdc['trans_x'].append(abs(md['trans_x'][i]-md['trans_x'][i-1]))
                    mdc['trans_y'].append(abs(md['trans_y'][i]-md['trans_y'][i-1]))
                    mdc['trans_z'].append(abs(md['trans_z'][i]-md['trans_z'][i-1]))
                    mdc['trans_yflt'].append(abs(md['trans_yflt'][i]-md['trans_yflt'][i-1]))            
                
                #calculate FD both with and without filtered y
                FD = []
                FD2 = []       
                for i in timelist2:
                    FD.append(mdc['rot_x'][i]+mdc['rot_y'][i]+mdc['rot_z'][i]+mdc['trans_x'][i]+mdc['trans_y'][i]+mdc['trans_z'][i])
                    FD2.append(mdc['rot_x'][i]+mdc['rot_y'][i]+mdc['rot_z'][i]+mdc['trans_x'][i]+mdc['trans_yflt'][i]+mdc['trans_z'][i])
                
                FDnewdf = pd.DataFrame({'FD':FD2})
                
                
                FDnewdf.to_csv(fdsavefile)
                
        
                #import FLIRT FD calculation
                fdflirt = []
                with open(fdfile) as file:
                    for line in file:
                        fdflirt.append(float(line))
                
                #count the number of bad volumes for each way of calculating FD
                badvolsFDflirt = 0
                badvolsFD = 0
                badvolsFD2 = 0
                #badvolsFD3 = 0
                
                for i in range(len(fdflirt)):
                    if fdflirt[i] > fd1thres:
                        badvolsFDflirt = badvolsFDflirt + 1
                for i in range(len(FD)):
                    if FD[i] > fd2thres:
                        badvolsFD = badvolsFD + 1
                for i in range(len(FD2)):
                    if FD2[i] > fd2thres:
                        badvolsFD2 = badvolsFD2 + 1                
                        
                badvolsFD_flirt.append(badvolsFDflirt)
                badvolsFD_power.append(badvolsFD)
                badvolsFD_poweryflt.append(badvolsFD2)
                
                
  
              
    if doit == True:  
        #save participant summary to dataframe
        badvoldf = pd.DataFrame({'person':subj,'ses':seslist, 'task':tasklist,'BadvolMCFLIRT':badvolsFD_flirt,'BadvolPower':badvolsFD_power,'BadvolPowerFltY':badvolsFD_poweryflt})    
        badvoldf['Power&PowerFltDiff'] = badvoldf['BadvolPower']-badvoldf['BadvolPowerFltY']
                                       
        print(badvoldf.to_string())
        
        #save to master file
        #'a' means to append
        badvoldf.to_csv(badvolcsv_all,mode='a',index=False,header=False)


