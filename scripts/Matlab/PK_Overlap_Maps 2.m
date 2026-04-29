% Find where adults and children overlap like HCP overlap maps
% Using PKWTA winner take all indiviudal template matched maps

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
basedir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/';
output_dir = fullfile(basedir, 'PKWTA_OverlapMaps');


if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Use a template to preserve header info
template = ciftiopen(fullfile(basedir, ...
    'Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii'), wbcommand);

template_data = template.cdata;
n_verts = size(template_data, 1);

% Network 
networks = [1:3, 5, 7:16];


child_assignments = zeros(n_verts, 1);
adult_assignments = zeros(n_verts, 1);

% Store per-network binary masks
child_netmask = containers.Map('KeyType','double','ValueType','any');
adult_netmask = containers.Map('KeyType','double','ValueType','any');

for net = networks
    child_netmask(net) = zeros(n_verts, 1);
    adult_netmask(net) = zeros(n_verts, 1);
end

% Loop through subjects
for sub = 2:26
    if sub == 3
        continue;
    end
    subnum = sprintf('1973%03d', sub);

    for group = ["C", "P"]
        try
            fname = sprintf('%s/sub-%s%s_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', ...
                basedir, subnum, group);
            map = ciftiopen(fname, wbcommand);
            data = map.cdata;

            for net = networks
                this_mask = double(data == net); % binary mask for this network
                if group == "C"
                    child_netmask(net) = child_netmask(net) + this_mask;
                else
                    adult_netmask(net) = adult_netmask(net) + this_mask;
                end
            end
        catch
            fprintf('Missing file for sub-%s%s\n', subnum, group);
        end
    end
end

% Create 1/2/3 overlap maps per network
for net = networks
    child_count = child_netmask(net);
    adult_count = adult_netmask(net);

    overlap_map = zeros(n_verts,1); % not in either group

    n_children = 24; 
    n_adults = 24;   
    %20% or 0.2 threshold on each group first before finding overlap
    child_thresh = 0.2 * n_children;
    adult_thresh = 0.2 * n_adults;
    
    child_mask_thresh = child_count >= child_thresh;
    adult_mask_thresh = adult_count >= adult_thresh;
    
    only_adults = adult_mask_thresh & ~child_mask_thresh;
    only_children = child_mask_thresh & ~adult_mask_thresh;
    both = child_mask_thresh & adult_mask_thresh;

    overlap_map(only_adults) = 1;
    overlap_map(only_children) = 2;
    overlap_map(both) = 3;

    % Save to file
    template.cdata = overlap_map;
    outname = sprintf('%s/Network%d_OverlapMap_Adults1_Children2_Both3_Thresh0.2.dscalar.nii', output_dir, net);
    ciftisavereset(template, outname, wbcommand);
    fprintf('Saved %s\n', outname);
end








%% Including all networks, see what the overlap is, on a group level

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
basedir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/';
output_dir = fullfile(basedir, 'PKWTA_GroupLevel_Overlap');

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Load template
template = ciftiopen(fullfile(basedir, ...
    'Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii'), wbcommand);
n_verts = size(template.cdata, 1);

% Define network IDs
networks = [1:3, 5, 7:16];  
n_networks = length(networks);

% Create lookup to index into count array
net_lookup = containers.Map(networks, 1:n_networks);

% Initialize count matrices: [vertex x network]
child_counts = zeros(n_verts, n_networks);
adult_counts = zeros(n_verts, n_networks);

% Accumulate counts per vertex per network
for sub = 2:26
    if sub == 3, continue; end
    subnum = sprintf('1973%03d', sub);

    for group = ["C", "P"]
        try
            fname = sprintf('%s/sub-%s%s_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', basedir, subnum, group);
            data = ciftiopen(fname, wbcommand).cdata;

            for net = networks
                idx = net_lookup(net);
                mask = (data == net);
                if group == "C"
                    child_counts(:, idx) = child_counts(:, idx) + mask;
                else
                    adult_counts(:, idx) = adult_counts(:, idx) + mask;
                end
            end
        catch
            fprintf('Missing or bad file for sub-%s%s\n', subnum, group);
        end
    end
end

% Winner-take-all per group (max count per vertex)
[~, child_wta_idx] = max(child_counts, [], 2);
[~, adult_wta_idx] = max(adult_counts, [], 2);

% Map back to network IDs
net_ids = networks(:);
child_wta_map = net_ids(child_wta_idx);
adult_wta_map = net_ids(adult_wta_idx);

% Save group-level PKWTA maps
template.cdata = child_wta_map;
ciftisavereset(template, fullfile(output_dir, 'GroupPKWTA_Children.dscalar.nii'), wbcommand);

template.cdata = adult_wta_map;
ciftisavereset(template, fullfile(output_dir, 'GroupPKWTA_Adults.dscalar.nii'), wbcommand);

%find overlap per network onthe winner take all maps
for net = networks
    overlap_map = zeros(n_verts, 1);

    in_child = (child_wta_map == net);
    in_adult = (adult_wta_map == net);

    only_adult = in_adult & ~in_child;
    only_child = in_child & ~in_adult;
    both = in_child & in_adult;

    overlap_map(only_adult) = 1;
    overlap_map(only_child) = 2;
    overlap_map(both) = 3;

    template.cdata = overlap_map;
    outname = sprintf('%s/GroupPKWTA_Overlap_Network%d_Adults1_Children2_Both3.dscalar.nii', output_dir, net);
    ciftisavereset(template, outname, wbcommand);
    fprintf('Saved %s\n', outname);
end

% Create one combined overlap map
combined_overlap = zeros(n_verts, 1);

for net = networks
    in_child = (child_wta_map == net);
    in_adult = (adult_wta_map == net);
    both = in_child & in_adult;

    % Label overlapping vertices with the network number
    combined_overlap(both) = net;
end

% Save the combined overlap map
template.cdata = combined_overlap;
outname = fullfile(output_dir, 'GroupPKWTA_CombinedOverlap_AdultsChildren_NetworkLabeled.dscalar.nii');
ciftisavereset(template, outname, wbcommand);
fprintf('Saved combined network overlap map: %s\n', outname);


% Create one combined difference map: net = different in either group only
combined_difference = zeros(n_verts, 1);

for net = networks
    in_child = (child_wta_map == net);
    in_adult = (adult_wta_map == net);

    only_one_group = xor(in_child, in_adult); % different in either group
    combined_difference(only_one_group) = net;
end

% Save the combined difference map
template.cdata = combined_difference;
outname = fullfile(output_dir, 'GroupPKWTA_CombinedDifference_EitherGroupOnly_NetworkLabeled.dscalar.nii');
ciftisavereset(template, outname, wbcommand);
fprintf('Saved combined difference map: %s\n', outname);



%% Save separate binary maps per network (Adults / Children / Overlap)

thresh_prop = 0.2;  % 20% threshold

n_children_loaded = 0;
n_adults_loaded   = 0;
for sub = 2:26
    if sub == 3, continue; end
    subnum = sprintf('1973%03d', sub);

    if exist(sprintf('%s/sub-%sC_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', basedir, subnum), 'file')
        n_children_loaded = n_children_loaded + 1;
    end
    if exist(sprintf('%s/sub-%sP_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii', basedir, subnum), 'file')
        n_adults_loaded = n_adults_loaded + 1;
    end
end

n_children_loaded = 24;
n_adults_loaded   = 24;

child_thresh = thresh_prop * n_children_loaded;
adult_thresh = thresh_prop * n_adults_loaded;

for net = networks
    child_count = child_netmask(net);  
    adult_count = adult_netmask(net);  

    % Thresholded group masks
    child_mask_thresh = child_count >= child_thresh;
    adult_mask_thresh = adult_count >= adult_thresh;

    % Binary outputs
    adults_only_bin  = adult_mask_thresh & ~child_mask_thresh;   % 1 where adults-only, else 0
    children_only_bin= child_mask_thresh & ~adult_mask_thresh;   % 1 where children-only, else 0
    overlap_bin      = child_mask_thresh &  adult_mask_thresh;   % 1 where both, else 0

    % Save Adults-only (binary)
    template.cdata = double(adults_only_bin);
    outA = sprintf('%s/Network%d_Adults_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outA, wbcommand);

    % Save Children-only (binary)
    template.cdata = double(children_only_bin);
    outC = sprintf('%s/Network%d_Children_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outC, wbcommand);

    % Save Overlap-only (binary; 1 where in both)
    template.cdata = double(overlap_bin);
    outO = sprintf('%s/Network%d_Overlap_Thresh%.1f.dscalar.nii', output_dir, net, thresh_prop);
    ciftisavereset(template, outO, wbcommand);

    fprintf('Saved %s\nSaved %s\nSaved %s\n', outA, outC, outO);
end







