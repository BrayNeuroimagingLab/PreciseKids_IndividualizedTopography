function createSpatialCorrMap(groupDconnLoc,subDconnLoc,outputdir, subID, task)
%createSpatialCorrMap(dconnLoc,subDataLoc,[outputdir])
%
% This function creates a spatial correlation map by comparing cortical
% BOLD data from a single individual to a group-average. The assumed file
% format is CIFTI, in order to work with Connectome Workbench (see 
% https://www.nitrc.org/projects/cifti/ for more details). This code 
% requires the GIFTI and CIFTI_Resources packages to be added to the user's
% path (which released in addition to this one).
%
% INPUTS
% dconnLoc: a path to the group-average correlation matrix (dconn is CIFTI
% for correlation matrix) and the file name
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
% "Where there's a will there's a kluge."
% -BAS 10/11/2019

%%%%%Shefali edits and notes: initial error "Invalid MEX-file.../xml_findstr.mexmaci64':" was resolved by:%%%%%
%First finding the missing file in terminal for mac: 
%     bash-3.2$ otool -L xml_findstr.mexmaci64
%Then using terminal in mac to build file using mex command: 
%     bash-3.2$ cd /Users/shefalirai/Documents/MATLAB/PRCKIDS_1973_Scripts/Utilities/read_write_cifti/gifti/@xmltree/private
%     bash-3.2$ /Applications/MATLAB_R2021b.app/bin/mex -compatibleArrayDims xml_findstr.c
%                      Building with 'Xcode with Clang'.
%                      MEX completed successfully.
%Then test the file path again:
%      bash-3.2$ otool -L xml_findstr.mexmaci64
%                      xml_findstr.mexmaci64:
%	                      @rpath/libmx.dylib (compatibility version 0.0.0, current version 0.0.0)
%	                      @rpath/libmex.dylib (compatibility version 0.0.0, current version 0.0.0)
%	                      /usr/lib/libc++.1.dylib (compatibility version 1.0.0, current version 1500.65.0)
%	                      /usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1319.100.3)
%Finally, the MEX-file error is resolved.


%%%%% CHANGE THIS PATH TO THE LOCATION WHERE YOU STORED THE TEMPLATE %%%%%
%%%%% NOTE: This template will only work with the 32k-fsLR surfaces. %%%%%
addpath(genpath('/Users/shefalirai/Documents/MATLAB/PRCKIDS_1973_Scripts/Utilities/'));

templateLoc = '/Users/shefalirai/Desktop';
% templateLoc = pwd;
template = ft_read_cifti_mod([templateLoc '/templateSpatialCorrMap.dtseries.nii']);
template.data = [];

%%%%% CHANGE THIS PATH TO THE LOCATION WHERE YOU STORED THE TEMPLATE %%%%%


% Set variables
if ~exist('outputdir')
    outputdir = pwd;
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
ft_write_cifti_mod(sprintf([outputdir '/%s_%s_spatialCorrMap.dtseries.nii'], subID, task), template);

end

%after this script run averaged_spatialvariants.m
