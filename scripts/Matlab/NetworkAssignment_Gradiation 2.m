%% Setup
wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkassignment_gradiation/';
template_file = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii';
template_map = ciftiopen(template_file, wbcommand);

% List of networks to process
networks = [1:3, 5, 7:16];

%% Save individual binary assignment maps
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
            % CHILD
            binmap = zeros(91282, 1);
            binmap(1:59412) = double(child_net == net);
            template_map.cdata = binmap;
            ciftisavereset(template_map, sprintf('%sNetwork%d_Assignment_sub1973%sC.dscalar.nii', output_dir, net, subnum), wbcommand);

            % PARENT
            binmap = zeros(91282, 1);
            binmap(1:59412) = double(parent_net == net);
            template_map.cdata = binmap;
            ciftisavereset(template_map, sprintf('%sNetwork%d_Assignment_sub1973%sP.dscalar.nii', output_dir, net, subnum), wbcommand);
        end

    catch
        fprintf('Error: file does not exist or failed for subject %s\n', subnum);
    end
end

%% Compute group overlap (number of subjects with assignment) per vertex
for net = networks
    network_children_count = zeros(91282, 1);
    network_adults_count = zeros(91282, 1);

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
            % CHILD
            child_map = ciftiopen(sprintf('%sNetwork%d_Assignment_sub1973%sC.dscalar.nii', output_dir, net, subnum), wbcommand);
            network_children_count = network_children_count + double(child_map.cdata == 1);

            % ADULT
            adult_map = ciftiopen(sprintf('%sNetwork%d_Assignment_sub1973%sP.dscalar.nii', output_dir, net, subnum), wbcommand);
            network_adults_count = network_adults_count + double(adult_map.cdata == 1);

        catch
            fprintf('Error: overlap failed for subject %s, network %d\n', subnum, net);
        end
    end

    % Save group overlap maps
    template_map.cdata = network_children_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_allchildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);

    template_map.cdata = network_adults_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_alladults_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
end

%% Compute difference map (Adults – Children)
for net = networks
    try
        adult_map = ciftiopen(sprintf('%sNetwork%d_alladults_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
        child_map = ciftiopen(sprintf('%sNetwork%d_allchildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);

        diffmap = adult_map.cdata - child_map.cdata;
        template_map.cdata = diffmap;

        ciftisavereset(template_map, sprintf('%sNetwork%d_AssignmentOverlapDifference_AdultMinusChild.dscalar.nii', output_dir, net), wbcommand);
        fprintf('Saved difference map for network %d\n', net);
    catch err
        fprintf('Error processing network %d: %s\n', net, err.message);
    end
end


%% Compute porportion difference maps (Children-Adults)

for net = networks
    try

        n_children_used = 0;
        n_adults_used   = 0;

        for sub = 2:26
            if sub == 3, continue; end
            if sub < 10, subnum = sprintf('00%d', sub); else, subnum = sprintf('0%d', sub); end

            child_file = sprintf('%sNetwork%d_Assignment_sub1973%sC.dscalar.nii', output_dir, net, subnum);
            adult_file = sprintf('%sNetwork%d_Assignment_sub1973%sP.dscalar.nii', output_dir, net, subnum);

            if exist(child_file, 'file') == 2
                % Subject is included for denominator even if their map is all zeros for this network
                n_children_used = n_children_used + 1;
            end
            if exist(adult_file, 'file') == 2
                n_adults_used = n_adults_used + 1;
            end
        end


        child_count_map = ciftiopen(sprintf('%sNetwork%d_allchildren_AssignmentOverlap.dscalar.nii', output_dir, net), wbcommand);
        adult_count_map = ciftiopen(sprintf('%sNetwork%d_alladults_AssignmentOverlap.dscalar.nii',  output_dir, net), wbcommand);

        if n_children_used == 0
            error('No children maps found for network %d', net);
        end
        if n_adults_used == 0
            error('No adult maps found for network %d', net);
        end

        child_prop = double(child_count_map.cdata) / n_children_used;
        adult_prop = double(adult_count_map.cdata) / n_adults_used;

        % Save group PROPORTION maps
        template_map.cdata = child_prop;
        ciftisavereset(template_map, sprintf('%sNetwork%d_allchildren_AssignmentProportion.dscalar.nii', output_dir, net), wbcommand);

        template_map.cdata = adult_prop;
        ciftisavereset(template_map, sprintf('%sNetwork%d_alladults_AssignmentProportion.dscalar.nii',  output_dir, net), wbcommand);

        % Save PROPORTION difference (Children – Adults)
        prop_diff = child_prop - adult_prop;
        template_map.cdata = prop_diff;
        ciftisavereset(template_map, sprintf('%sNetwork%d_AssignmentProportionDifference_ChildMinusAdult.dscalar.nii', output_dir, net), wbcommand);
    catch err
        fprintf('Error processing network %d: %s\n', net, err.message);
    end
end


