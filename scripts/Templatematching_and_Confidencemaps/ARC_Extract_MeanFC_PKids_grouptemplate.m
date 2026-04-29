function fc_table = ARC_Extract_MeanFC_PKids_grouptemplate(subject, dconn_dir, group_dscalar_adult, group_dscalar_child, distmat_file, network_labels, dist_thresh_mm)

% Inputs:
%   subject             - each sub
%   dconn_dir           - path to subject-level .dconn.nii files
%   group_dscalar_adult - adult group network map
%   group_dscalar_child - child group network map
%   distmat_file        - Conte distance matrix
%   network_labels      - array of network labels (e.g., 1:16)
%   dist_thresh_mm      - distance threshold (e.g., 30)
% Output:
%   fc_table            - table of FC results

%------------------------------------------------------------------------
addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab'))
addpath(genpath('~/Programs/matlab/Utilities/'))
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
wbcommand='~/workbench/bin_rh_linux64/wb_command';
%------------------------------------------------------------------------

% Load group winner take all maps
template_adult = ciftiopen(group_dscalar_adult, wbcommand);
template_child = ciftiopen(group_dscalar_child, wbcommand);
dist_data = load(distmat_file);
dist_mat = dist_data.distances;

rows = [];

subj = subject;
fprintf('Processing %s...\n', subj);

% Assign group and network template
if endsWith(subj, 'P')
    group = "Adult";
    net_labels = template_adult.cdata(1:64984);
elseif endsWith(subj, 'C')
    group = "Child";
    net_labels = template_child.cdata(1:64984);
end

% Load subject dconn
dconn_file = fullfile(dconn_dir, [subj '_alltasks_leftover15min.dconn.nii']);
fc_cifti = ciftiopen(dconn_file, wbcommand);
fc_mat = fc_cifti.cdata(1:64984, 1:64984); % cortical only

% Loop over network pairs
for i = 1:length(network_labels)
    netA = network_labels(i);
    idx_A = find(net_labels == netA);
    for j = i:length(network_labels)
        netB = network_labels(j);
        idx_B = find(net_labels == netB);

        if isempty(idx_A) || isempty(idx_B)
            warning('No vertices for net %d or %d in %s', netA, netB, subj);
            mean_fc = NaN;
        else
            % Extract data
            fc_submat = fc_mat(idx_A, idx_B);
            fprintf('Max FC: %.16f\n', max(fc_submat(:)));
            fprintf('Min FC: %.16f\n', min(fc_submat(:)));
            fprintf('Any exactly 1? %d\n', any(fc_submat(:) == 1));
            fprintf('Any exactly -1? %d\n', any(fc_submat(:) == -1));

            dist_submat = dist_mat(idx_A, idx_B);
            fc_censored = fc_submat(dist_submat >= dist_thresh_mm);

            % DEBUG PRINTS
            fprintf('\n--- DEBUG INFO ---\n');
            fprintf('Subject: %s | Group: %s\n', subj, group);
            fprintf('NetworkA: %d (%d verts) | NetworkB: %d (%d verts)\n', ...
                netA, length(idx_A), netB, length(idx_B));
            fprintf('Size fc_submat: [%d x %d] | #fc_censored: %d\n', ...
                size(fc_submat,1), size(fc_submat,2), length(fc_censored));
            fprintf('fc_censored stats — min: %.4f, max: %.4f, NaNs: %d, Infs: %d\n', ...
                min(fc_censored(:)), max(fc_censored(:)), ...
                sum(isnan(fc_censored(:))), sum(isinf(fc_censored(:))));
	
            [r1, c1] = find(fc_submat == 1 & dist_submat >= dist_thresh_mm);
                fprintf('  # of 1.0 correlations after distance censoring: %d\n', length(r1));

            if ~isempty(r1)
                    fprintf('  Example FC=1 at: (%d, %d) | dist = %.4f mm\n', ...
                    r1(1), c1(1), dist_submat(r1(1), c1(1)));
                fprintf('  Vertex indices: A = %d, B = %d\n', idx_A(r1(1)), ...
                idx_B(c1(1)));
		end

            % Clip before Fisher z-transform
            fc_censored(fc_censored >= 1) = 0.9999;
            fc_censored(fc_censored <= -1) = -0.9999;

            % Transform
            fc_z = atanh(fc_censored);

            if any(isinf(fc_z))
                warning('Inf found in atanh(fc_censored) for %s: NetA %d, NetB %d', subj, netA, netB);
            end

            mean_fc = mean(fc_z(~isnan(fc_z)));
        end

        rows = [rows; {subj, group, netA, netB, mean_fc}];
    end
end

fc_table = cell2table(rows, 'VariableNames', {'Subject', 'Group', 'NetworkA', 'NetworkB', 'FC'});
save(fullfile(dconn_dir, [subj '_fc_table_leftover15min_grouptemplate.mat']), 'fc_table');

end
