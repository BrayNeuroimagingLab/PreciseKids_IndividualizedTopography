% Set the variables needed for the rest of the process
wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

% Initialize a counter to store data in the right positions
data_index = 1;

% Open network files, skipping networks 4 and 6
dscalar_data = cell(1, 14); % Reduced to 14 since we're skipping 2 networks
for network = 1:16
    % Skip networks 4 and 6
    if network == 4 || network == 6
        continue;
    end
    
    % Load the current network file
    dscalar = ciftiopen(sprintf('/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/dworetsky-hcp_Dworetsky-HCP-network%d_network_probability_91282vertices_0.2thresholded.dscalar.nii', network), wbcommand);
    dscalar_data{data_index} = dscalar.cdata;
    
    % Store the first dscalar object to use for saving later
    if data_index == 1
        dscalar_template = dscalar;
    end
    
    % Increment counter
    data_index = data_index + 1;
end

% Initialize combined data with zeros (same size as first dscalar)
combined_data = zeros(size(dscalar_data{1}));

% Add all dscalar data arrays (excluding networks 4 and 6)
for i = 1:length(dscalar_data)
    combined_data = combined_data + dscalar_data{i};
end

% Save the combined data using the template dscalar
dscalar_template.cdata = combined_data;
ciftisavereset(dscalar_template, '/Users/shefalirai/Desktop/PK_networkassignment/HCP_DlabelTemplate/dworetsky-hcp_Dworetsky-HCP-combinednetworks_network_probability_91282vertices_0.2thresholded..dscalar.nii', wbcommand);

