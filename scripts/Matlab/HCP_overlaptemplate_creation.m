% Script to create overlap-only templates between Dworetsky HCP and HCP 8-9 year olds templates'

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

input_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/HCPtemplate_comparisons';
output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/HCPtemplate_overlap';

% Create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Define which networks to process (skipping 4 and 6)
networks_to_process = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

% Process each network
for i = 1:length(networks_to_process)
    network = networks_to_process(i);
    
    % Load the comparison file
    comparison_file = sprintf('%s/network%d_comparison.dscalar.nii', input_dir, network);
    comparison_dscalar = ciftiopen(comparison_file, wbcommand);
    comparison_data = comparison_dscalar.cdata;
    
    % Create binary overlap map (1 where value is 3, 0 elsewhere)
    overlap_map = zeros(size(comparison_data));
    overlap_map(comparison_data == 3) = 1; 
    
    % Save the overlap map
    output_dscalar = comparison_dscalar; 
    output_dscalar.cdata = overlap_map;
    output_file = sprintf('%s/network%d_overlap.dscalar.nii', output_dir, network);
    ciftisavereset(output_dscalar, output_file, wbcommand);
    
    fprintf('Network %d overlap map created and saved.\n', network);
end

