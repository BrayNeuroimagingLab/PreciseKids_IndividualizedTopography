function ARC_Templatematching_PKdata_alltasks_matchedconditions_movie(subject, task)
%subject is their full subject ID, e.g., 'sub-1973018C'
%task input e.g., 'task-RX'
%Based on Dworetsky et al 2021 NeuroImage template matching approach using DICE on movie Templates with 24 networks

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
wbcommand='~/workbench/bin_rh_linux64/wb_command';

%------------------------------------------------------------------------

%Get dconn
connFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_sample1_censored.dconn.nii', subject, task);
sub_data_dconn = ciftiopen(connFile, wbcommand);
sub_data_dconn = sub_data_dconn.cdata;

%Thresholds for each vertex (95 percent)
numVertices = size(sub_data_dconn, 1);
fprintf('Number of vertices: %d\n', numVertices);
thresholds = zeros(numVertices, 1);
    
%Calculate threshold for each vertex
for vertex = 1:numVertices
   thresholds(vertex) = prctile(sub_data_dconn(vertex, :), 95);
end
fprintf('Thresholds array size: [%d x %d]\n', size(thresholds, 1), size(thresholds, 2));

% Pre-binarize the entire connectivity matrix
binarized_connectivity = zeros(size(sub_data_dconn));
for vertex = 1:numVertices
    binarized_connectivity(vertex, :) = sub_data_dconn(vertex, :) >= thresholds(vertex);
end

fprintf('Binary connectivity size: [%d x %d]\n', size(binarized_connectivity, 1), size(binarized_connectivity, 2));
    
clear sub_data_dconn;

%Open templates (KMmovies)
networkList = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24];


for networks = 1:length(networkList)
    networkNum = networkList(networks);
    msc{networks} = ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/moviescalar91282_network%d.dscalar.nii', networkNum), wbcommand);
    binarizedTemplates{1,networks} = msc{networks}.cdata;
end

% Initialize output
numTemplates = numel(binarizedTemplates);
assignedNetwork = zeros(numVertices, 1);


% For each vertex using pre-binarized data
for vertex = 1:numVertices
    % Get this vertex connectivity profile
    vertexBinarizedProfile = binarized_connectivity(vertex, :);

    % Calculate Dice coefficient with each template
    diceToTemplateVertex = zeros(1, numTemplates);

    for template = 1:numTemplates
        templateMap = binarizedTemplates{template}';
    
        % Only take the first element of templateMap if it's the right size
        if length(templateMap) == length(vertexBinarizedProfile)
            validIndices = ~isnan(vertexBinarizedProfile) & ~isnan(templateMap);
        
            if any(validIndices)
                % Get valid data - already binarized
                validProfile = logical(vertexBinarizedProfile(validIndices));
                validTemplate = logical(templateMap(validIndices));
            
                % Use built-in dice function
                diceToTemplateVertex(template) = dice(validProfile, validTemplate);
            else
                diceToTemplateVertex(template) = NaN;
            end
        else
            % Print sizes for debugging
            fprintf('Size mismatch: vertexBinarizedProfile [1 x %d], templateMap [%d x %d]\n',length(vertexBinarizedProfile), size(templateMap, 1), size(templateMap, 2));
            diceToTemplateVertex(template) = NaN;
        end
    end

    [max_dice, maxIndex] = max(diceToTemplateVertex);
    assignedNetwork(vertex) = networkList(maxIndex);
    max_dice_map(vertex) = max_dice;

    % Normalize for entropy calc below
    % Calculate entropy
    valid_dice = diceToTemplateVertex(~isnan(diceToTemplateVertex));
    if ~isempty(valid_dice)
        dice_norm = valid_dice / sum(valid_dice);
        entropy_map(vertex) = -sum(dice_norm .* log2(dice_norm + eps));
    else
        entropy_map(vertex) = NaN;
    end

end

% Save the network assignment directly
sub_data=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_sample1_censored.dtseries.nii', subject, task), wbcommand);
sub_data.cdata=assignedNetwork;
outputFile = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_KMmovies_24networkassignment_Vertexwise_sample1_matchedconditions_Dice.dscalar.nii', subject, task);
ciftisavereset(sub_data, outputFile, wbcommand);

% Save maximum dice map
sub_data.cdata = max_dice_map';
max_dice_file = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_KMmovies_24networkassignment_Vertexwise_sample1_matchedconditions_maxdice.dscalar.nii', subject, task);
ciftisavereset(sub_data, max_dice_file, wbcommand);
    
% Save entropy map
sub_data.cdata = entropy_map';
entropy_file = sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/%s_%s_KMmovies_24networkassignment_Vertexwise_sample1_matchedconditions_entropy.dscalar.nii', subject, task);
ciftisavereset(sub_data, entropy_file, wbcommand);

fprintf('Successfully processed subject %s for task %s\n', subject, task);

end
