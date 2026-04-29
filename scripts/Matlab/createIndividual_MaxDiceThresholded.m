function createIndividual_MaxDiceThresholded(inputDirNetwork, inputDirMaxDice, outputDir, maxDiceThreshold)
%
% This function creates individual subject network maps thresholded by their maxDice values.
% It only assigns a network when the maxDice value is above the threshold.
%
% INPUT:
% inputDirNetwork = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/';
% inputDirMaxDice = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/';
% outputDir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/';
% maxDiceThreshold = 0.3; 

% OUTPUT:
% Individual thresholded network maps for each subject

if nargin < 4
    maxDiceThreshold = 0.3;
end

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

% Get list of network assignment files
networkFiles = dir(fullfile(inputDirNetwork, '*alltasks_HCPAdultChild_overlap_Dice.dscalar.nii'));

% Get list of maxDice files
maxDiceFiles = dir(fullfile(inputDirMaxDice, '*alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_maxdice.dscalar.nii'));

% Keep track of processed subjects
processedCount = 0;
childCount = 0;
adultCount = 0;

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
    
    % Full paths to input files
    networkFilePath = fullfile(inputDirNetwork, networkFiles(i).name);
    maxDiceFilePath = fullfile(inputDirMaxDice, maxDiceFiles(maxDiceIdx).name);
    
    try
        % Open the network CIFTI file
        networkCifti = ciftiopen(networkFilePath, wbcommand);
        networkData = networkCifti.cdata;
        
        % Open the maxDice CIFTI file
        maxDiceCifti = ciftiopen(maxDiceFilePath, wbcommand);
        maxDiceData = maxDiceCifti.cdata;
        
        % Create thresholded network map
        thresholdedNetwork = networkData;
        thresholdedNetwork(maxDiceData < maxDiceThreshold) = 0; 
        
        networkCifti.cdata = thresholdedNetwork;
        
        if contains(networkFiles(i).name, 'C_')
            subjectType = 'Child';
            childCount = childCount + 1;
        elseif contains(networkFiles(i).name, 'P_')
            subjectType = 'Adult';
            adultCount = adultCount + 1;
        else
            subjectType = 'Unknown';
        end
        
        % Create output filename
        outputFilename = [char(subjectID) '_alltasks_HCPAdultChild_overlap_' num2str(maxDiceThreshold) 'thresh_Dice.dscalar.nii'];
        outputFilePath = fullfile(outputDir, outputFilename);
        
        % Save the thresholded network map
        ciftisavereset(networkCifti, outputFilePath, wbcommand);
        
        processedCount = processedCount + 1;
        disp(['Created thresholded network map for ' subjectType ' subject: ' char(subjectID)]);
        
    catch ME
        disp(['Error occurred while processing subject ' char(subjectID) ':']);
        disp(ME.message);
    end
end

disp(' ');
disp('Processing complete!');
disp(['Total subjects processed: ' num2str(processedCount)]);
disp(['Child subjects: ' num2str(childCount)]);
disp(['Adult subjects: ' num2str(adultCount)]);
disp(['MaxDice threshold used: ' num2str(maxDiceThreshold)]);
disp(['Output files saved to: ' outputDir]);

    end

