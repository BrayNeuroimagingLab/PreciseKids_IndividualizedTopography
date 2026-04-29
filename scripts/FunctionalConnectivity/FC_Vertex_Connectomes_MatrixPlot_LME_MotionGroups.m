% FC_Vertex_Connectomes_LME_Analysis_Motion_FromCSV.m

%% --- Setup ---
fc_dir = '/Users/shefalirai/Downloads/FC_Vertex_Connectomes/'; %hard coded
files = dir(fullfile(fc_dir, '*.mat'));

validNetworks_all = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
networkID_to_label = containers.Map(...
    validNetworks_all, ...
    {'DMN','VIS','FP','DAN','VAN','SAL','CON','SMd','SMl','AUD','TPole','MTL','PMN','PON'});
labels_all = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks_all), 'UniformOutput', false);

validNetworks_perMethod.highconfidence = [1,2,3,5,7,8,9,10,11,12,16];
default_valid = validNetworks_perMethod.highconfidence;

all_fc = struct(); 
validNetworks_used = struct();

% Read behavioral + motion group data
beh_table = readtable(fullfile(fc_dir, 'prckids-task_beh.csv'));

% Summarize FD by subject
beh_summary = varfun(@mean, beh_table, ...
    'InputVariables', {'meanFD'}, ...
    'GroupingVariables', {'sub', 'sex', 'group', 'motion_group'});

% Add 'sub-' prefix
beh_summary.sub = strcat('sub-', beh_summary.sub);

% Merge family ID back in
[~, idx] = ismember(beh_summary.sub, strcat('sub-', beh_table.sub));
beh_summary.family = beh_table.family(idx);

% Clean up group label (if needed)
beh_summary.group = regexprep(beh_summary.group, 'C', 'Child');
beh_summary.group = regexprep(beh_summary.group, 'P', 'Adult');
beh_summary.group = categorical(beh_summary.group);

% Ensure motion_group is categorical
beh_summary.motion_group = categorical(beh_summary.motion_group);

%% --- Load Data Using motion_group from CSV ---
for i = 1:length(files)
    fname = files(i).name;
    load(fullfile(fc_dir, fname), 'fc_table');
    tokens = regexp(fname, 'sub-(\d{7}[CP])_fc_table_(\w+).mat', 'tokens');
    if isempty(tokens), continue; end
    subjID = tokens{1}{1};
    method = tokens{1}{2};
    
    % Look up motion_group from table
    sub_key = ['sub-' subjID];
    idx = find(strcmp(beh_summary.sub, sub_key));
    if isempty(idx) || ismissing(beh_summary.motion_group(idx))
        continue; % Skip if no motion group info
    end
    motion_group = char(beh_summary.motion_group(idx));
    
    % Skip if not one of our target groups
    if ~ismember(motion_group, {'LMA','LMC','HMC'})
        continue;
    end
    
    % Select networks for this method
    if isfield(validNetworks_perMethod, method)
        validNetworks = validNetworks_perMethod.(method);
    else
        validNetworks = default_valid;
    end
    validNetworks_used.(method) = validNetworks;
    nValid = numel(validNetworks);
    map = containers.Map(validNetworks, 1:nValid);
    fc_mat = nan(nValid);

    % Fill FC matrix
    for j = 1:height(fc_table)
        a = fc_table.NetworkA(j); 
        b = fc_table.NetworkB(j); 
        val = fc_table.FC(j);
        if iscell(val), val = val{1}; end
        if ischar(val), val = str2double(val); end
        if isfinite(val) && isKey(map,a) && isKey(map,b)
            ia = map(a); ib = map(b);
            fc_mat(ia, ib) = val;
            fc_mat(ib, ia) = val;
        end
    end

    % Initialize storage for this method if needed
    if ~isfield(all_fc, method)
        all_fc.(method).LMA = [];
        all_fc.(method).LMC = [];
        all_fc.(method).HMC = [];
        all_fc.(method).LMA_IDs = {};
        all_fc.(method).LMC_IDs = {};
        all_fc.(method).HMC_IDs = {};
    end

    % Append FC matrix and ID
    if isempty(all_fc.(method).(motion_group))
        all_fc.(method).(motion_group) = fc_mat;
    else
        all_fc.(method).(motion_group)(:,:,end+1) = fc_mat;
    end
    all_fc.(method).([motion_group '_IDs']){end+1} = subjID;
end


%% --- Build Long Table and Run Stats for Both Comparisons ---
comparisons = {'LowMotionAdult_vs_LowMotionChild', 'LowMotionAdult_vs_HighMotionChild'};
comparison_groups = {{'LMA', 'LMC'}, {'LMA', 'HMC'}};

sig_positions = struct(); 
long_fc_data = struct(); 
all_edge_results = struct();
methods = fieldnames(all_fc);

for comp = 1:length(comparisons)
    comparison_name = comparisons{comp};
    groups_to_compare = comparison_groups{comp};
    
    for m = 1:length(methods)
        method = methods{m};
        validNetworks = validNetworks_used.(method);
        nValid = numel(validNetworks);
        labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);

        % Get data for comparison groups
        group1_data = all_fc.(method).(groups_to_compare{1});
        group2_data = all_fc.(method).(groups_to_compare{2});
        
        if isempty(group1_data) || isempty(group2_data)
            fprintf('Skipping %s for method %s - insufficient data\n', comparison_name, method);
            continue;
        end

        group1_labels = repmat(groups_to_compare(1), 1, size(group1_data,3));
        group2_labels = repmat(groups_to_compare(2), 1, size(group2_data,3));
        group_labels = [group1_labels, group2_labels];
        
        subj_ids = [all_fc.(method).([groups_to_compare{1} '_IDs']), ...
                   all_fc.(method).([groups_to_compare{2} '_IDs'])];

        all_data = cat(3, group1_data, group2_data);

        % Build long table
        tbl = table();
        for s = 1:size(all_data, 3)
            for i = 1:nValid
                for j = i:nValid
                    val = all_data(i,j,s);
                    if isnan(val), continue; end
                    new_row = {['sub-' subj_ids{s}], group_labels{s}, ...
                               labels_this{i}, labels_this{j}, val, ...
                               sprintf('%s–%s', labels_this{i}, labels_this{j})};
                    tbl = [tbl; cell2table(new_row, 'VariableNames', ...
                           {'Subject', 'Group', 'NetA', 'NetB', 'FC', 'EdgeLabel'})];
                end
            end
        end
        
        % Add behavioral data
        [found, idx] = ismember(tbl.Subject, beh_summary.sub);
        
        if any(~found)
            missing_ids = unique(tbl.Subject(~found));
            fprintf('❗ Missing behavioral data for %d subject(s) in %s:\n', ...
                    numel(missing_ids), comparison_name);
            disp(missing_ids);
            continue; % Skip this comparison for this method
        end
        
        tbl.sex = categorical(beh_summary.sex(idx));
        tbl.meanFD = beh_summary.mean_meanFD(idx);
        tbl.group_label = categorical(tbl.Group);
        % Reorder categories appropriately for each comparison
        if strcmp(comparison_name, 'LowMotionAdult_vs_LowMotionChild')
            tbl.group_label = reordercats(tbl.group_label, {'LMA','LMC'});
        else
            tbl.group_label = reordercats(tbl.group_label, {'LMA','HMC'});
        end
        tbl.family = categorical(beh_summary.family(idx));
        
        % Store long table
        field_name = sprintf('%s_%s', comparison_name, method);
        long_fc_data.(field_name) = tbl;

        % Edge-specific LME with covariates
        tbl.EdgeLabel = categorical(tbl.EdgeLabel);
        edge_list = categories(tbl.EdgeLabel); 
        edge_results = table();
        
        for e = 1:length(edge_list)
            edge = edge_list{e};
            sub_tbl = tbl(tbl.EdgeLabel == edge, :);
            if numel(unique(sub_tbl.Subject)) < 4, continue; end
        
            % Fit edge-wise LME with covariates
            try
                model = fitlme(sub_tbl, 'FC ~ group_label + sex + (1|family)');
                coefs = model.Coefficients;
        
                % Extract group effect 
                group_coef_name = sprintf('group_label_%s', groups_to_compare{2});
                if any(strcmp(coefs.Name, group_coef_name))
                    row = {edge, coefs.Estimate(strcmp(coefs.Name, group_coef_name)), ...
                           coefs.pValue(strcmp(coefs.Name, group_coef_name))};
                    edge_results = [edge_results; cell2table(row, ...
                        'VariableNames', {'Edge', 'Beta', 'pValue'})];
                end
            catch ME
                fprintf('Error fitting model for edge %s in %s: %s\n', ...
                        edge, comparison_name, ME.message);
                continue;
            end
        end

        if isempty(edge_results)
            fprintf('No valid edge results for %s %s\n', comparison_name, method);
            continue;
        end

        edge_results.pFDR = mafdr(edge_results.pValue, 'BHFDR', true);
        edge_results = sortrows(edge_results, 'pFDR');
        sig_edges = edge_results(edge_results.pFDR < 0.05, :);

        % Store results
        all_edge_results.(field_name) = edge_results;

        % Store binary sig matrix for plotting
        sig_mat = false(nValid);
        for r = 1:height(sig_edges)
            parts = split(sig_edges.Edge{r}, '–');
            i = find(strcmp(labels_this, parts{1}));
            j = find(strcmp(labels_this, parts{2}));
            if ~isempty(i) && ~isempty(j)
                sig_mat(i,j) = true;
            end
        end
        sig_positions.(field_name) = sig_mat;

        disp(['--- COMPARISON: ', comparison_name, ', METHOD: ', method, ' ---']);
        if isempty(sig_edges)
            disp('No significant edges at FDR < 0.05');
        else
            disp(sig_edges);
        end
    end
end


%% --- Plot FC Differences with Significance Overlay ---
n = 256; purple = [76,0,153]/255; orange = [1,0.4,0];
cmap1 = [linspace(purple(1),1,n/2)', linspace(purple(2),1,n/2)', linspace(purple(3),1,n/2)'];
cmap2 = [linspace(1,orange(1),n/2)', linspace(1,orange(2),n/2)', linspace(1,orange(3),n/2)'];
custom_cmap = [cmap1; cmap2];

for comp = 1:length(comparisons)
    comparison_name = comparisons{comp};
    groups_to_compare = comparison_groups{comp};
    
    for m = 1:length(methods)
        method = methods{m};
        field_name = sprintf('%s_%s', comparison_name, method);
        
        if ~isfield(all_edge_results, field_name)
            continue;
        end
        
        validNetworks = validNetworks_used.(method);
        labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);
        nValid = numel(validNetworks);
        
        edge_results = all_edge_results.(field_name);

        % Compute LME diff matrix
        diff_mat = nan(nValid); p_mat = nan(nValid);

        for r = 1:height(edge_results)
            edge_label = edge_results.Edge{r};
            parts = split(edge_label, '–');
            i = find(strcmp(labels_this, parts{1}));
            j = find(strcmp(labels_this, parts{2}));
            if isempty(i) || isempty(j), continue; end
        
            % For interpretation: positive beta = second group > first group
            beta = -edge_results.Beta(r);  % NEGATE to show first group > second group
            pval = edge_results.pValue(r);
        
            diff_mat(i,j) = beta;
            p_mat(i,j) = pval;
        end

        % Mask lower triangle
        diff_mat(tril(true(nValid), -1)) = NaN;

        % Plot
        figure('Name', sprintf('%s %s — FC Diff', comparison_name, method));
        imagesc(diff_mat); colormap(custom_cmap); colorbar; caxis([-0.2 0.2]);
        axis square; xticks(1:nValid); yticks(1:nValid);
        xticklabels(labels_this); yticklabels(labels_this); xtickangle(45);
        title(sprintf('%s %s — %s - %s FC', comparison_name, method, ...
                      groups_to_compare{1}, groups_to_compare{2})); 
        hold on;

        % Extract FDR-significant edges
        sig_edges = edge_results(edge_results.pFDR < 0.05, :);
        
        for k = 1:height(sig_edges)
            edge_label = sig_edges.Edge{k};
            parts = split(edge_label, '–');
            i = find(strcmp(labels_this, parts{1}));
            j = find(strcmp(labels_this, parts{2}));
            if isempty(i) || isempty(j), continue; end
        
            beta = sig_edges.Beta(k);
        
            % Choose color by direction
            if beta < 0
                star_color = 'red';  % First group > Second group
            else
                star_color = [0.4 0 0.6];  % Second group > First group (purple)
            end
        
            % Plot star
            text(j, i, '*', 'FontSize', 14, ...
                 'Color', star_color, 'HorizontalAlignment', 'center');
        end

        % Legend
        text(nValid + 0.5, 1, sprintf('* = %s > %s', groups_to_compare{1}, groups_to_compare{2}), ...
             'Color', 'red', 'FontSize', 10);
        text(nValid + 0.5, 2, sprintf('* = %s > %s', groups_to_compare{2}, groups_to_compare{1}), ...
             'Color', [0.4 0 0.6], 'FontSize', 10);

        exportgraphics(gcf, fullfile(fc_dir, sprintf('%s_%s_FCdiff.png', comparison_name, method)), ...
                       'Resolution', 300);
    end
end




%% --- Export Beta and Q Matrices ---
outdir = fullfile(fc_dir, 'exports_csv_motion');
if ~exist(outdir, 'dir'); mkdir(outdir); end

% Export matrices for each comparison and method
field_names = fieldnames(all_edge_results);
for f = 1:length(field_names)
    field_name = field_names{f};
    
    if ~isfield(all_edge_results, field_name)
        continue;
    end
    
    % Parse field name to get comparison and method
    parts = split(field_name, '_');
    if length(parts) >= 4
        comparison = strjoin(parts(1:3), '_');  % e.g., 'LMA_vs_LMC'
        method = parts{4};                      % e.g., 'highconfidence'
    else
        continue;
    end
    
    % Get valid networks and labels for this method
    if isfield(validNetworks_used, method)
        validNetworks = validNetworks_used.(method);
    else
        continue;
    end
    nValid = numel(validNetworks);
    labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);
    
    edge_results = all_edge_results.(field_name);
    
    % Build beta and q matrices (upper triangle only)
    beta_mat = nan(nValid); 
    q_mat = nan(nValid);
    
    for r = 1:height(edge_results)
        edge_label = edge_results.Edge{r};
        parts_edge = split(edge_label, '–');
        i = find(strcmp(labels_this, parts_edge{1}));
        j = find(strcmp(labels_this, parts_edge{2}));
        if isempty(i) || isempty(j), continue; end
        
        beta = -edge_results.Beta(r);  % Negate to show first group > second group
        q_val = edge_results.pFDR(r);
        
        beta_mat(i,j) = beta;
        q_mat(i,j) = q_val;
    end
    
    % Create tables with proper row/column names
    T_beta = array2table(beta_mat, 'VariableNames', labels_this, 'RowNames', labels_this);
    T_q = array2table(q_mat, 'VariableNames', labels_this, 'RowNames', labels_this);
    
    % Export matrices
    writetable(T_beta, fullfile(outdir, sprintf('%s_%s_beta_matrix.csv', comparison, method)), 'WriteRowNames', true);
    writetable(T_q, fullfile(outdir, sprintf('%s_%s_q_matrix.csv', comparison, method)), 'WriteRowNames', true);
    
    fprintf('Exported matrices for %s %s\n', comparison, method);
end




%% --- Export everything to CSV ---
outdir = fullfile(fc_dir, 'exports_csv_motion');
if ~exist(outdir, 'dir'); mkdir(outdir); end

% Export data for each comparison and method
field_names = fieldnames(long_fc_data);
for f = 1:length(field_names)
    field_name = field_names{f};
    if isfield(long_fc_data, field_name) && isfield(all_edge_results, field_name)
        % Export long FC table
        writetable(long_fc_data.(field_name), ...
                   fullfile(outdir, sprintf('%s_long_fc.csv', field_name)));
        
        % Export edge results
        writetable(all_edge_results.(field_name), ...
                   fullfile(outdir, sprintf('%s_edge_results.csv', field_name)));
    end
end

