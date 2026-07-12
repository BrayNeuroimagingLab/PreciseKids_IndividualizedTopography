function arc_create_dconn_splitHalf(allsessions_file, subID, task, duration, sample)
% Create dconn for split-half reliability analysis.
% duration : '15min' or '30min'
% sample   : '1' or '2'

addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities'))
workbenchdir = '~/workbench/bin_rh_linux64';
addpath(genpath('~/Programs/matlab/gifti-1.6'))

inputcifti  = allsessions_file;
outputcifti = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_%s_sample%s.dconn.nii', ...
                      subID, task, duration, sample);

disp(['Input:  ' inputcifti]);
disp(['Output: ' outputcifti]);

system([workbenchdir '/wb_command -cifti-correlation ' inputcifti ' ' outputcifti]);

end
