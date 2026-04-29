
%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
% addpath(genpath('~/Programs/matlab/gifti-1.6'))
% addpath(genpath('~/Programs/matlab/BCT'))
% addpath(genpath('~/Programs/matlab/cifti_matlab-master'))
wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
%------------------------------------------------------------------------

%open all sessions combined dtseries file
MSCavg_dtseries_cifti=ciftiopen('/Users/shefalirai/Desktop/MSCAveraged_Timeseries.dtseries.nii', wbcommand);
MSCavg_dtseries_data=MSCavg_dtseries_cifti.cdata;

%average across each row (vertex)
MSCavg_dtseries_mean=mean(MSCavg_dtseries_data, 2);
[row,col]=find(MSCavg_dtseries_mean<=500);
%mask of which vertices contain averaged signal less than or equal to 750
mask=MSCavg_dtseries_mean <= 500;

%save mask
MSCavg_dtseries_cifti.cdata=mask;
ciftisavereset(MSCavg_dtseries_cifti, '/Users/shefalirai/Desktop/MSCavg_SNRmask.dtseries.nii' , wbcommand);


