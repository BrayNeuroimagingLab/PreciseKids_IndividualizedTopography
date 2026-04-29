function ARC_Templatematching_PKdata_Vertexwise(subject, task)
%subject is their full subject ID, e.g., 'sub-1973018C'
%task input e.g., 'task-RX'

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
wbcommand='~/workbench/bin_rh_linux64/wb_command';

%------------------------------------------------------------------------

%Create dconn
file_path = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored.dtseries.nii', subject, task);
connFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored.dconn.nii', subject, task);
eval(['! ~/workbench/bin_rh_linux64/wb_command -cifti-correlation ' file_path ' ' connFile]);
sub_data_dconn = ciftiopen(connFile, wbcommand);
sub_data_dconn = sub_data_dconn.cdata;


%Fisher Z pconn map
% Ensure the matrix is symmetric and has diagonal elements equal to 1
sub_data_dconn = triu(sub_data_dconn, 1) + triu(sub_data_dconn, 1).' + eye(91282);

% Apply Fisher transform
sub_data_fisher = atanh(sub_data_dconn);

%Threshold and binarize
threshold = 0.383;

% Thresholding
sub_data_fisher(sub_data_fisher < threshold) = 0;

% Binarization
binarizedMap = sub_data_fisher;
binarizedMap(binarizedMap >= threshold) = 1;

binarized_sub_data= binarizedMap';

%Visualize on surface and check binarized connectivity map for all vertices
sub_data=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored.dtseries.nii', subject, task), wbcommand);
sub_data.cdata=binarized_sub_data;
ciftisavereset(sub_data, sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored_binarizedmap.dtseries.nii', subject, task),  wbcommand);

%set diagonals to NaN
binarized_sub_data(1:size(binarized_sub_data, 1) + 1:end) = NaN;

 
%% Similarity from sub_data to MSC templates
% based on Code from DCAN Labs obtained from: https://github.com/DCAN-Labs/compare_matrices_to_assign_networks/tree/main

%Open MSC avg templates
for networks=1:16
    msc{networks}=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/AvgMSC_binarizedtemplatemaps_network%d_vertexwise.dscalar.nii', networks), wbcommand);
    binarizedNetworkMaps{1,networks}=msc{networks}.cdata;
end

%Similarity between subject vertices and MSC avg templates
numVertices = size(binarized_sub_data, 1);
numTemplates = numel(binarizedNetworkMaps);

% Initialize matrix to store similarity values
etaToTemplateVertex = zeros(numVertices, numTemplates);

% Loop through each vertex
for vertex = 1:numVertices
    % Extract connectivity profile for the current vertex
    vertexConnectivityProfile = binarized_sub_data(vertex, :);

    % Loop through each template map
    for template = 1:numTemplates
        % Extract template map for the current network
        templateMap = binarizedNetworkMaps{template}';

        % Find non-NaN indices in both subject map and template map
        validIndices = ~isnan(vertexConnectivityProfile) & ~isnan(templateMap);

        % Check if there are any valid indices
        if any(validIndices)
            % Compute similarity only for non-NaN values
            Mgrand  = (mean(mean(templateMap(validIndices))) + mean(mean(vertexConnectivityProfile(validIndices))))/2;
            Mwithin = (templateMap(validIndices)+vertexConnectivityProfile(validIndices))/2;
            SSwithin = sum(sum((templateMap(validIndices)-Mwithin).*(templateMap(validIndices)-Mwithin))) + sum(sum((vertexConnectivityProfile(validIndices)-Mwithin).*(vertexConnectivityProfile(validIndices)-Mwithin)));
            SStot    = sum(sum((templateMap(validIndices)-Mgrand ).*(templateMap(validIndices)-Mgrand ))) + sum(sum((vertexConnectivityProfile(validIndices)-Mgrand ).*(vertexConnectivityProfile(validIndices)-Mgrand )));
            etaToTemplateVertex(vertex, template) = 1 - SSwithin/SStot;
        else
            % Handle case where there are no valid indices (both subject and template are NaN)
            etaToTemplateVertex(vertex, template) = NaN;
        end
    end
end

% Find the template with the highest similarity for each vertex
[~, assignedNetwork] = max(etaToTemplateVertex, [], 2);

%Visualize network assignment on surface across all vertices
sub_data=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored_binarizedmap.dtseries.nii', subject, task), wbcommand);
sub_data.cdata=assignedNetwork;
ciftisavereset(sub_data, sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_MSCavgtemplatematching_14networkassignment_Vertexwise.dscalar.nii', subject, task),  wbcommand);



end

