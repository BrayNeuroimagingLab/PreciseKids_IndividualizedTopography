function arc_SpatialCorrC(groupDconnLoc,subDconnLoc, subID, task)
%function to craete spatial correlation map for each subject

% This function creates a spatial correlation map by comparing cortical
% BOLD data from a single individual to a group-average. The assumed file
% format is CIFTI, in order to work with Connectome Workbench (see
% https://www.nitrc.org/projects/cifti/ for more details). This code
% requires the GIFTI and CIFTI_Resources packages to be added to the user's
% path (which released in addition to this one).
%
% INPUTS
% dconnLoc: a path to the group-average correlation matrix (dconn is CIFTI
% for correlation matrix) and the file name, for this script we are using MSCAveraged dtseries
% from Midnight Scan Club 9 subjects average BOLD signal
%
% subDataLoc: a path to the single individual's correlation matrix (in the
% CIFTI format) and the file name
%
% OPTIONAL INPUT
% outputdir: the directory to which the output file will be written
%
% OUTPUT
% a single CIFTI file that contains the spatial correlation map
%
%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
wbcommand='~/workbench/bin_rh_linux64/wb_command';
addpath(genpath('~/Programs/matlab/'))
addpath(genpath('~/Programs/matlab/cifti-matlab-master/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
addpath(genpath('~/Programs/matlab/Utilities/'))
%------------------------------------------------------------------------

templateLoc = '/bulk/bray_bulk/Shefali_PreciseKIDS/spatialcorr';
template = ft_read_cifti_mod([templateLoc '/templateSpatialCorrMap.dtseries.nii']);
template.data = [];

% Set variables
if ~exist('outputdir')
    outputdir = templateLoc;
end

% Read in group-average matrix
tempCifti = ft_read_cifti_mod(groupDconnLoc, 'readdata', true);
cortexInds = 1:sum(tempCifti.brainstructure==1 | tempCifti.brainstructure==2);
groupMat = single(FisherTransform(tempCifti.data(cortexInds,cortexInds)));
clear tempCifti
    

% Read in single subject matrix
tempCifti = ft_read_cifti_mod(subDconnLoc, 'readdata', true );
cortexInds = 1:sum(tempCifti.brainstructure==1 | tempCifti.brainstructure==2);
subMat = single(FisherTransform(tempCifti.data(cortexInds,cortexInds)));
clear tempCifti

%Shefali edit: added this to replace vertices containing NaN values with zero values instead.
subMat(isnan(subMat))=0;

% Compare single subject to group-average at each cortical location
for i=1:length(cortexInds)
    template.data(i,1) = paircorr_mod(groupMat(:,i),subMat(:,i));
end
clear groupMat subMat


% Write out the spatial correlation map
ft_write_cifti_mod(sprintf([outputdir '/%s_%s_sample1_spatialCorrMap.dtseries.nii'], subID, task), template);

end

