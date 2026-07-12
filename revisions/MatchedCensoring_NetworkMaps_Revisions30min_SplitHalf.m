%% 30min split-half dtseries
% Creates two non-overlapping independent samples per subject, each = 30 min (900 vols).


wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

columns_per_session = 410;
TR_SECONDS          = 2;
TARGET_EACH         = round((30 * 60) / TR_SECONDS);  % 900 vols per sample
TARGET_TOTAL        = TARGET_EACH * 2;                 % 1800 vols to draw from pool

tasks_with_prefix = {'task-DORA', 'task-RX', 'task-YT'};
tasks             = {'DORA', 'RX', 'YT'};
sessions_fd       = {'ses-1', 'ses-2', 'ses-3', 'ses-4'};
sub_tasks         = {'1', '2'};
fd_threshold      = 0.15;

output_dir = fullfile(getenv('HOME'), 'Desktop', '30min_splitHalf_dtseries');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end

%% Main loop
for sub = 2:26
    if sub == 3, continue; end
    fprintf('\n========== Subject %02d ==========\n', sub);

    for is_parent = 0:1
        if is_parent
            subject  = sprintf('19730%02dP', sub);
            subtype  = 'P';
        else
            subject  = sprintf('19730%02dC', sub);
            subtype  = 'C';
        end
        fprintf('  %s\n', subject);

        if strcmp(subject, '1973024P')
            current_sessions_fd = {'ses-1', 'ses-2', 'ses-3', 'ses-6'};
        else
            current_sessions_fd = sessions_fd;
        end

        pooled_data = [];

        for t = 1:numel(tasks)
            task      = tasks{t};
            task_pref = tasks_with_prefix{t};

            file_path = sprintf(['/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/' ...
                                 'sub-19730%02d%s_%s_allsessions.dtseries.nii'], sub, subtype, task_pref);
            try
                d = ciftiopen(file_path, wbcommand);
                data = d.cdata;
                clear d
            catch ME
                fprintf('    Error loading task %s: %s\n', task, ME.message);
                continue;
            end

            sessions_data = cell(1, 4);
            for ses = 1:4
                sessions_data{ses} = data(:, (ses-1)*columns_per_session+1 : ses*columns_per_session);
            end
            clear data

            for j = 1:numel(current_sessions_fd)
                session = current_sessions_fd{j};
                total_vols_this_session = 0;
                good_vols_this = [];

                for l = 1:numel(sub_tasks)
                    csv_path = fullfile('/Volumes/Prckids', ['sub-' subject], session, 'func', ...
                        sprintf('sub-%s_%s_task-%s%s_echo-2_PowerFDFlt.csv', ...
                                subject, session, task, sub_tasks{l}));
                    try
                        fd_data = readtable(csv_path);
                        good_vols_this = [good_vols_this; ...
                            find(fd_data.FD <= fd_threshold) + total_vols_this_session];
                        total_vols_this_session = total_vols_this_session + height(fd_data);
                    catch
                        warning('Unable to read FD file: %s', csv_path);
                    end
                end

                if ~isempty(good_vols_this) && ~isempty(sessions_data{j})
                    valid_idx = good_vols_this(good_vols_this <= size(sessions_data{j}, 2));
                    if ~isempty(valid_idx)
                        pooled_data = [pooled_data, sessions_data{j}(:, valid_idx)];
                    end
                end
            end
            clear sessions_data

        end % task loop

        n_pool = size(pooled_data, 2);
        fprintf('    Total good vols pooled across tasks: %d\n', n_pool);

        if n_pool < TARGET_TOTAL
            fprintf('    SKIPPING %s: only %d good vols, need %d for 30min split-half\n', ...
                    subject, n_pool, TARGET_TOTAL);
            clear pooled_data
            continue;
        end

        seed = 300000 + 1000 * sub + is_parent;
        rs   = RandStream('mt19937ar', 'Seed', seed);
        sel  = sort(randsample(rs, n_pool, TARGET_TOTAL));  % 1800 unique indices

        sample1_data = pooled_data(:, sel(1:TARGET_EACH));           % vols 1-900
        sample2_data = pooled_data(:, sel(TARGET_EACH+1:end));       % vols 901-1800
        clear pooled_data

        % Save
        tmpl_f = sprintf(['/Volumes/Prckids2/newmc_matlabdir/uncensored_allses_dtseries/' ...
                          'sub-19730%02d%s_task-DORA_allsessions.dtseries.nii'], sub, subtype);

        for samp = 1:2
            if samp == 1
                samp_data = sample1_data;
            else
                samp_data = sample2_data;
            end
            out_file = fullfile(output_dir, ...
                sprintf('sub-19730%02d%s_alltasks_30min_sample%d.dtseries.nii', sub, subtype, samp));
            try
                tmpl = ciftiopen(tmpl_f, wbcommand);
                tmpl.cdata = samp_data;
                ciftisave(tmpl, out_file, wbcommand);
                fprintf('    Saved sample%d: %d vols\n', samp, size(samp_data, 2));
                clear tmpl
            catch ME
                warning('    Error saving sample%d for %s: %s', samp, subject, ME.message);
            end
        end
        clear sample1_data sample2_data
        drawnow;

    end % is_parent loop
end % sub loop


%% Summary check
fprintf('\n=== 30min Split-Half Summary ===\n');
for samp = 1:2
    files = dir(fullfile(output_dir, sprintf('*30min_sample%d.dtseries.nii', samp)));
    n_vols_arr = NaN(length(files), 1);
    for i = 1:length(files)
        try
            c = ciftiopen(fullfile(output_dir, files(i).name), wbcommand);
            n_vols_arr(i) = size(c.cdata, 2);
            clear c
        catch; end
    end
    fprintf('Sample %d: %d files | Avg: %.1f | Min: %d | Max: %d\n', ...
        samp, sum(~isnan(n_vols_arr)), mean(n_vols_arr,'omitnan'), ...
        min(n_vols_arr), max(n_vols_arr));
end
