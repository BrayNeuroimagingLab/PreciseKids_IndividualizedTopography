function concatenate_sessions(ses1_filepath, ses2_filepath, ses3_filepath, ses4_filepath, subID, task)
% Concatenate across sessions for each task 

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
% addpath(genpath('~/Programs/matlab/gifti-1.6'))
% addpath(genpath('~/Programs/matlab/BCT'))
% addpath(genpath('~/Programs/matlab/cifti_matlab-master'))
wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
outputcifti=sprintf('/Users/shefalirai/Desktop/%s_%s_allsessions.dtseries.nii',subID, task);
%------------------------------------------------------------------------

ses1_file=ciftiopen(ses1_filepath,wbcommand);
ses1=ses1_file.cdata;
ses2_file=ciftiopen(ses2_filepath,wbcommand);
ses2=ses2_file.cdata;
ses3_file=ciftiopen(ses3_filepath,wbcommand);
ses3=ses3_file.cdata;
ses4_file=ciftiopen(ses4_filepath,wbcommand);
ses4=ses4_file.cdata;
allsessions_file=[ses1 ses2 ses3 ses4];

%if needed, save cifti to folder as specified by path above
ses1_file.cdata=allsessions_file;
ciftisave(ses1_file, outputcifti, wbcommand); 

end
