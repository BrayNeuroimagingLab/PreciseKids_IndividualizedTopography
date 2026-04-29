% Using the surface area and network assignment for each participant
%ALso use for the proportion difference maps
% to create surface area gradiation maps across all people (not averages)
%Sort of like a density difference map at the end of how frequently each vertex is part of the network across the two groups.


wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/surfacearea_gradiation/';

%Open averaged
sample1_childrenmap = ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii',wbcommand);
sample1_childrenmap_data = sample1_childrenmap.cdata;

eachsubC_surfacearea = cell(1,26);
eachsubC_network = cell(1,26);
eachsubP_surfacearea = cell(1,26);
eachsubP_network = cell(1,26);

% Network
networks = [1:3, 5, 7:16];


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

        eachsubC_surfacearea{sub} = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/LRcortex_indices_allsubjects_Sample1/sub-1973%sC_LRcortexvertices_surfacearea.txt', subnum));
        eachsubC_network{sub} = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/sub-1973%sC_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_Dice_networkvertices_extractions.txt', subnum));
        eachsubP_surfacearea{sub} = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/LRcortex_indices_allsubjects_Sample1/sub-1973%sP_LRcortexvertices_surfacearea.txt', subnum));
        eachsubP_network{sub} = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/sub-1973%sP_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_Dice_networkvertices_extractions.txt', subnum));
        

        for net = networks
            % Create maps for child
            networkC_map = NaN(size(eachsubC_surfacearea{sub}));
            networkC_map(eachsubC_network{sub} == net) = eachsubC_surfacearea{sub}(eachsubC_network{sub} == net);
            
            % Create full gradiation map for child
            fullC_gradiation = zeros(91282, 1);
            fullC_gradiation(1:59412) = networkC_map;
            
            % Save child network map
            sample1_childrenmap.cdata = fullC_gradiation;
            ciftisavereset(sample1_childrenmap, sprintf('%sNetwork%d_SA_Gradiation_sub1973%sC_Sample1_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net, subnum), wbcommand);
            
            % Create maps for parent
            networkP_map = NaN(size(eachsubP_surfacearea{sub}));
            networkP_map(eachsubP_network{sub} == net) = eachsubP_surfacearea{sub}(eachsubP_network{sub} == net);
            
            % Create full gradiation map for parent
            fullP_gradiation = zeros(91282, 1);
            fullP_gradiation(1:59412) = networkP_map;
            
            % Save parent network map
            sample1_childrenmap.cdata = fullP_gradiation;
            ciftisavereset(sample1_childrenmap, sprintf('%sNetwork%d_SA_Gradiation_sub1973%sP_Sample1_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net, subnum), wbcommand);
        end
        
    catch
        fprintf('Error: file does not exist for subject %d\n', sub);
    end
end


%% Save overlap of all children and adults gradiation map per network
wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkgradiation/';

% Load template cifti
template_map = ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii', wbcommand);

% Networks
networks = [1:3, 5, 7:16];


for net = networks
    % Initialize coverage maps for this network
    network_children_count = zeros(91282, 1);
    network_adults_count = zeros(91282, 1);
    
    % Process each subject
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
            % Load children's map
            child_map = ciftiopen(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkgradiation/Network%d_SA_Gradiation_sub1973%sC_Sample1_HCPAdultChild_overlap_14networks.dscalar.nii', net, subnum), wbcommand);
            child_data = child_map.cdata;
            
            % Add to children's count where values exist (not NaN)
            network_children_count(~isnan(child_data)) = network_children_count(~isnan(child_data)) + 1;
            
            % Load adults' map
            adult_map = ciftiopen(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkgradiation/Network%d_SA_Gradiation_sub1973%sP_Sample1_HCPAdultChild_overlap_14networks.dscalar.nii', net, subnum), wbcommand);
            adult_data = adult_map.cdata;
            
            % Add to adults' count where values exist (not NaN)
            network_adults_count(~isnan(adult_data)) = network_adults_count(~isnan(adult_data)) + 1;
            
        catch
            fprintf('Error: Could not process subject %s for network %d\n', subnum, net);
        end
    end
    
    % Save network-specific children's coverage map
    template_map.cdata = network_children_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_allchildren_Gradiation_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net), wbcommand);
    
    % Save network-specific adults' coverage map
    template_map.cdata = network_adults_count;
    ciftisavereset(template_map, sprintf('%sNetwork%d_alladults_Gradiation_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net), wbcommand);
end


%% Save difference of overlap between adult and children gradiation maps

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkgradiation/';

% Load template cifti
template_map = ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii', wbcommand);

% Networks 
networks = [1:3, 5, 7:16];


for net = networks
    try
        % Load adult and children gradiation maps
        adult_map = ciftiopen(sprintf('%sNetwork%d_alladults_Gradiation_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net), wbcommand);
        child_map = ciftiopen(sprintf('%sNetwork%d_allchildren_Gradiation_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net), wbcommand);
        
        % Calculate difference (adults - children)
        difference_map = adult_map.cdata - child_map.cdata;
        
        % Save difference map
        template_map.cdata = difference_map;
        ciftisavereset(template_map, sprintf('%sNetwork%d_gradiation_difference_HCPAdultChild_overlap_14networks.dscalar.nii', output_dir, net), wbcommand);
        
        fprintf('Successfully processed network %d\n', net);
        
    catch err
        fprintf('Error processing network %d: %s\n', net, err.message);
    end
end



