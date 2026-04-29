wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

% Open averaged
sample1_childrenmap = ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/Allchildren_groupaverage_winnertakeall_networkmap_sample1_matchedconditions.dscalar.nii', wbcommand);
sample1_childrenmap_data = sample1_childrenmap.cdata;

% Define networks to process (excluding 4 and 6)
networks = [1:3, 5, 7:14];

% Process C (Children) files
for net = networks
    % Read the network overlap file
    network_diff = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/NetworkOverlap/network_%d_C_overlap.txt', net));
    
    % Save the results
    sample1_childrenmap.cdata = network_diff;
    output_filename = sprintf('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/NetworkOverlap/Network%d_Children_OverlapNumbers.dscalar.nii', net);
    ciftisavereset(sample1_childrenmap, output_filename, wbcommand);
end

% Process P (Parent) files
for net = networks
    % Read the network overlap file
    network_diff = readmatrix(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/NetworkOverlap/network_%d_P_overlap.txt', net));
    
    % Save the results
    sample1_childrenmap.cdata = network_diff;
    output_filename = sprintf('/Users/shefalirai/Desktop/PK_networkassignment/RandomSample_MatchedConditions_NetworkAssignments/NetworkOverlap/Network%d_Parent_OverlapNumbers.dscalar.nii', net);
    ciftisavereset(sample1_childrenmap, output_filename, wbcommand);
end

