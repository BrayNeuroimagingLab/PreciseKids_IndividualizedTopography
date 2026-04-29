% Script to compare networks between Dworetsky HCP and HCP 8-9 year olds templates

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

dworetsky_base = '/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/dworetsky-hcp_Dworetsky-HCP-network';
child_base = '/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/hcp-d_ages08-09_hcp-d_10minute_ages08-09_network';

% Define which networks to process (skipping 4 and 6)
networks_to_process = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

% Create output directory if it doesn't exist
output_dir = '/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/HCPtemplate_comparisons';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Process each network pair
for i = 1:length(networks_to_process)
    network = networks_to_process(i);
    
    % Load adult network file
    adult_file = sprintf('%s%d_network_probability_91282vertices_0.2thresholded.dscalar.nii', dworetsky_base, network);
    adult_dscalar = ciftiopen(adult_file, wbcommand);
    adult_data = adult_dscalar.cdata;
    
    % Load child network file
    child_file = sprintf('%s%d_network_probability_0.2thresholded.dscalar.nii', child_base, network);
    child_dscalar = ciftiopen(child_file, wbcommand);
    child_data = child_dscalar.cdata;
    
    % Binarize both datasets (threshold already applied in filenames)
    adult_binary = adult_data > 0;
    child_binary = child_data > 0;
    
    comparison_map = zeros(size(adult_binary));
    comparison_map(adult_binary & ~child_binary) = 1;  % Adult only
    comparison_map(~adult_binary & child_binary) = 2;  % Child only
    comparison_map(adult_binary & child_binary) = 3;   % Both
    
    % Save the comparison map
    output_dscalar = adult_dscalar; % Use as template
    output_dscalar.cdata = comparison_map;
    output_file = sprintf('%s/network%d_comparison.dscalar.nii', output_dir, network);
    ciftisavereset(output_dscalar, output_file, wbcommand);
    
    % Calculate overlap statistics
    total_adult_vertices = sum(adult_binary);
    total_child_vertices = sum(child_binary);
    overlap_vertices = sum(adult_binary & child_binary);
    
    adult_only_vertices = sum(adult_binary & ~child_binary);
    child_only_vertices = sum(~adult_binary & child_binary);
    
    dice_coefficient = (2 * overlap_vertices) / (total_adult_vertices + total_child_vertices);
    
    % Store statistics in a structure for later reporting
    stats(i).network = network;
    stats(i).adult_vertices = total_adult_vertices;
    stats(i).child_vertices = total_child_vertices;
    stats(i).overlap_vertices = overlap_vertices;
    stats(i).adult_only_vertices = adult_only_vertices;
    stats(i).child_only_vertices = child_only_vertices;
    stats(i).dice_coefficient = dice_coefficient;
    stats(i).percent_overlap_of_adult = (overlap_vertices / total_adult_vertices) * 100;
    stats(i).percent_overlap_of_child = (overlap_vertices / total_child_vertices) * 100;
    
    fprintf('Network %d comparison complete.\n', network);
end


% Bar plot of Dice coefficients
bar([stats.dice_coefficient]);
xticks(1:length(stats));
xticklabels(arrayfun(@num2str, [stats.network], 'UniformOutput', false));
xlabel('Network');
ylabel('Dice Coefficient');
title('Network Overlap (Dice Coefficient)');
grid on;
