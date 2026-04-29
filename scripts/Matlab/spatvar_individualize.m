function spatialvariants = spatvar_individualize(subject, task, thresh)
%subject is either 'C' or 'P' depending on if you are running on child or parent 
%Thresh is 10 for 0.1
%Average spatial variants thresholded maps from ARC across all children
%into 1 averaged output

% Step1:
% Do this for all dora, yt and rx first, load all spatial variants for both C and P
% rxP_spatvar=spatvar_individualize('P', 'task-RX', 10);
% doraP_spatvar=spatvar_individualize('P', 'task-DORA', 10);
% ytP_spatvar=spatvar_individualize('P', 'task-YT', 10);
% rxC_spatvar=spatvar_individualize('C', 'task-RX', 10);
%
%Step 2: Uncomment and average all dora, yt, rx together for C and P
% Step 3: manually delete column 1 and 3 for both variables


%% Open all C and P spatial variants

wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
%open each individual spatial variant
for sub=2:26
        if sub >=10
            try
                spatialvariants{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_spatialcorr/sub-19730%d%s_%s_spatialVariants_thresh%d.dtseries.nii', sub, subject, task, thresh)),wbcommand);
                spatialvariants{sub}=spatialvariants{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        elseif sub <10
            try
                spatialvariants{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_spatialcorr/sub-197300%d%s_%s_spatialVariants_thresh%d.dtseries.nii', sub, subject, task, thresh)),wbcommand);
                spatialvariants{sub}=spatialvariants{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        else
            try
                spatialvariants{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_spatialcorr/sub-1973%d%s_%s_spatialVariants_thresh%d.dtseries.nii', sub, subject, task, thresh)),wbcommand);
                spatialvariants{sub}=spatialvariants{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        end
end

%% Average across all tasks for each group

% Initialize the output cell arrays for both tasks
alltasksC_spatvar = cell(1, 26);
alltasksP_spatvar = cell(1, 26);

% Loop through each child and parent
for i = 1:26
    % Extract data for the i-th child 
    doraC_data = doraC_spatvar{i};
    ytC_data = ytC_spatvar{i};
    rxC_data = rxC_spatvar{i};
    
    % Extract data for the i-th parent
    doraP_data = doraP_spatvar{i};
    ytP_data = ytP_spatvar{i};
    rxP_data = rxP_spatvar{i};
    
    % Check if any of the data arrays are empty for task C
    if isempty(doraC_data) || isempty(ytC_data) || isempty(rxC_data)
        % Skip 
        continue;
    end
    
    % Check if any of the data arrays are empty for task P
    if isempty(doraP_data) || isempty(ytP_data) || isempty(rxP_data)
        % Skip
        continue;
    end
    
    % Calculate the average across the three tasks for task C
    averaged_data_C = (doraC_data + ytC_data + rxC_data) / 3;
    
    % Calculate the average across the three tasks for task P
    averaged_data_P = (doraP_data + ytP_data + rxP_data) / 3;
    
    % Store the averaged data in the output cell arrays
    alltasksC_spatvar{i} = averaged_data_C;
    alltasksP_spatvar{i} = averaged_data_P;
end



%% Manually delete column 1 and 3



%% Indivualization code 





end


