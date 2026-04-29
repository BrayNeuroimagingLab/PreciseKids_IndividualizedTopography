%Each vertex proportion of children and adults assigned to network,
%visualized as the absolute difference in dscalar maps
% Coming from EachVertex_ProportionAssignment.py which takes child minus adult proportion and outputs differences.txt

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

% Open averaged map
groupaverage_map = ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Alladults_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii', wbcommand);
groupaverage_mapdata = groupaverage_map.cdata;

for networks =1:16
    if networks == 4 || networks ==6
        continue
    end
    network_diff_file = sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/network_%d_differences.txt', networks);
    network_diff = readmatrix(network_diff_file);
    network_diff_all = zeros(91282, 1);
    network_diff_all(1:59412, 1) = network_diff(1:59412, 4);
    groupaverage_map.cdata=single(network_diff_all);
    ciftisavereset(groupaverage_map, sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Network%d_difference.dscalar.nii', networks), wbcommand);
end
