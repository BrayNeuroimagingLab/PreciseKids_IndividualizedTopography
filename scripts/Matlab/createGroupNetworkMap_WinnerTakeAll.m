function createGroupNetworkMap_WinnerTakeAll(inputDir, outputDir)
%
% This function creates group average network maps for child and adult group using MODE
% "winner take all" approach is just using mode function from individual subject network maps.
%
% INPUT:
% inputDir: directory containing the individual subject .dscalar.nii files
% (can do either the 14 network or 15 network SCAN inputDIR)
%
% outputDir: directory where the output group average maps will be saved
%
% OUTPUT:
% Two .dscalar.nii files: one for the child group average and one for the adult group average
%
% Required external functions: ft_read_cifti_mod, ft_write_cifti_mod

% % Get list of all .dscalar.nii files in the input directory
% inputDir = '/Users/shefalirai/Desktop/PK_networkassignment/';
% OR inputDir = '/Users/shefalirai/Desktop/PK_networkassignment/Networkassignment_withSCAN/'
%
% outputDir = '/Users/shefalirai/Desktop/PK_networkassignment/';
%
%
% If getting an Invalid MEX-file issue, add "Utilities" folder and subfolders to path

files = dir(fullfile(inputDir, '*_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii'));
%files = dir(fullfile(inputDir, '*_task-YT_HCPAdultChild_overlap_Exemplar_Dice.dscalar.nii'));


% Initialize variables to store group data
childData = [];
adultData = [];
templateCifti = [];

% Process each file
for i = 1:length(files)
    % Read the CIFTI file
    cifti = ft_read_cifti_mod(fullfile(inputDir, files(i).name));
    
    % Store the first cifti structure as a template
    if isempty(templateCifti)
        templateCifti = cifti;
    end
    
    % Determine if the subject is a child or adult
    if contains(files(i).name, 'C_')
        childData = cat(2, childData, cifti.data);
    elseif contains(files(i).name, 'P_')
        adultData = cat(2, adultData, cifti.data);
    end
end

% Create group average maps using "winner take all" approach
childAvg = mode(childData, 2);
adultAvg = mode(adultData, 2);

% Prepare output CIFTI structures
childOut = templateCifti;
childOut.data = childAvg;
childOut.dimord = 'scalar_pos';
childOut.mapname = {'Child Group Average Network Map'};
if isfield(childOut, 'datalabel')
    childOut.datalabel = childOut.mapname;
end

adultOut = templateCifti;
adultOut.data = adultAvg;
adultOut.dimord = 'scalar_pos';
adultOut.mapname = {'Adult Group Average Network Map'};
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
    ft_write_cifti_mod(fullfile(outputDir, 'Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii'), childOut);
    ft_write_cifti_mod(fullfile(outputDir, 'Alladults_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii'), adultOut);
    disp('Group average network maps have been created successfully.');
catch ME
    disp('Error occurred while writing CIFTI files:');
    disp(ME.message);
    disp('Stack trace:');
    disp(ME.stack);
end

end