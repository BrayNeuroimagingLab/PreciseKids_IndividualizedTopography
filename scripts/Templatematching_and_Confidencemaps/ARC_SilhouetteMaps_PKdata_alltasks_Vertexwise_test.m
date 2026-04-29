function ARC_ConfidenceMaps_PKdata_alltasks_Vertexwise_test(subject, task)
%subject is their full subject ID, e.g., 'sub-1973024P'
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
t = tic; % Start timing here
connFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_allsessions_censored.dconn.nii', subject, task);
sub_data_dconn = ciftiopen(connFile, wbcommand);
sub_data_dconn = sub_data_dconn.cdata;
fprintf('Done (%.2f min). Matrix size: %dx%d\n', toc(t)/60, size(sub_data_dconn));


%Fisher Z pconn map
t = tic; % Start timing here
sub_data_dconn = triu(sub_data_dconn, 0); % Upper triangle including diagonal
sub_data_fisher = atanh(sub_data_dconn);
fprintf('Done (%.2f min). Range: [%.3f, %.3f]\n', toc(t)/60, min(sub_data_fisher(:)), max(sub_data_fisher(:)));


%Threshold and binarize
t = tic; % Start timing here
threshold = 0.383;
sub_data_fisher(sub_data_fisher < threshold) = 0;
binarizedMap = double(sub_data_fisher >= threshold);
binarized_sub_data = binarizedMap';
fprintf('Done (%.2f min). Fraction of connections above threshold: %.3f\n', toc(t)/60, sum(binarizedMap(:)==1)/numel(binarizedMap));


% Set binarized map diagonals to NaN
binarized_sub_data(1:size(binarized_sub_data, 1) + 1:end) = NaN;
 
%% Load MSC templates
t = tic; % Start timing here
for networks=1:16
    msc{networks}=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/AvgMSC_binarizedtemplatemaps_network%d_vertexwise.dscalar.nii', networks), wbcommand);
    binarizedNetworkMaps{1,networks}=msc{networks}.cdata;
end
fprintf('All templates loaded (%.2f min)\n', toc(t)/60);

% Remove msc variable for space
clear msc

%Initialize metrics
numVertices = size(binarized_sub_data, 1);
numTemplates = numel(binarizedNetworkMaps);
max_eta_map = zeros(numVertices, 1);
entropy_map = zeros(numVertices, 1);
silhouette_map = zeros(numVertices, 1);
all_eta_values = zeros(numVertices, numTemplates);
network_assignments = zeros(numVertices, 1);

% Calculate eta coefficients and assignments first
t = tic; % Start timing here
for vertex = 1:numVertices
    vertexConnectivityProfile = binarized_sub_data(vertex, :);
    etaToTemplateVertex = zeros(1, numTemplates);
    
    % Calculate eta coefficients
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
    [max_eta, assigned_network] = max(etaToTemplateVertex);
    network_assignments(vertex) = assigned_network;
end
fprintf('Eta coefficients completed (%.2f min)\n', toc(t)/60);

% Get valid networks (exclude networks 4 and 6 that have no vertices)
valid_networks = setdiff(1:16, [4 6]);  % This removes 4 and 6 from the network list

% Only calculate silhouette for vertices belonging to valid networks
valid_mask = ismember(network_assignments, valid_networks);
fprintf('Found %d valid vertices\n', sum(valid_mask));

% Clean correlation matrix - handle NaN values
sub_data_dconn(isnan(sub_data_dconn)) = 0;  % Replace NaN with 0
sub_data_dconn(1:size(sub_data_dconn,1)+1:end) = 1;  % Set diagonal to 1

% Calculate silhouette only for valid vertices
t = tic; % Start timing here
temp_assignments = network_assignments(valid_mask);
temp_correlation = sub_data_dconn(valid_mask, valid_mask);
fprintf('Correlation matrix prepared (%.2f min)\n', toc(t)/60);

% Calculate silhouette for the valid subset
t = tic; % Start timing here
fprintf('Starting silhouette calculation at %s...\n', datestr(now));
fprintf('Matrix size: %dx%d. Starting calculation...\n', size(temp_correlation));
t = tic;
temp_silhouette = silhouette(temp_correlation, temp_assignments, 'correlation');
fprintf('Silhouette completed (%.2f min)\n', toc(t)/60);
fprintf('Matrix size for silhouette: %dx%d\n', size(temp_correlation));

% Save results
fprintf('Saving results... ');
t = tic; % Start timing here
output_file = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_tempsilhouette_values.txt', subject, task);
dlmwrite(output_file, temp_silhouette, 'delimiter', '\t', 'precision', '%.6f');
fprintf('Done (%.2f min)\n', toc(t)/60);
    
fprintf('Total processing time: %.2f hours\n', toc(total_start)/3600);

end
