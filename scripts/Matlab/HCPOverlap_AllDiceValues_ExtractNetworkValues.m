% This is used for VertexwiseR TFCE package comparing dice, as we need a range of Dice values rather than binary which would be more appropriate for logistic regression


wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
baseDir = '/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/HCPOverlap_AllDiceValues/';


adults = {};
for i = 2:26
    adults{end+1} = sprintf('%03dC', i);
end

children = {};
for i = 2:26
    children{end+1} = sprintf('%03dP', i);
end

all_subjects = [adults, children];

for s = 1:length(all_subjects)
    subject_id = all_subjects{s};

    inputFile = [baseDir, 'sub-1973', subject_id, '_alltasks_HCPAdultChild_overlap_allnetworks_alldicevalues.dscalar.nii'];

    if exist(inputFile, 'file')
        fprintf('Processing subject %s\n', subject_id);
        

        dscalar = ciftiopen(inputFile, wbcommand);
        dscalar_data = dscalar.cdata;

        for network = 1:16
            dscalar.cdata = dscalar_data(:, network);
            outputFile = [baseDir, 'sub-1973', subject_id, '_alltasks_HCPAdultChild_overlap_allnetworks_alldicevalues_network', num2str(network), '.dscalar.nii'];
            ciftisavereset(dscalar, outputFile, wbcommand);
            fprintf('  Saved network %d\n', network);
        end
    else
        fprintf('Warning: File not found for subject %s\n', subject_id);
    end
end

fprintf('Processing complete!\n');

