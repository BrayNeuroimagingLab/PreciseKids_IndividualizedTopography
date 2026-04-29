%% Matched censoring across all tasks and all participants for network assignment 
% This script creates the Sample 1 data needed for creating network maps


wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

% Assume each session contributes an equal number of volumes 
columns_per_session = 410;
tasks = {'task-DORA', 'task-RX', 'task-YT'};


%% Open dtseries uncensored each task files

% Loop through each task
for t = 1:length(tasks)
    task = tasks{t};

    % Load and split the child data for each task
    subject = 'C';
    dtseries_C_sessions = cell(26, 4); % 26 subjects x 4 sessions
    for sub = 2:26
        if sub == 3
            continue; % Skip subject 03
        end
        % Construct file path
        file_path = sprintf('/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/sub-19730%02d%s_%s_allsessions.dtseries.nii', sub, subject, task);

        try
            % Load data
            data = ciftiopen(file_path, wbcommand);
            data = data.cdata; % Extract cdata

            % Split data into sessions
            for ses = 1:4
                start_col = (ses - 1) * columns_per_session + 1;
                end_col = ses * columns_per_session;
                dtseries_C_sessions{sub, ses} = data(:, start_col:end_col);
            end
        catch
            fprintf('Error: file does not exist for subject %d\n', sub);
        end
    end
    assignin('base', sprintf('dtseries_C_sessions_%s', task(6:end)), dtseries_C_sessions);

    % Load and split the parent data for each task
    subject = 'P';
    dtseries_P_sessions = cell(26, 4); % 26 subjects x 4 sessions
    for sub = 2:26
        if sub == 3
            continue; % Skip subject 03
        end
        % Construct file path
        file_path = sprintf('/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/sub-19730%02d%s_%s_allsessions.dtseries.nii', sub, subject, task);

        try
            % Load data
            data = ciftiopen(file_path, wbcommand);
            data = data.cdata; % Extract cdata

            % Split data into sessions
            for ses = 1:4
                start_col = (ses - 1) * columns_per_session + 1;
                end_col = ses * columns_per_session;
                dtseries_P_sessions{sub, ses} = data(:, start_col:end_col);
            end
        catch
            fprintf('Error: file does not exist for subject %d\n', sub);
        end
    end
    assignin('base', sprintf('dtseries_P_sessions_%s', task(6:end)), dtseries_P_sessions);
end



%% Find maximum censoring across all subs and tasks 

% Define parameters
subjects = {};
for i = 2:26
    if i == 3
        continue; % Skip subject 03
    end
    subjects{end+1} = sprintf('19730%02dC', i);
    subjects{end+1} = sprintf('19730%02dP', i);
end
sessions = {'ses-1', 'ses-2', 'ses-3', 'ses-4'};
tasks = {'DORA', 'RX', 'YT'};
sub_tasks = {'1', '2'};
fd_threshold = 0.15;

% Initialize variables to track maximum
max_by_task = containers.Map(tasks, zeros(1, numel(tasks)));
% Create a cell array to store all motion info
all_motion_info = {};

% Process each subject
for i = 1:numel(subjects)
    subject = subjects{i};
    for k = 1:numel(tasks)
        task = tasks{k};
        all_volumes = [];
        total_volumes = 0;

        % Adjust sessions for subject 24P
        if strcmp(subject, '1973024P')
            current_sessions = {'ses-1', 'ses-2', 'ses-3', 'ses-6'};
        else
            current_sessions = sessions;
        end

        % Process each session and sub-task
        for j = 1:numel(current_sessions)
            session = current_sessions{j};
            for l = 1:numel(sub_tasks)
                sub_task = sub_tasks{l};
                csv_path = fullfile('/Volumes/Prckids', ['sub-' subject], session, 'func', ...
                    sprintf('sub-%s_%s_task-%s%s_echo-2_PowerFDFlt.csv', subject, session, task, sub_task));
                try
                    fd_data = readtable(csv_path);
                    high_motion_vols = find(fd_data.FD > fd_threshold);
                    all_volumes = [all_volumes; high_motion_vols + total_volumes];
                    total_volumes = total_volumes + height(fd_data);
                catch
                    warning('Unable to read file: %s', csv_path);
                end
            end
        end

        % Count unique high motion volumes
        num_censored = numel(unique(all_volumes));
        
        % Store motion info for this subject and task
        motion_info = struct();
        motion_info.subject = subject;
        motion_info.task = task;
        motion_info.count = num_censored;
        all_motion_info{end+1} = motion_info;
        
        % Update maximum for this task
        max_by_task(task) = max(max_by_task(task), num_censored);
    end
end

% Convert cell array to array of structs for easier sorting
motion_array = [all_motion_info{:}];

% Sort by count in descending order
[~, idx] = sort([motion_array.count], 'descend');
sorted_motion = motion_array(idx);

% Display results
fprintf('\nMaximum censoring by task:\n');
for task = tasks
    fprintf('%s: %d volumes\n', task{1}, max_by_task(task{1}));
end

fprintf('\nTop 4 subjects with highest motion:\n');
for i = 1:min(6, length(sorted_motion))
    fprintf('Subject %s, Task %s: %d volumes\n', ...
        sorted_motion(i).subject, sorted_motion(i).task, sorted_motion(i).count);
end

% % Output from above:
% % Maximum censoring by task:
% % DORA: 971 volumes (60% of data)
% % RX: 1296 volumes (80% of data)
% % YT: 1036 volumes (63% of data)
% % Global maximum censoring:
% % Subject 1973008C, Task RX: 1296 volumes

% % Top 6 subjects with highest motion:
% % Subject 1973008C, Task RX: 1296 volumes
% % Subject 1973016C, Task RX: 1241 volumes
% % Subject 1973017P, Task RX: 1131 volumes
% % Subject 1973017P, Task YT: 1036 volumes
% % Subject 1973022C, Task RX: 993 volumes
% % Subject 1973012C, Task DORA: 971 volumes (1640-971=669 volumes remaining)
% % Censor 59.76% of data, only use 22 min (660 vols)  for each condition


%% Get high motion volumes and censor, then randomly sample good volumes

required_good_volumes = 660; % We need exactly 660 volumes after censoring
tasks = {'DORA', 'RX', 'YT'};
sessions = {'ses-1', 'ses-2', 'ses-3', 'ses-4'};
sub_tasks = {'1', '2'};
fd_threshold = 0.15;

% Initialize random number generator for reproducibility
rng(42);

for t = 1:length(tasks)
    task = tasks{t};
    dtseries_var_C = sprintf('dtseries_C_sessions_%s', task);
    dtseries_var_P = sprintf('dtseries_P_sessions_%s', task);
    dtseries_C = eval(dtseries_var_C);
    dtseries_P = eval(dtseries_var_P);

    % Create two sets of randomly sampled data
    dtseries_C_sample1 = dtseries_C;
    dtseries_C_sample2 = dtseries_C;
    dtseries_P_sample1 = dtseries_P;
    dtseries_P_sample2 = dtseries_P;

    for sub = 2:26
        if sub == 3
            continue; % Skip subject 03
        end
        
        for is_parent = 0:1
            if is_parent
                subject = sprintf('19730%02dP', sub);
                current_sessions_data = dtseries_P(sub, :);
            else
                subject = sprintf('19730%02dC', sub);
                current_sessions_data = dtseries_C(sub, :);
            end
            
            if all(cellfun(@isempty, current_sessions_data))
                fprintf('No data for subject %s, task %s. Skipping.\n', subject, task);
                continue;
            end
            
            % Initialize arrays for all volumes and their FD values
            all_volumes = [];
            all_fd_values = [];
            total_volumes = 0;
            
            % Adjust sessions for subject 24P
            if strcmp(subject, '1973024P')
                current_sessions = {'ses-1', 'ses-2', 'ses-3', 'ses-6'};
            else
                current_sessions = sessions;
            end
            
            % First pass: Identify all high-motion volumes
            good_volumes_by_session = cell(1, numel(current_sessions));
            
            for j = 1:numel(current_sessions)
                session = current_sessions{j};
                good_volumes_this_session = [];
                total_vols_this_session = 0;
                
                for l = 1:numel(sub_tasks)
                    sub_task = sub_tasks{l};
                    csv_path = fullfile('/Volumes/Prckids', ['sub-' subject], session, 'func', ...
                        sprintf('sub-%s_%s_task-%s%s_echo-2_PowerFDFlt.csv', subject, session, task, sub_task));
                    try
                        fd_data = readtable(csv_path);
                        % Find good volumes (FD <= threshold)
                        good_vols = find(fd_data.FD <= fd_threshold);
                        % Adjust indices for this sub-task
                        good_vols = good_vols + total_vols_this_session;
                        good_volumes_this_session = [good_volumes_this_session; good_vols];
                        total_vols_this_session = total_vols_this_session + height(fd_data);
                    catch
                        warning('Unable to read file: %s', csv_path);
                    end
                end
                
                good_volumes_by_session{j} = good_volumes_this_session;
                total_volumes = total_volumes + total_vols_this_session;
            end
            
            % Calculate total good volumes
            total_good_volumes = sum(cellfun(@length, good_volumes_by_session));
            
            % Check if subject has enough good volumes
            if total_good_volumes < required_good_volumes
                fprintf('Subject %s, Task %s: EXCLUDED - Only %d good volumes (FD≤%.2f), need %d\n', ...
                    subject, task, total_good_volumes, fd_threshold, required_good_volumes);
                
                % Set all sessions to empty for this subject in all samples
                empty_sessions = cell(1, numel(current_sessions));
                if is_parent
                    dtseries_P_sample1(sub, :) = empty_sessions;
                    dtseries_P_sample2(sub, :) = empty_sessions;
                else
                    dtseries_C_sample1(sub, :) = empty_sessions;
                    dtseries_C_sample2(sub, :) = empty_sessions;
                end
                continue;
            end
            
            % For included subjects, randomly sample good volumes for each session
            fprintf('Subject %s, Task %s: %d good volumes available, sampling %d\n', ...
                subject, task, total_good_volumes, required_good_volumes);
            
            % Calculate how many volumes to sample from each session
            vols_per_session = round(required_good_volumes / numel(current_sessions));
            
            % Create two independent random samples
            for sample_num = 1:2
                current_sessions_data_sampled = cell(1, numel(current_sessions));
                
                for j = 1:numel(current_sessions)
                    if ~isempty(current_sessions_data{j})
                        good_vols = good_volumes_by_session{j};
                        
                        % Randomly sample volumes for this session
                        if j == numel(current_sessions) % Last session
                            % Adjust final session to get exactly required_good_volumes in total
                            total_sampled_so_far = sum(cellfun(@(x) size(x,2), current_sessions_data_sampled(1:j-1)));
                            n_sample = required_good_volumes - total_sampled_so_far;
                        else
                            n_sample = vols_per_session;
                        end
                        
                        if length(good_vols) >= n_sample
                            sampled_indices = sort(randsample(good_vols, n_sample));
                        else
                            warning('Not enough good volumes in session %d for subject %s', j, subject);
                            sampled_indices = good_vols; % Take all available good volumes
                        end
                        
                        % Extract sampled volumes
                        current_sessions_data_sampled{j} = current_sessions_data{j}(:, sampled_indices);
                    end
                end
                
                % Store the sampled data
                if is_parent
                    if sample_num == 1
                        dtseries_P_sample1(sub, :) = current_sessions_data_sampled;
                    else
                        dtseries_P_sample2(sub, :) = current_sessions_data_sampled;
                    end
                else
                    if sample_num == 1
                        dtseries_C_sample1(sub, :) = current_sessions_data_sampled;
                    else
                        dtseries_C_sample2(sub, :) = current_sessions_data_sampled;
                    end
                end
            end
        end
    end
    
    % Store the two random samples in new variables
    new_var_name_C1 = sprintf('dtseries_C_sessions_%s_rndsample1', task);
    new_var_name_C2 = sprintf('dtseries_C_sessions_%s_rndsample2', task);
    new_var_name_P1 = sprintf('dtseries_P_sessions_%s_rndsample1', task);
    new_var_name_P2 = sprintf('dtseries_P_sessions_%s_rndsample2', task);
    
    assignin('base', new_var_name_C1, dtseries_C_sample1);
    assignin('base', new_var_name_C2, dtseries_C_sample2);
    assignin('base', new_var_name_P1, dtseries_P_sample1);
    assignin('base', new_var_name_P2, dtseries_P_sample2);
    
    fprintf('Stored sampled data in: %s, %s, %s, %s\n', ...
        new_var_name_C1, new_var_name_C2, new_var_name_P1, new_var_name_P2);
end



%% Save 660 volumes from each tsak matched censored data as total 66 minutes per person

% Create output directory if it doesn't exist
output_dir = '/Volumes/Prckids2/newmc_matlabdir/matchedcensored_allses_dtseries';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Process each subject
for sub = 2:26
    if sub == 3
        continue; % Skip subject 03
    end
    
    % Process each sample
    for sample = 1:2
        % Initialize arrays for combined data
        combined_data_C = [];
        combined_data_P = [];
        
        % Combine all tasks for this subject and sample
        for t = 1:length(tasks)
            task = tasks{t};
            
            % Get variable names for this task
            var_name_C1 = sprintf('dtseries_C_sessions_%s_rndsample1', task);
            var_name_C2 = sprintf('dtseries_C_sessions_%s_rndsample2', task);
            var_name_P1 = sprintf('dtseries_P_sessions_%s_rndsample1', task);
            var_name_P2 = sprintf('dtseries_P_sessions_%s_rndsample2', task);
            
            % Load the data for current sample
            if sample == 1
                dtseries_C = eval(var_name_C1);
                dtseries_P = eval(var_name_P1);
            else
                dtseries_C = eval(var_name_C2);
                dtseries_P = eval(var_name_P2);
            end
            
            % Get current subject's data
            current_data_C = dtseries_C(sub,:);
            current_data_P = dtseries_P(sub,:);
            
            % Combine sessions for child data
            if ~all(cellfun(@isempty, current_data_C))
                task_data_C = [];
                for ses = 1:4
                    if ~isempty(current_data_C{ses})
                        task_data_C = [task_data_C, current_data_C{ses}];
                    end
                end
                combined_data_C = [combined_data_C, task_data_C];
            end
            
            % Combine sessions for parent data
            if ~all(cellfun(@isempty, current_data_P))
                task_data_P = [];
                for ses = 1:4
                    if ~isempty(current_data_P{ses})
                        task_data_P = [task_data_P, current_data_P{ses}];
                    end
                end
                combined_data_P = [combined_data_P, task_data_P];
            end
        end
        
        % Save combined child data if it exists
        if ~isempty(combined_data_C)
            % Create output filename for child
            output_file_C = fullfile(output_dir, ...
                sprintf('sub-19730%02dC_alltasks_sample%d_censored.dtseries.nii', ...
                sub, sample));
            
            % Load template file to get structure
            template_file_C = sprintf('/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/sub-19730%02dC_task-DORA_allsessions.dtseries.nii', sub);
            
            try
                template_C = ciftiopen(template_file_C, wbcommand);
                template_C.cdata = combined_data_C;
                ciftisave(template_C, output_file_C, wbcommand);
                fprintf('Saved combined tasks for child: %s\n', output_file_C);
            catch ME
                warning('Error saving combined file for subject %02dC, sample %d: %s', ...
                    sub, sample, ME.message);
            end
        end
        
        % Save combined parent data if it exists
        if ~isempty(combined_data_P)
            % Create output filename for parent
            output_file_P = fullfile(output_dir, ...
                sprintf('sub-19730%02dP_alltasks_sample%d_censored.dtseries.nii', ...
                sub, sample));
            
            % Load template file to get structure
            template_file_P = sprintf('/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/sub-19730%02dP_task-DORA_allsessions.dtseries.nii', sub);
            
            try
                template_P = ciftiopen(template_file_P, wbcommand);
                template_P.cdata = combined_data_P;
                ciftisave(template_P, output_file_P, wbcommand);
                fprintf('Saved combined tasks for parent: %s\n', output_file_P);
            catch ME
                warning('Error saving combined file for subject %02dP, sample %d: %s', ...
                    sub, sample, ME.message);
            end
        end
    end
end


%% Check the n vols for each person

% Define folder and wb_command path
data_dir = '/Volumes/Prckids2/newmc_matlabdir/matchedcensored_allses_dtseries'; 
wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

% List all .dtseries.nii files
dtseries_files = dir(fullfile(data_dir, '*.dtseries.nii'));

% Preallocate array for storing timepoint counts
n_vols = zeros(length(dtseries_files), 1);

% Loop through files
for i = 1:length(dtseries_files)
    fname = fullfile(data_dir, dtseries_files(i).name);
    
    try
        % Load CIFTI file
        cifti = ciftiopen(fname, wbcommand);
        
        % Store number of timepoints (2nd dimension)
        n_vols(i) = size(cifti.cdata, 2);
    catch ME
        warning('Could not load file: %s\n%s', fname, ME.message);
        n_vols(i) = NaN;
    end
end

% Summary stats
fprintf('\n--- Summary of Timepoints (Volumes) ---\n');
fprintf('N valid files: %d\n', sum(~isnan(n_vols)));
fprintf('Average volumes: %.2f\n', mean(n_vols, 'omitnan'));
fprintf('Min volumes: %d\n', min(n_vols));
fprintf('Max volumes: %d\n', max(n_vols));
