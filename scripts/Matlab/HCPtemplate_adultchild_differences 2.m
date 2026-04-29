% Script to compute non-overlapping regions between adult and child templates for each network
% and assign the network number to those vertices (final combined map)

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

dworetsky_base = '/Users/shefalirai/Desktop/PK_networkassignment/OriginalHCP_DlabelTemplate/dworetsky-hcp_Dworetsky-HCP-network';
child_base = '/Users/shefalirai/Desktop/PK_networkassignment/OriginalHCP_DlabelTemplate/hcp-d_ages08-09_hcp-d_10minute_ages08-09_network';

% Define networks to include in final difference map
networks_to_process = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

% Initialize combined difference map
template_file = sprintf('%s%d_network_probability_91282vertices_0.2thresholded.dscalar.nii', dworetsky_base, networks_to_process(1));
template_dscalar = ciftiopen(template_file, wbcommand);
combined_map = zeros(size(template_dscalar.cdata));

% Process each network
for i = 1:length(networks_to_process)
    network = networks_to_process(i);
    
    adult_file = sprintf('%s%d_network_probability_91282vertices_0.2thresholded.dscalar.nii', dworetsky_base, network);
    child_file = sprintf('%s%d_network_probability_0.2thresholded.dscalar.nii', child_base, network);
    
    adult_data = ciftiopen(adult_file, wbcommand).cdata > 0;
    child_data = ciftiopen(child_file, wbcommand).cdata > 0;
    
    % Non-overlapping vertices (present in only one of adult/child)
    difference_mask = xor(adult_data, child_data);
    
    % Assign network number to those vertices in combined map
    combined_map(difference_mask) = network;
    
    fprintf('Processed network %d\n', network);
end

% Save the combined difference map
template_dscalar.cdata = combined_map;
output_file = '/Users/shefalirai/Desktop/PK_networkassignment/OriginalHCP_DlabelTemplate/hcp-d_dworetskyHCP_AllNetwork_Differences.dscalar.nii';
ciftisavereset(template_dscalar, output_file, wbcommand);

fprintf('Saved combined difference map: %s\n', output_file);
