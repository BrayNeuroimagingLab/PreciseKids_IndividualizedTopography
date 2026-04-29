function createGroup_MaxDiceWinnerTakeAll_Threshold(inputDirNetwork, inputDirMaxDice, outputDir, maxDiceThreshold)
%
% This function creates group average network maps for child and adult groups
% combining MODE "winner take all" approach with maxDice thresholding.
% It only assigns a network (from mode) when the maxDice value is above the threshold.
%
% INPUT:
% inputDirNetwork: directory containing the individual subject network assignment files
% inputDirMaxDice: directory containing the individual subject maxDice files
% outputDir: directory where the output combined maps will be saved
% maxDiceThreshold: threshold for maxDice values (default: 0.3)
%
% OUTPUT:
% Two .dscalar.nii files: one for the child group and one for the adult group
%
% Required external functions: ft_read_cifti_mod, ft_write_cifti_mod

% Set default threshold if not provided
if nargin < 4
    maxDiceThreshold = 0.3;
end

% Get list of network assignment files
networkFiles = dir(fullfile(inputDirNetwork, '*alltasks_HCPAdultChild_overlap_Dice.dscalar.nii'));

% Get list of maxDice files
maxDiceFiles = dir(fullfile(inputDirMaxDice, '*alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_maxdice.dscalar.nii'));

% Initialize variables to store group data
childNetworkData = [];
adultNetworkData = [];
childMaxDiceData = [];
adultMaxDiceData = [];
templateCifti = [];

% Process each network assignment file
for i = 1:length(networkFiles)
    % Extract subject ID from filename
    [~, networkFileName, ~] = fileparts(networkFiles(i).name);
    subjectID = extractBetween(networkFileName, 1, 12); 
    
    % Find corresponding maxDice file
    maxDiceIdx = find(contains({maxDiceFiles.name}, subjectID));
    
    if isempty(maxDiceIdx)
        warning(['No matching maxDice file found for subject ' char(subjectID) '. Skipping this subject.']);
        continue;
    end
    
    % Read the network CIFTI file
    networkCifti = ft_read_cifti_mod(fullfile(inputDirNetwork, networkFiles(i).name));
    
    % Read the maxDice CIFTI file
    maxDiceCifti = ft_read_cifti_mod(fullfile(inputDirMaxDice, maxDiceFiles(maxDiceIdx).name));
    
    % Store the first cifti structure as a template
    if isempty(templateCifti)
        templateCifti = networkCifti;
    end
    
    % Determine if the subject is a child or adult
    if contains(networkFiles(i).name, 'C_')
        childNetworkData = cat(2, childNetworkData, networkCifti.data);
        childMaxDiceData = cat(2, childMaxDiceData, maxDiceCifti.data);
    elseif contains(networkFiles(i).name, 'P_')
        adultNetworkData = cat(2, adultNetworkData, networkCifti.data);
        adultMaxDiceData = cat(2, adultMaxDiceData, maxDiceCifti.data);
    end
end

% Calculate median maxDice values for each group
childMaxDiceAvg = median(childMaxDiceData, 2);
adultMaxDiceAvg = median(adultMaxDiceData, 2);

% Calculate mode of network assignments for each group
childNetworkAvg = mode(childNetworkData, 2);
adultNetworkAvg = mode(adultNetworkData, 2);

% Apply maxDice threshold to network assignments
childCombined = childNetworkAvg;
childCombined(childMaxDiceAvg < maxDiceThreshold) = 0; 

adultCombined = adultNetworkAvg;
adultCombined(adultMaxDiceAvg < maxDiceThreshold) = 0; 

% Prepare output CIFTI structures
childOut = templateCifti;
childOut.data = childCombined;
childOut.dimord = 'scalar_pos';
childOut.mapname = {['Child Group Combined Network Map (MaxDice Threshold ' num2str(maxDiceThreshold) ')']};
if isfield(childOut, 'datalabel')
    childOut.datalabel = childOut.mapname;
end

adultOut = templateCifti;
adultOut.data = adultCombined;
adultOut.dimord = 'scalar_pos';
adultOut.mapname = {['Adult Group Combined Network Map (MaxDice Threshold ' num2str(maxDiceThreshold) ')']};
if isfield(adultOut, 'datalabel')
    adultOut.datalabel = adultOut.mapname;
end

% Ensure other necessary fields are present and correctly formatted
fields_to_check = {'hdr', 'brainstructure', 'brainstructurelabel', 'pos', 'transform'};
for field = fields_to_check
    if ~isfield(childOut, field{1}) || isempty(childOut.(field{1}))
        warning(['Field ' field{1} ' is missing or empty in the CIFTI structure. The output file may not be complete.']);
    end
end

% Write output files
try
    ft_write_cifti_mod(fullfile(outputDir, ['Allchildren_combined_winnertakeall_maxdice' num2str(maxDiceThreshold) '_alltasks_HCPAdultChild_overlap_14network.dscalar.nii']), childOut);
    ft_write_cifti_mod(fullfile(outputDir, ['Alladults_combined_winnertakeall_maxdice' num2str(maxDiceThreshold) '_alltasks_HCPAdultChild_overlap_14network.dscalar.nii']), adultOut);
    disp(['Combined network maps with maxDice threshold of ' num2str(maxDiceThreshold) ' have been created successfully.']);
catch ME
    disp('Error occurred while writing CIFTI files:');
    disp(ME.message);
    disp('Stack trace:');
    disp(ME.stack);
end

% Also save the maxDice maps for reference
childMaxDiceOut = templateCifti;
childMaxDiceOut.data = childMaxDiceAvg;
childMaxDiceOut.dimord = 'scalar_pos';
childMaxDiceOut.mapname = {'Child Group MaxDice Map'};
if isfield(childMaxDiceOut, 'datalabel')
    childMaxDiceOut.datalabel = childMaxDiceOut.mapname;
end

adultMaxDiceOut = templateCifti;
adultMaxDiceOut.data = adultMaxDiceAvg;
adultMaxDiceOut.dimord = 'scalar_pos';
adultMaxDiceOut.mapname = {'Adult Group MaxDice Map'};
if isfield(adultMaxDiceOut, 'datalabel')
    adultMaxDiceOut.datalabel = adultMaxDiceOut.mapname;
end

try
    ft_write_cifti_mod(fullfile(outputDir, 'Allchildren_groupaverage_maxdice_alltasks_HCPAdultChild_overlap_14network.dscalar.nii'), childMaxDiceOut);
    ft_write_cifti_mod(fullfile(outputDir, 'Alladults_groupaverage_maxdice_alltasks_HCPAdultChild_overlap_14network.dscalar.nii'), adultMaxDiceOut);
    disp('Group average maxDice maps have been created successfully.');
catch ME
    disp('Error occurred while writing maxDice CIFTI files:');
    disp(ME.message);
    disp('Stack trace:');
    disp(ME.stack);
end
end