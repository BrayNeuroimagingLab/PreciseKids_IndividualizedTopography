%Each vertex proportion of children and adults assigned to network,
%visualized as the absolute difference in dscalar maps
% Coming from EachVertex_ProportionAssignment.py which takes child minus adult proportion and outputs differences.txt

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

%Open averaged 
exemplaradults_map=ciftiopen('/Users/shefalirai/Desktop/Exemplar_Prckids/ExemplarAdults_groupaverage_winnertakeall_task-DORA_HCPAdultChild_overlap_Dice.dscalar.nii',wbcommand);
exemplaradults_mapdata=exemplaradults_map.cdata;

network_diff=readmatrix('/Users/shefalirai/Desktop/Exemplar_Prckids/group_consistency_map.txt');

%add zeros to 91282 vertices
network_diff_all=zeros(91282,1);
network_diff_all(1:59412,1)=network_diff(1:59412,1);

%Save
exemplaradults_map.cdata=network_diff_all;
ciftisavereset(exemplaradults_map, '/Users/shefalirai/Desktop/Exemplar_Prckids/Exemplar_TaskDifference_ConsistencyMap.dscalar.nii', wbcommand);
