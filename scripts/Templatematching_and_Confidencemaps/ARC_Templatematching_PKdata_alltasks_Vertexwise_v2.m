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

%Open dconn
connFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored.dconn.nii', subject, task);
sub_data_dconn = ciftiopen(connFile, wbcommand);
sub_data_dconn = sub_data_dconn.cdata;

%Fisher Z pconn map
sub_data_dconn = triu(sub_data_dconn, 1) + triu(sub_data_dconn, 1).' + eye(91282);
sub_data_fisher = atanh(sub_data_dconn);

%Threshold and binarize
threshold = 0.383;
sub_data_fisher(sub_data_fisher < threshold) = 0;
binarizedMap = double(sub_data_fisher >= threshold);
binarized_sub_data = binarizedMap';

% Set binarized map diagonals to NaN
binarized_sub_data(1:size(binarized_sub_data, 1) + 1:end) = NaN;
 
%% Similarity from sub_data to MSC templates
% based on Code from DCAN Labs obtained from: https://github.com/DCAN-Labs/compare_matrices_to_assign_networks/tree/main

%Open MSC avg templates
for networks=1:17
    msc{networks}=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/AvgMSC_binarizedtemplatemaps_network%d_vertexwise.dscalar.nii', networks), wbcommand);
    binarizedNetworkMaps{1,networks}=msc{networks}.cdata;
end

% Compute similarity and assign networks
numVertices = size(binarized_sub_data, 1);
numTemplates = numel(binarizedNetworkMaps);
assignedNetwork = zeros(numVertices, 1);

for vertex = 1:numVertices
    vertexConnectivityProfile = binarized_sub_data(vertex, :);
    etaToTemplateVertex = zeros(1, numTemplates);
    
    for template = 1:numTemplates
        templateMap = binarizedNetworkMaps{template}';
        validIndices = ~isnan(vertexConnectivityProfile) & ~isnan(templateMap);
        
        if any(validIndices)
            Mgrand = (mean(templateMap(validIndices)) + mean(vertexConnectivityProfile(validIndices)))/2;
            Mwithin = (templateMap(validIndices) + vertexConnectivityProfile(validIndices))/2;
            SSwithin = sum((templateMap(validIndices) - Mwithin).^2) + sum((vertexConnectivityProfile(validIndices) - Mwithin).^2);
            SStot = sum((templateMap(validIndices) - Mgrand).^2) + sum((vertexConnectivityProfile(validIndices) - Mgrand).^2);
            etaToTemplateVertex(template) = 1 - SSwithin/SStot;
        else
            etaToTemplateVertex(template) = NaN;
        end
    end
    
    [~, assignedNetwork(vertex)] = max(etaToTemplateVertex);
end

% Save the network assignment directly
sub_data=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored.dtseries.nii', subject, task), wbcommand);
sub_data.cdata=assignedNetwork;
outputFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_MSCavgtemplatematching_14networkassignment_Vertexwise.dscalar.nii', subject, task);
ciftisavereset(sub_data, outputFile, wbcommand);


fprintf('Successfully processed subject %s for task %s\n', subject, task);


end

