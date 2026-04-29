%% Setup
wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkassignment_gradiation/';
template_file = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii';
template_map = ciftiopen(template_file, wbcommand);

% List of networks to process
networks = [1:3, 5, 7:16];

% Define motion-based groups
low_motion_adults = [2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26]; 
low_motion_children = [2,5,7,9,15,18,21,23,25,26]; % C subjects - low motion
high_motion_children = [4,6,8,10,11,12,13,14,16,17,19,20,22,24]; % C subjects - high motion

%% Save individual binary assignment maps (same as before, but organized by motion groups)
for sub = 2:26
    if sub == 3
        continue; % Skip subject 03
    end

    if sub < 10
        subnum = sprintf('00%d', sub);
    else
        subnum = sprintf('0%d', sub);
    end

    try
        % Load vertex-wise network assignment
        child_net = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/sub-1973%sC_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_Dice_networkvertices_extractions.txt', subnum));
        parent_net = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/sub-1973%sP_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_Dice_networkvertices_extractions.txt', subnum));

        for net = networks
            % CHILD (will be categorized by motion later)
            binmap = zeros(91282, 1);
            binmap(1:59412) = double(child_net == net);
            template_map.cdata = binmap;
            ciftisavereset(template_map, sprintf('%sNetwork%d_Assignment_sub1973%sC.dscalar.nii', output_dir, net, subnum), wbcommand);

            % PARENT (low motion adults)
            binmap = zeros(91282, 1);
            binmap(1:59412) = double(parent_net == net);
            template_map.cdata = binmap;
            ciftisavereset(template_map, sprintf('%sNetwork%d_Assignment_sub1973%sP.dscalar.nii', output_dir, net, subnum), wbcommand);
        end

    catch
        fprintf('Error: file does not exist or failed for subject %s\n', subnum);
    end
end

%% Compute group overlap for 3 motion groups
for net = networks
    network_lm_adults_count = zeros(91282, 1);    % Low motion adults
    network_lm_children_count = zeros(91282, 1);  % Low motion children
    network_hm_children_count = zeros(91282, 1);  % High motion children

    for sub = 2:26
        if sub == 3
            continue;
        end

        if sub < 10
            subnum = sprintf('00%d', sub);
        else
            subnum = sprintf('0%d', sub);
        end

        try
            % Low Motion Adults (P subjects)
            if ismember(sub, low_motion_adults)
                adult_map = ciftiopen(sprintf('%sNetwork%d_Assignment_sub1973%sP.dscalar.nii', output_dir, net, subnum), wbcommand);
                network_lm_adults_count = network_lm_adults_count + double(adult_map.cdata == 1);
            end
            
            % Low Motion Children (C subjects)
            if ismember(sub, low_motion_children)
                child_map = ciftiopen(sprintf('%sNetwork%d_Assignment_sub1973%sC.dscalar.nii', output_dir, net, subnum), wbcommand);
                network_lm_children_count = network_lm_children_count + double(child_map.cdata == 1);
            end
            
            % High Motion Children (C subjects)
            if ismember(sub, high_motion_children)
                child_map = ciftiopen(sprintf('%sNetwork%d_Assignment_sub1973%sC.dscalar.nii', output_dir, net, subnum), wbcommand);
                network_hm_children_count = network_hm_children_count + double(child_map.cdata == 1);
            end

        catch
            fprintf('Error: overlap failed for subject %s, network %d\n', subnum, net);
        end
    end

    % Save group overlap maps for each motion group
    template_map.cdata = network_lm_adults_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_LowMotionAdults_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);

    template_map.cdata = network_lm_children_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_LowMotionChildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
    
    template_map.cdata = network_hm_children_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_HighMotionChildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
    
    fprintf('Saved overlap maps for network %d\n', net);
end

%% Compute pairwise PROPORTION difference maps between motion groups
for net = networks
    try
        % Load the overlap maps
        lm_adults_map = ciftiopen(sprintf('%sNetwork%d_LowMotionAdults_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
        lm_children_map = ciftiopen(sprintf('%sNetwork%d_LowMotionChildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
        hm_children_map = ciftiopen(sprintf('%sNetwork%d_HighMotionChildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);

        % Convert to proportions first (normalize by group size)
        n_lm_adults = length(low_motion_adults);
        n_lm_children = length(low_motion_children);
        n_hm_children = length(high_motion_children);
        
        lm_adults_prop = lm_adults_map.cdata / n_lm_adults;
        lm_children_prop = lm_children_map.cdata / n_lm_children;
        hm_children_prop = hm_children_map.cdata / n_hm_children;

        % Pairwise PROPORTION differences
        % 1. Low Motion Adults - Low Motion Children (proportion difference)
        prop_diffmap1 = lm_adults_prop - lm_children_prop;
        template_map.cdata = prop_diffmap1;
        ciftisavereset(template_map, sprintf('%sNetwork%d_AssignmentProportionDifference_LowMotionAdults_Minus_LowMotionChildren.dscalar.nii', output_dir, net), wbcommand);

        % 2. Low Motion Adults - High Motion Children (proportion difference)
        prop_diffmap2 = lm_adults_prop - hm_children_prop;
        template_map.cdata = prop_diffmap2;
        ciftisavereset(template_map, sprintf('%sNetwork%d_AssignmentProportionDifference_LowMotionAdults_Minus_HighMotionChildren.dscalar.nii', output_dir, net), wbcommand);

        % 3. Low Motion Children - High Motion Children (proportion difference)
        prop_diffmap3 = lm_children_prop - hm_children_prop;
        template_map.cdata = prop_diffmap3;
        ciftisavereset(template_map, sprintf('%sNetwork%d_AssignmentProportionDifference_LowMotionChildren_Minus_HighMotionChildren.dscalar.nii', output_dir, net), wbcommand);

        fprintf('Saved proportion difference maps for network %d\n', net);
        fprintf('  Group sizes: LM Adults=%d, LM Children=%d, HM Children=%d\n', n_lm_adults, n_lm_children, n_hm_children);
        
    catch err
        fprintf('Error processing network %d: %s\n', net, err.message);
    end
end


%% Create combined visualization maps showing relative group strengths
for net = networks
    try
        % Load the overlap maps
        lm_adults_map = ciftiopen(sprintf('%sNetwork%d_LowMotionAdults_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
        lm_children_map = ciftiopen(sprintf('%sNetwork%d_LowMotionChildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
        hm_children_map = ciftiopen(sprintf('%sNetwork%d_HighMotionChildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);

        % Normalize by group size to get proportions
        n_lm_adults = length(low_motion_adults);
        n_lm_children = length(low_motion_children);
        n_hm_children = length(high_motion_children);
        
        lm_adults_prop = lm_adults_map.cdata / n_lm_adults;
        lm_children_prop = lm_children_map.cdata / n_lm_children;
        hm_children_prop = hm_children_map.cdata / n_hm_children;
        
        % Save proportion maps
        template_map.cdata = lm_adults_prop;
        ciftisavereset(template_map, sprintf('%sNetwork%d_LowMotionAdults_AssignmentProportion.dscalar.nii', output_dir, net), wbcommand);
        
        template_map.cdata = lm_children_prop;
        ciftisavereset(template_map, sprintf('%sNetwork%d_LowMotionChildren_AssignmentProportion.dscalar.nii', output_dir, net), wbcommand);
        
        template_map.cdata = hm_children_prop;
        ciftisavereset(template_map, sprintf('%sNetwork%d_HighMotionChildren_AssignmentProportion.dscalar.nii', output_dir, net), wbcommand);

        % Create winner-take-all map showing which group has highest proportion at each vertex
        combined_props = [lm_adults_prop, lm_children_prop, hm_children_prop];
        [max_props, winner_idx] = max(combined_props, [], 2);
        
        % Only assign winner if the max proportion is above a threshold (e.g., 0.2 = 20%)
        threshold = 0.2;
        winner_map = zeros(size(winner_idx));
        winner_map(max_props >= threshold) = winner_idx(max_props >= threshold);
        
        % Labels: 1=LowMotionAdults, 2=LowMotionChildren, 3=HighMotionChildren
        template_map.cdata = winner_map;
        ciftisavereset(template_map, sprintf('%sNetwork%d_MotionGroupWinner_1LMA_2LMC_3HMC_Thresh%.1f.dscalar.nii', output_dir, net, threshold), wbcommand);

        fprintf('Saved proportion and winner maps for network %d\n', net);
        
    catch err
        fprintf('Error creating visualization maps for network %d: %s\n', net, err.message);
    end
end

%% Summary statistics
fprintf('\n=== MOTION GROUP ANALYSIS SUMMARY ===\n');
fprintf('Low Motion Adults: %d subjects\n', length(low_motion_adults));
fprintf('Low Motion Children: %d subjects\n', length(low_motion_children));
fprintf('High Motion Children: %d subjects\n', length(high_motion_children));
fprintf('Total subjects analyzed: %d\n', length(low_motion_adults) + length(low_motion_children) + length(high_motion_children));

fprintf('\nOutput files created for each network:\n');
fprintf('1. Individual assignment maps: Network{N}_Assignment_sub1973{###}{C/P}.dscalar.nii\n');
fprintf('2. Group overlap maps: Network{N}_{MotionGroup}_AssignmentOverlap.dscalar.nii\n');
fprintf('3. Pairwise difference maps: Network{N}_AssignmentOverlapDifference_{Group1}_Minus_{Group2}.dscalar.nii\n');
fprintf('4. Proportion maps: Network{N}_{MotionGroup}_AssignmentProportion.dscalar.nii\n');
fprintf('5. Winner-take-all maps: Network{N}_MotionGroupWinner_1LMA_2LMC_3HMC_Thresh0.2.dscalar.nii\n');

fprintf('\nMotion groups overlap analysis completed!\n');