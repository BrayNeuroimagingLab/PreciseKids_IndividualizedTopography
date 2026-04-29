function arc_create_dconn_Leftover15min(allsessions_file, subID, task)
% Create correlated connectomes for each task before running createSpatialCorrMap.m

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities'))
workbenchdir='~/workbench/bin_rh_linux64';
addpath(genpath('~/Programs/matlab/gifti-1.6'))
%------------------------------------------------------------------------

% run cifti-correlation wbcommand function
inputcifti=allsessions_file;
outputcifti=sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_leftover15min.dconn.nii',subID, task);

% Add debug information
disp(['Input file: ' allsessions_file]);
disp(['Output file: ' outputcifti]);


system([workbenchdir '/wb_command -cifti-correlation' ' ' inputcifti ' ' outputcifti ]);

end
