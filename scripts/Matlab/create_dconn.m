function create_dconn(allsessions_file, subID, task)
% Create correlated connectomes for each task before running createSpatialCorrMap.m

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
workbenchdir='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS';
outputcifti=sprintf('/Users/shefalirai/Desktop/%s_%s_allsessions_corr.dconn.nii',subID, task);
%------------------------------------------------------------------------

% run cifti-correlation wbcommand function
inputcifti=allsessions_file;
system([workbenchdir '/wb_command -cifti-correlation' ' ' inputcifti ' ' outputcifti ]);

% remove NaN values from dconn file before proceeding
% for example: outputcifti.cdata(isnan(outputcifti.cdata))=0;

end
