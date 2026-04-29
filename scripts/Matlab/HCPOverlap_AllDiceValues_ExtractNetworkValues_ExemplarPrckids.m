% This is used for VertexwiseR TFCE package comparing dice, as we need a range of Dice values rather than binary which would be more appropriate for logistic regression


wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
baseDir = '/Users/shefalirai/Desktop/Exemplar_Prckids/';

%List of my exemplar 8 adults
adults = {};
for i = [2,6,7,10,11,16,21,23]
    adults{end+1} = sprintf('%03dP', i);
end

% Define the tasks and the subs
tasks = {'task-DORA', 'task-RX', 'task-YT'};
all_subjects = [adults];

for t = 1:length(tasks)
    task_id = tasks{t};
    for s = 1:length(all_subjects)
        subject_id = all_subjects{s};

       inputFile = fullfile(baseDir, ['sub-1973' subject_id '_' task_id '_HCPAdultChild_overlap_14networkassignment_Vertexwise_Exemplar_alldicevalues.dscalar.nii']);

        if exist(inputFile, 'file')
            fprintf('Processing subject %s\n', subject_id);
            
            dscalar = ciftiopen(inputFile, wbcommand);
            dscalar_data = dscalar.cdata;

            for network = 1:16
                dscalar.cdata = dscalar_data(:, network);
                outputFile = [baseDir, 'sub-1973', subject_id, task_id, '_HCPAdultChild_overlap_14networkassignment_Vertexwise_Exemplar_alldicevalues_network', num2str(network), '.dscalar.nii'];
                ciftisavereset(dscalar, outputFile, wbcommand);
                fprintf('  Saved network %d\n', network);
            end
        else
            fprintf('Warning: File not found for subject %s\n', subject_id);
        end
    end
end

fprintf('Processing complete!\n');

