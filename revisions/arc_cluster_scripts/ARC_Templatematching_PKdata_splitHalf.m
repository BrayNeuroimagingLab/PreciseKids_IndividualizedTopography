function ARC_Templatematching_PKdata_splitHalf(subject, task, duration, sample)
% Template matching (Dice) for split-half reliability analysis.
% duration : '15min' or '30min'
% sample   : '1' or '2'
% Based on Dworetsky et al 2021 NeuroImage template matching approach.

addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
wbcommand = '~/workbench/bin_rh_linux64/wb_command';

MATDIR = '/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir';

% Load dconn
connFile = sprintf('%s/%s_%s_%s_sample%s.dconn.nii', MATDIR, subject, task, duration, sample);
fprintf('Loading dconn: %s\n', connFile);
sub_data_dconn = ciftiopen(connFile, wbcommand);
sub_data_dconn = sub_data_dconn.cdata;

% Threshold each vertex at 95th percentile and binarize
numVertices = size(sub_data_dconn, 1);
fprintf('Vertices: %d\n', numVertices);

binarized_connectivity = zeros(size(sub_data_dconn));
for vertex = 1:numVertices
    thr = prctile(sub_data_dconn(vertex, :), 95);
    binarized_connectivity(vertex, :) = sub_data_dconn(vertex, :) >= thr;
end
clear sub_data_dconn;

% Load HCP network templates
networkList = [1,2,3,5,7,8,9,10,11,12,13,14,15,16];
for n = 1:length(networkList)
    msc{n} = ciftiopen(sprintf('%s/HCPnetwork%d_overlap.dscalar.nii', MATDIR, networkList(n)), wbcommand);
    binarizedTemplates{n} = msc{n}.cdata;
end

% Template matching
assignedNetwork = zeros(numVertices, 1);
max_dice_map    = zeros(numVertices, 1);
entropy_map     = zeros(numVertices, 1);

for vertex = 1:numVertices
    vertexProfile = binarized_connectivity(vertex, :);
    diceScores    = zeros(1, length(networkList));

    for t = 1:length(networkList)
        templateMap = binarizedTemplates{t}';
        if length(templateMap) == length(vertexProfile)
            validIdx = ~isnan(vertexProfile) & ~isnan(templateMap);
            if any(validIdx)
                diceScores(t) = dice(logical(vertexProfile(validIdx)), logical(templateMap(validIdx)));
            else
                diceScores(t) = NaN;
            end
        else
            diceScores(t) = NaN;
        end
    end

    [max_d, maxIdx]      = max(diceScores);
    assignedNetwork(vertex) = networkList(maxIdx);
    max_dice_map(vertex)    = max_d;

    valid_dice = diceScores(~isnan(diceScores));
    if ~isempty(valid_dice)
        d_norm = valid_dice / sum(valid_dice);
        entropy_map(vertex) = -sum(d_norm .* log2(d_norm + eps));
    else
        entropy_map(vertex) = NaN;
    end
end

% Load dtseries as cifti template for saving outputs
dts_file = sprintf('%s/%s_%s_%s_sample%s.dtseries.nii', MATDIR, subject, task, duration, sample);
sub_data = ciftiopen(dts_file, wbcommand);

% Save network assignment (Dice map)
sub_data.cdata = assignedNetwork;
outDice = sprintf('%s/%s_%s_HCPAdultChild_overlap_%s_sample%s_Dice.dscalar.nii', MATDIR, subject, task, duration, sample);
ciftisavereset(sub_data, outDice, wbcommand);
fprintf('Saved Dice map: %s\n', outDice);

% Save entropy map
sub_data.cdata = entropy_map';
outEntropy = sprintf('%s/%s_%s_HCPAdultChild_overlap_14networkassignment_Vertexwise_%s_sample%s_entropy.dscalar.nii',MATDIR, subject, task, duration, sample);
ciftisavereset(sub_data, outEntropy, wbcommand);
fprintf('Saved entropy map: %s\n', outEntropy);

fprintf('Done: %s  duration=%s  sample=%s\n', subject, duration, sample);
end
