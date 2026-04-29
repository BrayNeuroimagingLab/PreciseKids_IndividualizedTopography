%% Matched censoring across all tasks and all participants for network assignment
% Creates Sample 1/2 matched-censored datasets + logs kept/leftover/censored indices
% Also writes combined "kept" and **capped leftover** (5 min per task) dtseries per sub

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

columns_per_session = 410;

TR_SECONDS = 2;                 
LEFTOVER_MIN_PER_TASK = 5;     
LEFTOVER_TARGET_VOL = round((LEFTOVER_MIN_PER_TASK*60)/TR_SECONDS);  

% File task names vs short task codes
tasks_with_prefix = {'task-DORA','task-RX','task-YT'};
tasks              = {'DORA','RX','YT'};  

%% -------------------------------
%% Load and split uncensored dtseries per task (Child & Parent)
%% -------------------------------
for t = 1:numel(tasks_with_prefix)
    task_pref = tasks_with_prefix{t};
    short     = task_pref(6:end); % 'DORA','RX','YT'

    % ---- Child
    dtseries_C_sessions = cell(26, 4); % 26 subjects x 4 sessions
    for sub = 2:26
        if sub == 3, continue; end % Skip subject 03

        file_path = sprintf(['/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/' ...
                             'sub-19730%02dC_%s_allsessions.dtseries.nii'], sub, task_pref);
        try
            d = ciftiopen(file_path, wbcommand);
            data = d.cdata;
            for ses = 1:4
                start_col = (ses-1)*columns_per_session + 1;
                end_col   = ses*columns_per_session;
                dtseries_C_sessions{sub, ses} = data(:, start_col:end_col);
            end
        catch
            fprintf('Error: file does not exist for child %02d, %s\n', sub, task_pref);
        end
    end
    assignin('base', sprintf('dtseries_C_sessions_%s', short), dtseries_C_sessions);

    % ---- Parent
    dtseries_P_sessions = cell(26, 4);
    for sub = 2:26
        if sub == 3, continue; end

        file_path = sprintf(['/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/' ...
                             'sub-19730%02dP_%s_allsessions.dtseries.nii'], sub, task_pref);
        try
            d = ciftiopen(file_path, wbcommand);
            data = d.cdata;
            for ses = 1:4
                start_col = (ses-1)*columns_per_session + 1;
                end_col   = ses*columns_per_session;
                dtseries_P_sessions{sub, ses} = data(:, start_col:end_col);
            end
        catch
            fprintf('Error: file does not exist for parent %02d, %s\n', sub, task_pref);
        end
    end
    assignin('base', sprintf('dtseries_P_sessions_%s', short), dtseries_P_sessions);
end

%% -------------------------------
%% Motion summary (max censoring across subs/tasks)
%% -------------------------------
subjects = {};
for i = 2:26
    if i == 3, continue; end
    subjects{end+1} = sprintf('19730%02dC', i); 
    subjects{end+1} = sprintf('19730%02dP', i);
end
sessions_fd  = {'ses-1','ses-2','ses-3','ses-4'};
sub_tasks    = {'1','2'};
fd_threshold = 0.15;

max_by_task = containers.Map(tasks, zeros(1, numel(tasks)));
all_motion_info = {};

for i = 1:numel(subjects)
    subject = subjects{i};
    for k = 1:numel(tasks)
        task = tasks{k};
        all_volumes = [];
        total_volumes = 0;

        % Special case for 24P FD files
        if strcmp(subject,'1973024P')
            current_sessions_fd = {'ses-1','ses-2','ses-3','ses-6'};
        else
            current_sessions_fd = sessions_fd;
        end

        for j = 1:numel(current_sessions_fd)
            session = current_sessions_fd{j};
            for l = 1:numel(sub_tasks)
                sub_task = sub_tasks{l};
                csv_path = fullfile('/Volumes/Prckids',['sub-' subject], session, 'func', ...
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

        num_censored = numel(unique(all_volumes));

        info.subject = subject;
        info.task    = task;
        info.count   = num_censored;
        all_motion_info{end+1} = info; 

        max_by_task(task) = max(max_by_task(task), num_censored);
    end
end

motion_array = [all_motion_info{:}];
[~, idx] = sort([motion_array.count], 'descend');
sorted_motion = motion_array(idx);

fprintf('\nMaximum censoring by task:\n');
for tt = 1:numel(tasks)
    fprintf('%s: %d volumes\n', tasks{tt}, max_by_task(tasks{tt}));
end

fprintf('\nTop 15 subjects with highest motion:\n');
for i = 1:min(15, numel(sorted_motion))
    fprintf('Subject %s, Task %s: %d volumes\n', ...
        sorted_motion(i).subject, sorted_motion(i).task, sorted_motion(i).count);
end


%% Matched censored samples 
%% -------------------------------
required_good_volumes = 660; % exactly 660 vol
rng(42);                     % reproducible

% Logs
kept_log = struct();  
left_log = struct();   
cens_log = struct();   

for t = 1:numel(tasks)
    task = tasks{t}; % 'DORA','RX','YT'

    dtseries_var_C = sprintf('dtseries_C_sessions_%s', task);
    dtseries_var_P = sprintf('dtseries_P_sessions_%s', task);
    dtseries_C = eval(dtseries_var_C);
    dtseries_P = eval(dtseries_var_P);

 
    dtseries_C_sample1   = dtseries_C;  dtseries_C_sample2   = dtseries_C;
    dtseries_P_sample1   = dtseries_P;  dtseries_P_sample2   = dtseries_P;
    dtseries_C_leftover1 = dtseries_C;  dtseries_C_leftover2 = dtseries_C;
    dtseries_P_leftover1 = dtseries_P;  dtseries_P_leftover2 = dtseries_P;

    for sub = 2:26
        if sub == 3, continue; end

        for is_parent = 0:1
            if is_parent
                subject = sprintf('19730%02dP', sub);
                current_sessions_data = dtseries_P(sub, :);
            else
                subject = sprintf('19730%02dC', sub);
                current_sessions_data = dtseries_C(sub, :);
            end

            % Skip 
            if all(cellfun(@isempty, current_sessions_data))
                fprintf('No data for subject %s, task %s. Skipping.\n', subject, task);
                continue;
            end

            % FD
            if strcmp(subject,'1973024P')
                current_sessions_fd = {'ses-1','ses-2','ses-3','ses-6'};
            else
                current_sessions_fd = sessions_fd;
            end

            % Build 
            good_volumes_by_session = cell(1, numel(current_sessions_fd));
            cens_volumes_by_session = cell(1, numel(current_sessions_fd));

            for j = 1:numel(current_sessions_fd)
                session = current_sessions_fd{j};
                good_vols_this = [];
                cens_vols_this = [];
                total_vols_this_session = 0;

                for l = 1:numel(sub_tasks)
                    sub_task = sub_tasks{l};
                    csv_path = fullfile('/Volumes/Prckids',['sub-' subject], session, 'func', ...
                        sprintf('sub-%s_%s_task-%s%s_echo-2_PowerFDFlt.csv', subject, session, task, sub_task));
                    try
                        fd_data = readtable(csv_path);
                        idx_good = find(fd_data.FD <= fd_threshold);
                        idx_bad  = find(fd_data.FD >  fd_threshold);

                        good_vols_this = [good_vols_this; idx_good + total_vols_this_session]; 
                        cens_vols_this = [cens_vols_this; idx_bad  + total_vols_this_session]; 

                        total_vols_this_session = total_vols_this_session + height(fd_data);
                    catch
                        warning('Unable to read file: %s', csv_path);
                    end
                end

                good_volumes_by_session{j} = good_vols_this;
                cens_volumes_by_session{j} = cens_vols_this;
            end

            total_good_volumes = sum(cellfun(@numel, good_volumes_by_session));
            if total_good_volumes < required_good_volumes
                fprintf('Subject %s, Task %s: EXCLUDED - Only %d good vols (FD≤%.2f), need %d\n', ...
                    subject, task, total_good_volumes, fd_threshold, required_good_volumes);

                empty_sessions = cell(1, numel(current_sessions_data));
                if is_parent
                    dtseries_P_sample1(sub,:)   = empty_sessions;
                    dtseries_P_sample2(sub,:)   = empty_sessions;
                    dtseries_P_leftover1(sub,:) = empty_sessions;
                    dtseries_P_leftover2(sub,:) = empty_sessions;
                else
                    dtseries_C_sample1(sub,:)   = empty_sessions;
                    dtseries_C_sample2(sub,:)   = empty_sessions;
                    dtseries_C_leftover1(sub,:) = empty_sessions;
                    dtseries_C_leftover2(sub,:) = empty_sessions;
                end
                continue;
            end

            fprintf('Subject %s, Task %s: %d good vols available, sampling %d\n', ...
                subject, task, total_good_volumes, required_good_volumes);

            % How many 
            vols_per_session = round(required_good_volumes / numel(current_sessions_fd));


            subj_key = ['s' subject]; 
            if ~isfield(kept_log, subj_key), kept_log.(subj_key) = struct(); end
            if ~isfield(left_log, subj_key), left_log.(subj_key) = struct(); end
            if ~isfield(cens_log, subj_key), cens_log.(subj_key) = struct(); end
            if ~isfield(kept_log.(subj_key), task), kept_log.(subj_key).(task) = struct(); end
            if ~isfield(left_log.(subj_key), task), left_log.(subj_key).(task) = struct(); end
            if ~isfield(cens_log.(subj_key), task), cens_log.(subj_key).(task) = struct(); end

            % Save 
            for j = 1:numel(current_sessions_fd)
                sess_name = sprintf('ses%02d', j);
                cens_log.(subj_key).(task).(sess_name) = cens_volumes_by_session{j};
            end

            % 
            for sample_num = 1:2
                current_sessions_data_sampled  = cell(1, numel(current_sessions_fd));
                current_sessions_data_leftover = cell(1, numel(current_sessions_fd));

                for j = 1:numel(current_sessions_fd)
                    if ~isempty(current_sessions_data{j})
                        good_vols = good_volumes_by_session{j};


                        if j == numel(current_sessions_fd)
                            total_sampled_so_far = sum(cellfun(@(x) size(x,2), current_sessions_data_sampled(1:j-1)));
                            n_sample = required_good_volumes - total_sampled_so_far;
                        else
                            n_sample = vols_per_session;
                        end
                        n_sample = max(0, n_sample); 

                        if numel(good_vols) >= n_sample && n_sample > 0
                            sampled_indices = sort(randsample(good_vols, n_sample));
                        else
                            if n_sample > 0
                                warning('Not enough good volumes in session %d for subject %s (%s). Taking all good.', j, subject, task);
                            end
                            sampled_indices = sort(good_vols);
                        end

                        
                        sess_name = sprintf('ses%02d', j);
                        fieldname = sprintf('sample%d', sample_num);

                        if ~isfield(kept_log.(subj_key).(task), sess_name)
                            kept_log.(subj_key).(task).(sess_name) = struct();
                        end
                        if ~isfield(left_log.(subj_key).(task), sess_name)
                            left_log.(subj_key).(task).(sess_name) = struct();
                        end

                        kept      = sampled_indices(:);
                        leftover  = setdiff(good_vols, kept);

                        kept_log.(subj_key).(task).(sess_name).(fieldname) = kept;
                        left_log.(subj_key).(task).(sess_name).(fieldname) = leftover(:);

                        % Extract matrices
                        current_sessions_data_sampled{j}  = current_sessions_data{j}(:, kept);
                        if ~isempty(leftover)
                            current_sessions_data_leftover{j} = current_sessions_data{j}(:, leftover);
                        else
                            current_sessions_data_leftover{j} = [];
                        end
                    else
                        current_sessions_data_sampled{j}  = [];
                        current_sessions_data_leftover{j} = [];
                    end
                end

                % Store into subject rows
                if is_parent
                    if sample_num == 1
                        dtseries_P_sample1(sub,:)   = current_sessions_data_sampled;
                        dtseries_P_leftover1(sub,:) = current_sessions_data_leftover;
                    else
                        dtseries_P_sample2(sub,:)   = current_sessions_data_sampled;
                        dtseries_P_leftover2(sub,:) = current_sessions_data_leftover;
                    end
                else
                    if sample_num == 1
                        dtseries_C_sample1(sub,:)   = current_sessions_data_sampled;
                        dtseries_C_leftover1(sub,:) = current_sessions_data_leftover;
                    else
                        dtseries_C_sample2(sub,:)   = current_sessions_data_sampled;
                        dtseries_C_leftover2(sub,:) = current_sessions_data_leftover;
                    end
                end
            end
        end
    end

    assignin('base', sprintf('dtseries_C_sessions_%s_rndsample1', task), dtseries_C_sample1);
    assignin('base', sprintf('dtseries_C_sessions_%s_rndsample2', task), dtseries_C_sample2);
    assignin('base', sprintf('dtseries_P_sessions_%s_rndsample1', task), dtseries_P_sample1);
    assignin('base', sprintf('dtseries_P_sessions_%s_rndsample2', task), dtseries_P_sample2);

    assignin('base', sprintf('dtseries_C_sessions_%s_leftover1', task), dtseries_C_leftover1);
    assignin('base', sprintf('dtseries_C_sessions_%s_leftover2', task), dtseries_C_leftover2);
    assignin('base', sprintf('dtseries_P_sessions_%s_leftover1', task), dtseries_P_leftover1);
    assignin('base', sprintf('dtseries_P_sessions_%s_leftover2', task), dtseries_P_leftover2);

    fprintf('Stored sampled+leftover data in base for task %s.\n', task);
end



%% Save

TR_SECONDS = 2;                               
LEFTOVER_MIN_PER_TASK = 5;                   
LEFTOVER_TARGET_VOL = round((LEFTOVER_MIN_PER_TASK*60)/TR_SECONDS); 

% ---- Output dir
output_dir = fullfile(getenv('HOME'),'Desktop','leftover15min_dtseries');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

clear dtseries_*_rndsample* dtseries_*_sessions_DORA dtseries_*_sessions_RX dtseries_*_sessions_YT

% Process each subject
for sub = 2:26
    if sub == 3
        continue; 
    end
    
    % Process each sample
    for sample = 1:2
        
        combined_data_C = [];
        combined_data_P = [];
        
        % Combine 5-min-per-task left
        for t = 1:length(tasks)
            task = tasks{t};   % 'DORA','RX','YT'
            
            
            var_name_C1 = sprintf('dtseries_C_sessions_%s_leftover1', task);
            var_name_C2 = sprintf('dtseries_C_sessions_%s_leftover2', task);
            var_name_P1 = sprintf('dtseries_P_sessions_%s_leftover1', task);
            var_name_P2 = sprintf('dtseries_P_sessions_%s_leftover2', task);
            
            % Load the data for current sample (LEFTOVER)
            if sample == 1
                dt_C_left = eval(var_name_C1);
                dt_P_left = eval(var_name_P1);
            else
                dt_C_left = eval(var_name_C2);
                dt_P_left = eval(var_name_P2);
            end
            
            % ---------- CHILD leftover for this task (concat sessions, then cap to 5 min) ----------
            if ~all(cellfun(@isempty, dt_C_left(sub,:)))
                task_data_C = [];
                for ses = 1:4
                    if ~isempty(dt_C_left{sub, ses})
                        task_data_C = [task_data_C, dt_C_left{sub, ses}]; 
                    end
                end
                if ~isempty(task_data_C)
                    nC = size(task_data_C,2);
                    if nC > LEFTOVER_TARGET_VOL
                        seedC = 410000 + 1000*sub + 100*sample + 10*t + 0; % reproducible
                        rsC   = RandStream('mt19937ar','Seed',seedC);
                        selC  = sort(randsample(rsC, nC, LEFTOVER_TARGET_VOL));
                        task_data_C = task_data_C(:, selC);
                    end
                    combined_data_C = [combined_data_C, task_data_C]; 
                end
            end
            
            % ---------- PARENT leftover for this task (concat sessions, then cap to 5 min) ----------
            if ~all(cellfun(@isempty, dt_P_left(sub,:)))
                task_data_P = [];
                for ses = 1:4
                    if ~isempty(dt_P_left{sub, ses})
                        task_data_P = [task_data_P, dt_P_left{sub, ses}]; 
                    end
                end
                if ~isempty(task_data_P)
                    nP = size(task_data_P,2);
                    if nP > LEFTOVER_TARGET_VOL
                        seedP = 420000 + 1000*sub + 100*sample + 10*t + 1; % reproducible
                        rsP   = RandStream('mt19937ar','Seed',seedP);
                        selP  = sort(randsample(rsP, nP, LEFTOVER_TARGET_VOL));
                        task_data_P = task_data_P(:, selP);
                    end
                    combined_data_P = [combined_data_P, task_data_P]; 
                end
            end
            clear dt_C_left dt_P_left task_data_C task_data_P
        end
        
        % ---- Save combined CHILD leftover15min 
        if ~isempty(combined_data_C)
            output_file_C = fullfile(output_dir, ...
                sprintf('sub-19730%02dC_alltasks_sample%d_leftover15min.dtseries.nii', sub, sample));
            template_file_C = sprintf(['/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/' ...
                                       'sub-19730%02dC_task-DORA_allsessions.dtseries.nii'], sub);
            try
                template_C = ciftiopen(template_file_C, wbcommand);
                template_C.cdata = combined_data_C;
                ciftisave(template_C, output_file_C, wbcommand);
                fprintf('Saved 15min leftover (Child): %s | vols=%d\n', output_file_C, size(combined_data_C,2));
            catch ME
                warning('Error saving 15min leftover for subject %02dC, sample %d: %s', sub, sample, ME.message);
            end
        end
        
        % ---- Save combined PARENT leftover15min 
        if ~isempty(combined_data_P)
            output_file_P = fullfile(output_dir, ...
                sprintf('sub-19730%02dP_alltasks_sample%d_leftover15min.dtseries.nii', sub, sample));
            template_file_P = sprintf(['/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/' ...
                                       'sub-19730%02dP_task-DORA_allsessions.dtseries.nii'], sub);
            try
                template_P = ciftiopen(template_file_P, wbcommand);
                template_P.cdata = combined_data_P;
                ciftisave(template_P, output_file_P, wbcommand);
                fprintf('Saved 15min leftover (Parent): %s | vols=%d\n', output_file_P, size(combined_data_P,2));
            catch ME
                warning('Error saving 15min leftover for subject %02dP, sample %d: %s', sub, sample, ME.message);
            end
        end
        % Drop large arrays before next loop
        clear combined_data_C combined_data_P template_C template_P
        drawnow;
    end
end


%% Checksing
data_dir = output_dir;  
dtseries_files = dir(fullfile(data_dir, '*leftover15min.dtseries.nii'));
n_vols = zeros(length(dtseries_files), 1);

for i = 1:length(dtseries_files)
    fname = fullfile(data_dir, dtseries_files(i).name);
    try
        cifti = ciftiopen(fname, wbcommand);
        n_vols(i) = size(cifti.cdata, 2);
    catch ME
        warning('Could not load file: %s\n%s', fname, ME.message);
        n_vols(i) = NaN;
    end
end

fprintf('\n--- 15min Leftover Summary ---\n');
fprintf('Files: %d | Avg vols: %.1f | Min: %d | Max: %d\n', ...
    sum(~isnan(n_vols)), mean(n_vols,'omitnan'), min(n_vols), max(n_vols));
