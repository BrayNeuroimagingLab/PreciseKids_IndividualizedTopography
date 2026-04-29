function fc_table = ARC_Extract_MeanFC_PKids_highconfidence(subject, dconn_dir, dscalar_dir, distmat_file, network_labels, dist_thresh_mm, confidence_thresh)

%Uses Extract_PairwiseFC_censored.m to open dscalars
%
%
% Inputs:
%   subject    - each subject
%   dconn_dir       - dconn.nii files path
%   dscalar_dir     - network dscalar.nii files path
%   distmat_file    - distance .mat file path (using generic fsLR32: Conte_DISTANCE_32k_fsLR-001.mat)
%   network_labels  - array of network labels (1:16)
%   dist_thresh_mm  - geodesic distance censoring threshold (30mm)
%   confidence_thresh  -max dice thresh(0.3)
% Output:
%   fc_table        -  table with all within/between FC values


%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
wbcommand='~/workbench/bin_rh_linux64/wb_command';

%------------------------------------------------------------------------

%If max dice not given
if nargin < 7
   confidence_thresh = 0.3; %max dice 0.3
end

rows = [];


subj = subject;
fprintf('Processing %s...\n', subj);

%group
if endsWith(subj, 'P')
    group = "Adult";
elseif endsWith(subj, 'C')
    group = "Child";
else
    warning('Unknown group for subject %s', subj);
    group = "Unknown";
end

dconn_file = fullfile(dconn_dir, [subj '_alltasks_leftover15min.dconn.nii']);
dscalar_file = fullfile(dscalar_dir, [subj '_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii']);

for i = 1:length(network_labels)
    netA = network_labels(i);
    for j = i:length(network_labels)
        netB = network_labels(j);

        mean_fc = ARC_Extract_PairwiseFC_censored_highconfidence( ...
               dconn_file, dscalar_file, netA, netB, distmat_file, dist_thresh_mm, confidence_thresh);

        row = {subj, group, netA, netB, mean_fc};
        rows = [rows; row];
    end
end


% Convert to table
fc_table = cell2table(rows, ...
   'VariableNames', {'Subject', 'Group', 'NetworkA', 'NetworkB', 'FC'});

save(fullfile(dconn_dir, [subj '_fc_table_leftover15min_highconfidence.mat']), 'fc_table');

end


