% Find where low motion adults, low motion children, and high motion children overlap
% Using PKWTA winner take all individual template matched maps

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
basedir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/';
output_dir = fullfile(basedir, 'PKWTA_MotionGroups_OverlapMaps');

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Define motion-based groups
low_motion_adults = [2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26]; % All P subjects excluding 22 and 017
low_motion_children = [2,5,7,9,15,18,21,23,25,26]; % C subjects - low motion
high_motion_children = [4,6,8,10,11,12,13,14,16,17,19,20,22,24]; % C subjects - high motion

% Use a template to preserve header info
template = ciftiopen(fullfile(basedir, ...
    'Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii'), wbcommand);

template_data = template.cdata;
n_verts = size(template_data, 1);

% Network 
networks = [1:3, 5, 7:16];

% Store per-network binary masks for each motion group
lm_adult_netmask = containers.Map('KeyType','double','ValueType','any');
lm_child_netmask = containers.Map('KeyType','double','ValueType','any');
hm_child_netmask = containers.Map('KeyType','double','ValueType','any');

for net = networks
    lm_adult_netmask(net) = zeros(n_verts, 1);
    lm_child_netmask(net) = zeros(n_verts, 1);
    hm_child_netmask(net) = zeros(n_verts, 1);
end

% Loop through subjects and accumulate counts
for sub = 2:26
    if sub == 3
        continue;
    end
    subnum = sprintf('1973%03d', sub);

    % Process low motion adults (P subjects)
    if ismember(sub, low_motion_adults)
        try
            fname = sprintf('%s/sub-%sP_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', ...
                basedir, subnum);
            map = ciftiopen(fname, wbcommand);
            data = map.cdata;

            for net = networks
                this_mask = double(data == net);
                lm_adult_netmask(net) = lm_adult_netmask(net) + this_mask;
            end
        catch
            fprintf('Missing file for sub-%sP\n', subnum);
        end
    end
    
    % Process low motion children (C subjects)
    if ismember(sub, low_motion_children)
        try
            fname = sprintf('%s/sub-%sC_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', ...
                basedir, subnum);
            map = ciftiopen(fname, wbcommand);
            data = map.cdata;

            for net = networks
                this_mask = double(data == net);
                lm_child_netmask(net) = lm_child_netmask(net) + this_mask;
            end
        catch
            fprintf('Missing file for sub-%sC\n', subnum);
        end
    end
    
    % Process high motion children (C subjects)
    if ismember(sub, high_motion_children)
        try
            fname = sprintf('%s/sub-%sC_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', ...
                basedir, subnum);
            map = ciftiopen(fname, wbcommand);
            data = map.cdata;

            for net = networks
                this_mask = double(data == net);
                hm_child_netmask(net) = hm_child_netmask(net) + this_mask;
            end
        catch
            fprintf('Missing file for sub-%sC\n', subnum);
        end
    end
end

% Create overlap maps per network with 3 groups
for net = networks
    lm_adult_count = lm_adult_netmask(net);
    lm_child_count = lm_child_netmask(net);
    hm_child_count = hm_child_netmask(net);

    overlap_map = zeros(n_verts,1); % 0 = not in any group

    n_lm_adults = length(low_motion_adults);
    n_lm_children = length(low_motion_children);
    n_hm_children = length(high_motion_children);
    
    % 20% threshold on each group
    lm_adult_thresh = 0.2 * n_lm_adults;
    lm_child_thresh = 0.2 * n_lm_children;
    hm_child_thresh = 0.2 * n_hm_children;
    
    lm_adult_mask_thresh = lm_adult_count >= lm_adult_thresh;
    lm_child_mask_thresh = lm_child_count >= lm_child_thresh;
    hm_child_mask_thresh = hm_child_count >= hm_child_thresh;
    
    % Create labels for different combinations
    % 1 = Low motion adults only
    % 2 = Low motion children only  
    % 3 = High motion children only
    % 4 = Low motion adults + Low motion children
    % 5 = Low motion adults + High motion children
    % 6 = Low motion children + High motion children
    % 7 = All three groups
    
    only_lm_adults = lm_adult_mask_thresh & ~lm_child_mask_thresh & ~hm_child_mask_thresh;
    only_lm_children = ~lm_adult_mask_thresh & lm_child_mask_thresh & ~hm_child_mask_thresh;
    only_hm_children = ~lm_adult_mask_thresh & ~lm_child_mask_thresh & hm_child_mask_thresh;
    
    lm_adults_lm_children = lm_adult_mask_thresh & lm_child_mask_thresh & ~hm_child_mask_thresh;
    lm_adults_hm_children = lm_adult_mask_thresh & ~lm_child_mask_thresh & hm_child_mask_thresh;
    lm_children_hm_children = ~lm_adult_mask_thresh & lm_child_mask_thresh & hm_child_mask_thresh;
    
    all_three = lm_adult_mask_thresh & lm_child_mask_thresh & hm_child_mask_thresh;

    overlap_map(only_lm_adults) = 1;
    overlap_map(only_lm_children) = 2;
    overlap_map(only_hm_children) = 3;
    overlap_map(lm_adults_lm_children) = 4;
    overlap_map(lm_adults_hm_children) = 5;
    overlap_map(lm_children_hm_children) = 6;
    overlap_map(all_three) = 7;

    % Save to file
    template.cdata = overlap_map;
    outname = sprintf('%s/Network%d_MotionGroups_1LMA_2LMC_3HMC_4LMALMC_5LMAHMC_6LMCHMC_7All_Thresh0.2.dscalar.nii', output_dir, net);
    ciftisavereset(template, outname, wbcommand);
    fprintf('Saved %s\n', outname);
end

%% Group-level analysis with 3 motion groups

output_dir_group = fullfile(basedir, 'PKWTA_GroupLevel_MotionGroups');

if ~exist(output_dir_group, 'dir')
    mkdir(output_dir_group);
end

% Define network IDs
networks = [1:3, 5, 7:16];  
n_networks = length(networks);

% Create lookup to index into count array
net_lookup = containers.Map(networks, 1:n_networks);

% Initialize count matrices: [vertex x network]
lm_adult_counts = zeros(n_verts, n_networks);
lm_child_counts = zeros(n_verts, n_networks);
hm_child_counts = zeros(n_verts, n_networks);

% Accumulate counts per vertex per network for each motion group
for sub = 2:26
    if sub == 3, continue; end
    subnum = sprintf('1973%03d', sub);

    % Low motion adults (P subjects)
    if ismember(sub, low_motion_adults)
        try
            fname = sprintf('%s/sub-%sP_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', basedir, subnum);
            data = ciftiopen(fname, wbcommand).cdata;

            for net = networks
                idx = net_lookup(net);
                mask = (data == net);
                lm_adult_counts(:, idx) = lm_adult_counts(:, idx) + mask;
            end
        catch
            fprintf('Missing or bad file for sub-%sP\n', subnum);
        end
    end
    
    % Low motion children (C subjects)
    if ismember(sub, low_motion_children)
        try
            fname = sprintf('%s/sub-%sC_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', basedir, subnum);
            data = ciftiopen(fname, wbcommand).cdata;

            for net = networks
                idx = net_lookup(net);
                mask = (data == net);
                lm_child_counts(:, idx) = lm_child_counts(:, idx) + mask;
            end
        catch
            fprintf('Missing or bad file for sub-%sC\n', subnum);
        end
    end
    
    % High motion children (C subjects)
    if ismember(sub, high_motion_children)
        try
            fname = sprintf('%s/sub-%sC_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', basedir, subnum);
            data = ciftiopen(fname, wbcommand).cdata;

            for net = networks
                idx = net_lookup(net);
                mask = (data == net);
                hm_child_counts(:, idx) = hm_child_counts(:, idx) + mask;
            end
        catch
            fprintf('Missing or bad file for sub-%sC\n', subnum);
        end
    end
end

% Winner-take-all per motion group (max count per vertex)
[~, lm_adult_wta_idx] = max(lm_adult_counts, [], 2);
[~, lm_child_wta_idx] = max(lm_child_counts, [], 2);
[~, hm_child_wta_idx] = max(hm_child_counts, [], 2);

% Map back to network IDs
net_ids = networks(:);
lm_adult_wta_map = net_ids(lm_adult_wta_idx);
lm_child_wta_map = net_ids(lm_child_wta_idx);
hm_child_wta_map = net_ids(hm_child_wta_idx);

% Save group-level PKWTA maps
template.cdata = lm_adult_wta_map;
ciftisavereset(template, fullfile(output_dir_group, 'GroupPKWTA_LowMotionAdults.dscalar.nii'), wbcommand);

template.cdata = lm_child_wta_map;
ciftisavereset(template, fullfile(output_dir_group, 'GroupPKWTA_LowMotionChildren.dscalar.nii'), wbcommand);

template.cdata = hm_child_wta_map;
ciftisavereset(template, fullfile(output_dir_group, 'GroupPKWTA_HighMotionChildren.dscalar.nii'), wbcommand);

% Find overlap per network on the winner take all maps
for net = networks
    overlap_map = zeros(n_verts, 1);

    in_lm_adult = (lm_adult_wta_map == net);
    in_lm_child = (lm_child_wta_map == net);
    in_hm_child = (hm_child_wta_map == net);

    % Same labeling as before
    only_lm_adults = in_lm_adult & ~in_lm_child & ~in_hm_child;
    only_lm_children = ~in_lm_adult & in_lm_child & ~in_hm_child;
    only_hm_children = ~in_lm_adult & ~in_lm_child & in_hm_child;
    
    lm_adults_lm_children = in_lm_adult & in_lm_child & ~in_hm_child;
    lm_adults_hm_children = in_lm_adult & ~in_lm_child & in_hm_child;
    lm_children_hm_children = ~in_lm_adult & in_lm_child & in_hm_child;
    
    all_three = in_lm_adult & in_lm_child & in_hm_child;

    overlap_map(only_lm_adults) = 1;
    overlap_map(only_lm_children) = 2;
    overlap_map(only_hm_children) = 3;
    overlap_map(lm_adults_lm_children) = 4;
    overlap_map(lm_adults_hm_children) = 5;
    overlap_map(lm_children_hm_children) = 6;
    overlap_map(all_three) = 7;

    template.cdata = overlap_map;
    outname = sprintf('%s/GroupPKWTA_MotionOverlap_Network%d_1LMA_2LMC_3HMC_4LMALMC_5LMAHMC_6LMCHMC_7All.dscalar.nii', output_dir_group, net);
    ciftisavereset(template, outname, wbcommand);
    fprintf('Saved %s\n', outname);
end

% Create combined overlap map (vertices that overlap across all 3 groups)
combined_overlap = zeros(n_verts, 1);

for net = networks
    in_lm_adult = (lm_adult_wta_map == net);
    in_lm_child = (lm_child_wta_map == net);
    in_hm_child = (hm_child_wta_map == net);
    all_three = in_lm_adult & in_lm_child & in_hm_child;

    % Label overlapping vertices with the network number
    combined_overlap(all_three) = net;
end

% Save the combined overlap map
template.cdata = combined_overlap;
outname = fullfile(output_dir_group, 'GroupPKWTA_CombinedOverlap_AllThreeGroups_NetworkLabeled.dscalar.nii');
ciftisavereset(template, outname, wbcommand);
fprintf('Saved combined 3-group overlap map: %s\n', outname);

%% Save separate binary maps per network for each motion group

thresh_prop = 0.2;  % 20% threshold

n_lm_adults = length(low_motion_adults);
n_lm_children = length(low_motion_children);  
n_hm_children = length(high_motion_children);

lm_adult_thresh = thresh_prop * n_lm_adults;
lm_child_thresh = thresh_prop * n_lm_children;
hm_child_thresh = thresh_prop * n_hm_children;

for net = networks
    lm_adult_count = lm_adult_netmask(net);  
    lm_child_count = lm_child_netmask(net);  
    hm_child_count = hm_child_netmask(net);

    % Thresholded group masks
    lm_adult_mask_thresh = lm_adult_count >= lm_adult_thresh;
    lm_child_mask_thresh = lm_child_count >= lm_child_thresh;
    hm_child_mask_thresh = hm_child_count >= hm_child_thresh;

    % Binary outputs for each group
    lm_adults_bin = double(lm_adult_mask_thresh);
    lm_children_bin = double(lm_child_mask_thresh);
    hm_children_bin = double(hm_child_mask_thresh);
    
    % Overlap binary (where all 3 groups overlap)
    all_three_overlap_bin = double(lm_adult_mask_thresh & lm_child_mask_thresh & hm_child_mask_thresh);

    % Save Low Motion Adults (binary)
    template.cdata = lm_adults_bin;
    outLMA = sprintf('%s/Network%d_LowMotionAdults_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outLMA, wbcommand);

    % Save Low Motion Children (binary)
    template.cdata = lm_children_bin;
    outLMC = sprintf('%s/Network%d_LowMotionChildren_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outLMC, wbcommand);

    % Save High Motion Children (binary)
    template.cdata = hm_children_bin;
    outHMC = sprintf('%s/Network%d_HighMotionChildren_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outHMC, wbcommand);
    
    % Save All Three Groups Overlap (binary)
    template.cdata = all_three_overlap_bin;
    outOverlap = sprintf('%s/Network%d_AllThreeGroupsOverlap_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outOverlap, wbcommand);

    fprintf('Saved %s\nSaved %s\nSaved %s\nSaved %s\n', outLMA, outLMC, outHMC, outOverlap);
end

fprintf('\nMotion-based group analysis completed!\n');
fprintf('Low Motion Adults: %d subjects\n', n_lm_adults);
fprintf('Low Motion Children: %d subjects\n', n_lm_children);
fprintf('High Motion Children: %d subjects\n', n_hm_children);