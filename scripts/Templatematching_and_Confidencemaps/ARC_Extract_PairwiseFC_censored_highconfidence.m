function mean_fc = ARC_Extract_PairwiseFC_censored_highconfidence(dconn_file, dscalar_file, network_label_A, network_label_B, distmat_file, dist_thresh_mm, confidence_thresh)

% Compute mean FC between two networks with distance censoring from DVD
%
% Inputs:
%   dconn_file      - .dconn.nii file
%   dscalar_file    -  network map .dscalar.nii file
%   network_label_A - label for first network (e.g., DMN = 1)
%   network_label_B - label for second network (e.g., DAN = 2)
%   distmat_file    - Conte distance matrix .mat file
%   dist_thresh_mm  - minimum distance threshold in mm (>=30mm)
%   confidence_thresh - max dice value (0.3)
% Output:
%   mean_fc         - mean Fisher Z FC between (or within) the networkswith distance censored

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
wbcommand='~/workbench/bin_rh_linux64/wb_command';

%------------------------------------------------------------------------

fc_cifti = ciftiopen(dconn_file,wbcommand);
fc_mat = fc_cifti.cdata(1:64984, 1:64984); % cortical vertices only

net_cifti = ciftiopen(dscalar_file, wbcommand);
net_labels = net_cifti.cdata(1:64984);  % Only cortical

%filter for high confidence vertices
dice_file = strrep(dscalar_file, '_Dice.dscalar.nii', '_14networkassignment_Vertexwise_sample1_matchedconditions_maxdice.dscalar.nii');
dice_cifti = ciftiopen(dice_file, wbcommand);
max_dice = dice_cifti.cdata(1:64984);  % cortical surface

dist_data = load(distmat_file);
dist_mat = dist_data.distances;

%Filter both network and high confidence Dice vertices
idx_A = find(net_labels == network_label_A & max_dice >= confidence_thresh); %>=0.3
idx_B = find(net_labels == network_label_B & max_dice >= confidence_thresh);%>=0.3

if isempty(idx_A) || isempty(idx_B)
        warning('No high-confidence vertices found for one or both network labels (%d, %d)', network_label_A, network_label_B);
        mean_fc = NaN;
        return
end

fc_submat = fc_mat(idx_A, idx_B);
dist_submat = dist_mat(idx_A, idx_B);

% Apply distance censoring
mask = dist_submat >= dist_thresh_mm;
fc_censored = fc_submat(mask);

% Get mean FC and fisher z transform first
fc_z = atanh(fc_censored);
mean_fc = mean(fc_z(~isnan(fc_z)));

end


