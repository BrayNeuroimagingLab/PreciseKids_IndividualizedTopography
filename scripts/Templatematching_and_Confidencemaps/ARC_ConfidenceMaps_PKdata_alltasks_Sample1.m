function ARC_ConfidenceMaps_PKdata_alltasks_Sample1(subject, task)
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
connFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_sample1_censored.dconn.nii', subject, task);
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
for networks=1:16
    msc{networks}=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/AvgMSC_binarizedtemplatemaps_network%d_vertexwise.dscalar.nii', networks), wbcommand);
    binarizedNetworkMaps{1,networks}=msc{networks}.cdata;
end

%Confidence/uncertainty metrics
numVertices = size(binarized_sub_data, 1);
numTemplates = numel(binarizedNetworkMaps);
max_eta_map = zeros(numVertices, 1);
entropy_map = zeros(numVertices, 1);
all_eta_values = zeros(numVertices, numTemplates);
    
%Calculate eta coefficients and assignments
network_assignments = zeros(numVertices, 1);
for vertex = 1:numVertices
        vertexConnectivityProfile = binarized_sub_data(vertex, :);
        etaToTemplateVertex = zeros(1, numTemplates);
        
        % Calculate eta coefficients as with template matching to get numbers
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

        % Store values and get network assignment
        all_eta_values(vertex, :) = etaToTemplateVertex;
        [max_eta, assigned_network] = max(etaToTemplateVertex);
        network_assignments(vertex) = assigned_network;
        max_eta_map(vertex) = max_eta;

        % Normalize eta for entropy calc below
        % Calculate entropy
        valid_eta = etaToTemplateVertex(~isnan(etaToTemplateVertex));
        if ~isempty(valid_eta)
            eta_norm = valid_eta / sum(valid_eta);
            entropy_map(vertex) = -sum(eta_norm .* log2(eta_norm + eps));
        else
            entropy_map(vertex) = NaN;
        end

end


% Save maximum eta map
sub_data=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_sample1_censored.dtseries.nii', subject, task), wbcommand);
max_eta_output = sub_data;
max_eta_output.cdata = max_eta_map;
max_eta_file = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_sample1_templatematching_maxeta.dscalar.nii', subject, task);
ciftisavereset(max_eta_output, max_eta_file, wbcommand);
    
% Save entropy map
entropy_output = sub_data;
entropy_output.cdata = entropy_map;
entropy_file = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_sample1_templatematching_entropy.dscalar.nii', subject, task);
ciftisavereset(entropy_output, entropy_file, wbcommand);


end
