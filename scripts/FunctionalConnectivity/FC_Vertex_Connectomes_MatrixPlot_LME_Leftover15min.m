% FC_Vertex_Connectomes_LME_Analysis.m --- Updated for 15 min matrices


%******For the first script, I excluded 17P and 8C that have <80 mins of total data******
%******For this script, I excluded 17P, 8C, 12C, 16C, 17C, 22C, 20C, 10C that have <95 mins of total data******


%% --- Setup ---
fc_dir = '/Users/shefalirai/Downloads/FC_Vertex_Connectomes_15minleftover/';
files = dir(fullfile(fc_dir, '*.mat'));

validNetworks_all = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
networkID_to_label = containers.Map(...
    validNetworks_all, ...
    {'DMN','VIS','FP','DAN','VAN','SAL','CON','SMd','SMl','AUD','TPole','MTL','PMN','PON'});
labels_all = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks_all), 'UniformOutput', false);

validNetworks_perMethod.highconfidence = [1,2,3,5,7,8,9,10,11,12,16];
default_valid = validNetworks_perMethod.highconfidence;

all_fc = struct(); validNetworks_used = struct();

beh_table = readtable('/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv');

if ~ismember('meanFD', beh_table.Properties.VariableNames)
    error('Column "meanFD" not found. Actual names: %s', strjoin(beh_table.Properties.VariableNames, ', '));
end

try
    beh_summary = groupsummary(beh_table, {'sub','sex','group'}, 'mean', 'meanFD');
 
catch

    beh_summary = grpstats(beh_table, {'sub','sex','group'}, {'mean'}, 'DataVars','meanFD');
    beh_summary = renamevars(beh_summary, 'mean_meanFD', 'mean_meanFD'); % no-op, keeps same name
end

beh_summary.sub = "sub-" + string(beh_summary.sub);


% Merge family back in using original table
[~, idx] = ismember(beh_summary.sub, strcat('sub-', beh_table.sub));
beh_summary.family = beh_table.family(idx);


% Clean up group label
beh_summary.group = regexprep(beh_summary.group, 'C', 'Child');
beh_summary.group = regexprep(beh_summary.group, 'P', 'Adult');
beh_summary.group = categorical(beh_summary.group);



%% --- Load Data ---
for i = 1:length(files)
    fname = files(i).name;
    load(fullfile(fc_dir, fname), 'fc_table');
    tokens = regexp(fname, 'sub-(\d{7}[CP])_fc_table_leftover15min_(\w+).mat', 'tokens');
    if isempty(tokens), continue; end
    subjID = tokens{1}{1}; method = tokens{1}{2};
    group = 'Child'; if endsWith(subjID, 'P'), group = 'Adult'; end
    if isfield(validNetworks_perMethod, method)
        validNetworks = validNetworks_perMethod.(method);
    else
        validNetworks = default_valid;
    end
    validNetworks_used.(method) = validNetworks;
    nValid = numel(validNetworks);
    map = containers.Map(validNetworks, 1:nValid);
    fc_mat = nan(nValid);

    for j = 1:height(fc_table)
        a = fc_table.NetworkA(j); b = fc_table.NetworkB(j); val = fc_table.FC(j);
        if iscell(val), val = val{1}; end
        if ischar(val), val = str2double(val); end
        if isfinite(val) && isKey(map,a) && isKey(map,b)
            ia = map(a); ib = map(b);
            fc_mat(ia, ib) = val;
            fc_mat(ib, ia) = val;
        end
    end


    if ~isfield(all_fc, method)
    all_fc.(method).Adult = [];
    all_fc.(method).Child = [];
    all_fc.(method).Adult_IDs = {};
    all_fc.(method).Child_IDs = {};
    end

    if isempty(all_fc.(method).(group))
        all_fc.(method).(group) = fc_mat;
    else
        all_fc.(method).(group)(:,:,end+1) = fc_mat;
    end

all_fc.(method).([group '_IDs']){end+1} = subjID;
end




%% Build Long Table and Run Stats

sig_positions = struct(); long_fc_data = struct(); methods = fieldnames(all_fc);
for m = 1:length(methods)
    method = methods{m};
    validNetworks = validNetworks_used.(method);
    nValid = numel(validNetworks);
    labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);

    adults = all_fc.(method).Adult;
    children = all_fc.(method).Child;
    group_labels = [repmat({'Adult'}, 1, size(adults,3)), repmat({'Child'}, 1, size(children,3))];
    subj_ids = [all_fc.(method).Adult_IDs, all_fc.(method).Child_IDs];

    all_data = cat(3, adults, children);

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
    long_fc_data.(method) = tbl;

    % Extract subj ID from FC table
    fc_sub_ids = regexprep(tbl.Subject, '[AC]', '');  % remove 'A' or 'C'
    [found, idx] = ismember(tbl.Subject, beh_summary.sub);

    if any(~found)
        missing_ids = unique(tbl.Subject(~found));
        fprintf('❗ Missing behavioral data for %d subject(s):\n', numel(missing_ids));
        disp(missing_ids);
        error('Aborting: behavioral data missing for one or more FC subjects.');
    end
    
    tbl.sex = categorical(beh_summary.sex(idx));
    tbl.meanFD = beh_summary.mean_meanFD(idx);
    tbl.group_label = categorical(beh_summary.group(idx));
    tbl.group_label = reordercats(tbl.group_label, {'Adult','Child'});
    tbl.family = categorical(beh_summary.family(idx)); 


    if any(~found)
        missing_ids = unique(fc_sub_ids(~found));
        fprintf('❗ Missing behavioral data for %d subject(s):\n', numel(missing_ids));
        disp(missing_ids);
        error('Aborting: behavioral data missing for one or more FC subjects.');
    end

    
    % Edge-specific LME with covariates
    tbl.EdgeLabel = categorical(tbl.EdgeLabel);
    edge_list = categories(tbl.EdgeLabel); 
    
    edge_results = table();   % will hold both group and motion effects

    for e = 1:length(edge_list)
        edge = edge_list{e};
        sub_tbl = tbl(tbl.EdgeLabel == edge, :);
        if numel(unique(sub_tbl.Subject)) < 4, continue; end
    
        % Fit edge-wise LME with motion
        model = fitlme(sub_tbl, 'FC ~ group_label + sex + meanFD + (1|family)');
        coefs = model.Coefficients;
    
        % Extract group (Child vs Adult) effect
        has_grp = any(strcmp(coefs.Name, 'group_label_Child'));
        if has_grp
            grp_est = coefs.Estimate(strcmp(coefs.Name, 'group_label_Child'));
            grp_p   = coefs.pValue( strcmp(coefs.Name, 'group_label_Child'));
        else
            grp_est = NaN; grp_p = NaN;
        end
    
        % Extract motion (meanFD) effect
        has_fd = any(strcmp(coefs.Name, 'meanFD'));
        if has_fd
            fd_est = coefs.Estimate(strcmp(coefs.Name, 'meanFD'));
            fd_p   = coefs.pValue( strcmp(coefs.Name, 'meanFD'));
        else
            fd_est = NaN; fd_p = NaN;
        end
    
        % --- ADDED DIS: pull SE for the motion term + 95% CI and sample sizes
        fd_se  = NaN; fd_ci_low = NaN; fd_ci_high = NaN;
        if has_fd
            fd_se     = coefs.SE(strcmp(coefs.Name,'meanFD'));
            fd_ci_low = fd_est - 1.96 * fd_se;
            fd_ci_high= fd_est + 1.96 * fd_se;
        end
        
        % effective sample sizes per edge (optional but useful to explain CI width)
        n_obs      = height(sub_tbl);                        % rows for that edge
        n_subjects = numel(unique(sub_tbl.Subject));         % unique subjects
        
        newrow = {edge, grp_est, grp_p, fd_est, fd_p, fd_se, fd_ci_low, fd_ci_high, n_obs, n_subjects};
        edge_results = [edge_results; cell2table(newrow, 'VariableNames', ...
          {'Edge','Beta_GroupChild','p_GroupChild','Beta_meanFD','p_meanFD', ...
           'SE_meanFD','CIlo_meanFD','CIhi_meanFD','N_rows','N_subjects'})];

    end
    
    % FDR-correct the two families separately
    edge_results.q_GroupChild = mafdr(edge_results.p_GroupChild, 'BHFDR', true);
    edge_results.q_meanFD     = mafdr(edge_results.p_meanFD,     'BHFDR', true);
    
    % Sort 
    edge_results = sortrows(edge_results, 'q_GroupChild');  % or 'q_meanFD'
    edge_results.q_GroupChild = mafdr(edge_results.p_GroupChild, 'BHFDR', true);

    % old names
    edge_results.Beta   = edge_results.Beta_GroupChild;
    edge_results.pValue = edge_results.p_GroupChild;
    edge_results.pFDR   = edge_results.q_GroupChild;

    sig_edges = edge_results(edge_results.pFDR < 0.05, :);
    disp(sig_edges);

    % Store binary sig matrix for uniqueness test
    sig_mat = false(nValid);
    for r = 1:height(sig_edges)
        parts = split(sig_edges.Edge{r}, '–');
        i = find(strcmp(labels_this, parts{1}));
        j = find(strcmp(labels_this, parts{2}));
        sig_mat(i,j) = true;
    end
    full_sig = false(16,16);
    for i = 1:nValid
        for j = 1:nValid
            ni = validNetworks(i); nj = validNetworks(j);
            full_sig(ni,nj) = sig_mat(i,j);
        end
    end
    sig_positions.(method) = full_sig;


    disp(['--- METHOD: ', method, ' ---']);
    if isempty(sig_edges)
        disp('No significant edges at FDR < 0.05');
    else
        disp(sig_edges);
    end

    all_edge_results.(method) = edge_results;

end




%% ===== Export motion-affected edges (FD term) to Excel =====
outdir = fullfile(fc_dir, 'exports_motion');
if ~exist(outdir, 'dir'); mkdir(outdir); end

xlsx_sig = fullfile(outdir, 'motion_significant_edges.xlsx');   % q_meanFD < 0.05
xlsx_all = fullfile(outdir, 'motion_all_edges.xlsx');           

if exist(xlsx_sig, 'file'); delete(xlsx_sig); end
if exist(xlsx_all, 'file'); delete(xlsx_all); end

methods = fieldnames(all_edge_results);
master_sig = table();  % combined table across methods

for m = 1:numel(methods)
    method = methods{m};
    T = all_edge_results.(method);

   
    requiredCols = {'Edge','Beta_meanFD','p_meanFD','q_meanFD'};
    if ~all(ismember(requiredCols, T.Properties.VariableNames))
        warning('Method %s is missing motion columns; skipping.', method);
        continue;
    end

    % Per-method ALL edges with motion columns (wits SE/CI/N)
    T_all = T(:, {'Edge','Beta_meanFD','SE_meanFD','CIlo_meanFD','CIhi_meanFD', ...
                  'p_meanFD','q_meanFD', ...
                  'Beta_GroupChild','p_GroupChild','q_GroupChild', ...
                  'N_rows','N_subjects'});
    
    % Add a direction label for motion
    dir_motion = repmat(string(missing), height(T_all), 1);
    dir_motion(T_all.Beta_meanFD > 0) = "↑ (higher FD → higher FC)";
    dir_motion(T_all.Beta_meanFD < 0) = "↓ (higher FD → lower FC)";
    T_all.Direction = dir_motion;
    
    % Write the full, unfiltered sheet 
    writetable(T_all, xlsx_all, 'Sheet', method, 'WriteMode', 'overwritesheet');


    % Filter to motion-significant edges
    is_sig = T.q_meanFD < 0.05 & ~isnan(T.q_meanFD);
    T_sig = T(is_sig, {'Edge','Beta_meanFD','q_meanFD','p_meanFD'});

  
    dir_sig = repmat(string(missing), height(T_sig), 1);
    dir_sig(T_sig.Beta_meanFD > 0) = "↑ (higher FD → higher FC)";
    dir_sig(T_sig.Beta_meanFD < 0) = "↓ (higher FD → lower FC)";
    T_sig.Direction = dir_sig;

    % Add method column and sort by q
    T_sig.Method = repmat(string(method), height(T_sig), 1);
    T_sig = movevars(T_sig, 'Method', 'Before', 'Edge');
    T_sig = sortrows(T_sig, 'q_meanFD');

    % Write per-method significant sheet
    writetable(T_sig, xlsx_sig, 'Sheet', method, 'WriteMode', 'overwritesheet');

    % Append to master table
    master_sig = [master_sig; T_sig]; 
end


if ~isempty(master_sig)
    writetable(master_sig, xlsx_sig, 'Sheet', 'ALL_methods', 'WriteMode', 'overwritesheet');
end



%% --- Plot FC Differences with Significance Overlay ---

% Reconstruct binary sig matrices per method
mnames = fieldnames(sig_positions);
sig1 = sig_positions.(mnames{1});
sig2 = sig_positions.(mnames{2});
sig3 = sig_positions.(mnames{3});

% Compute unique significance per method
unique1 = sig1 & ~sig2 & ~sig3;
unique2 = sig2 & ~sig1 & ~sig3;
unique3 = sig3 & ~sig1 & ~sig2;

% Store in a cell array
unique_maps = {unique1, unique2, unique3};


n = 256; purple = [76,0,153]/255; orange = [1,0.4,0];
cmap1 = [linspace(purple(1),1,n/2)', linspace(purple(2),1,n/2)', linspace(purple(3),1,n/2)'];
cmap2 = [linspace(1,orange(1),n/2)', linspace(1,orange(2),n/2)', linspace(1,orange(3),n/2)'];
custom_cmap = [cmap1; cmap2];
method_colors = struct('highconfidence','red','individualmaps','blue','grouptemplate','green');

for m = 1:length(methods)
    method = methods{m};
    validNetworks = validNetworks_used.(method);
    labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);
    nValid = numel(validNetworks);
    tbl = long_fc_data.(method);

    if ~iscategorical(tbl.EdgeLabel)
        tbl.EdgeLabel = categorical(tbl.EdgeLabel);
    end

    % Compute LME diff matrix
    edge_list = categories(tbl.EdgeLabel);
    diff_mat = nan(nValid); p_mat = nan(nValid);

    edge_results = all_edge_results.(method);
    for r = 1:height(edge_results)
        edge_label = edge_results.Edge{r};
        parts = split(edge_label, '–');
        i = find(strcmp(labels_this, parts{1}));
        j = find(strcmp(labels_this, parts{2}));
        if isempty(i) || isempty(j), continue; end
    
        beta = -edge_results.Beta(r);  % NEGATE to show Adult > Child
        pval = edge_results.pValue(r);
    
        diff_mat(i,j) = beta;
        p_mat(i,j) = pval;
    end


    % Apply significance and uniqueness masks
    sig_logical = false(nValid); sig_logical(p_mat < 0.05) = true;
    uniq_crop = unique_maps{m}(validNetworks, validNetworks);
    diff_mat(tril(true(nValid), -1)) = NaN;

    % Plot
    figure('Name', [method ' — FC Diff']);
    imagesc(diff_mat); colormap(custom_cmap); colorbar; caxis([-0.2 0.2]);
    axis square; xticks(1:nValid); yticks(1:nValid);
    xticklabels(labels_this); yticklabels(labels_this); xtickangle(45);
    title([method ' — Adult - Child FC']); hold on;

    % Extract FDR-significant Adult > Child edges from edge_results
    this_edges = all_edge_results.(method);

    % FDR-significant edges in either direction
    sig_edges = this_edges(this_edges.pFDR < 0.05, :);
    
    for k = 1:height(sig_edges)
        edge_label = sig_edges.Edge{k};
        parts = split(edge_label, '–');
        i = find(strcmp(labels_this, parts{1}));
        j = find(strcmp(labels_this, parts{2}));
        if isempty(i) || isempty(j), continue; end
    
        beta = sig_edges.Beta(k);
    
        % Choose color by direction
        if beta < 0
            star_color = 'red';  % Adult > Child
        else
            star_color = [0.4 0 0.6];  % purple RGB
        end
    
        % Plot star
        text(j, i, '*', 'FontSize', 14, ...
             'Color', star_color, 'HorizontalAlignment', 'center');
    end



    [ui, uj] = find(uniq_crop);
    for k = 1:length(ui)
        text(uj(k), ui(k), '*', 'FontSize', 24, ...
            'FontWeight','bold','Color',method_colors.(method), ...
            'HorizontalAlignment','center');
    end

    text(nValid + 0.5, 1, '* = Adult > Child', 'Color', 'red', 'FontSize', 12);
    text(nValid + 0.5, 2, '* = Child > Adult', 'Color', [0.4 0 0.6], 'FontSize', 12);


    exportgraphics(gcf, fullfile(fc_dir, sprintf('%s_FCdiff.png', method)), 'Resolution', 300);
end








%% Plot Betas for effect size (Adult > Child)
for m = 1:length(methods)
    method = methods{m};
    validNetworks = validNetworks_used.(method);
    labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);
    nValid = numel(validNetworks);
    edge_results = all_edge_results.(method);

    % Build beta matrix (negated to show Adult > Child)
    beta_mat = nan(nValid);
    sig_edges = edge_results(edge_results.pFDR < 0.05, :);

    for r = 1:height(edge_results)
        parts = split(edge_results.Edge{r}, '–');
        i = find(strcmp(labels_this, parts{1}));
        j = find(strcmp(labels_this, parts{2}));
        if isempty(i) || isempty(j), continue; end
        beta = -edge_results.Beta(r);  % NEGATE to make positive = Adult > Child
        beta_mat(i,j) = beta;
    end

    % Mask lower triangle
    beta_mat(tril(true(nValid), -1)) = NaN;

    % Plot
    figure('Name', [method ' — LME Beta Values (Adult > Child)']);
    imagesc(beta_mat); 
    colormap(custom_cmap); 
    colorbar; 
    caxis([-0.1 0.1]); 
    axis square;
    xticks(1:nValid); yticks(1:nValid);
    xticklabels(labels_this); yticklabels(labels_this); xtickangle(45);
    title([method ' — LME Beta Coefficients']);
    hold on;

    % Overlay *
    for r = 1:height(sig_edges)
        parts = split(sig_edges.Edge{r}, '–');
        i = find(strcmp(labels_this, parts{1}));
        j = find(strcmp(labels_this, parts{2}));
        if isempty(i) || isempty(j), continue; end
        beta = -sig_edges.Beta(r);  % NEGATE again for consistent direction

        % Choose star color based on direction
        if beta > 0
            star_color = 'red';       % Adult > Child
        else
            star_color = [0.4 0 0.6]; % Child > Adult
        end

        text(j, i, '*', 'FontSize', 14, ...
            'Color', star_color, 'HorizontalAlignment', 'center');
    end


    text(nValid + 0.5, 1, '* = Adult > Child', 'Color', 'red', 'FontSize', 12);
    text(nValid + 0.5, 2, '* = Child > Adult', 'Color', [0.4 0 0.6], 'FontSize', 12);
    

    uniq_crop = unique_maps{m}(validNetworks, validNetworks);
    [ui, uj] = find(uniq_crop);
    for k = 1:length(ui)
        text(uj(k), ui(k), '*', 'FontSize', 24, ...
            'FontWeight','bold','Color',method_colors.(method), ...
            'HorizontalAlignment','center');
    end

    % Save plot
    exportgraphics(gcf, fullfile(fc_dir, sprintf('%s_LME_BetaMatrix.png', method)), 'Resolution', 300);
end










%% --- Export everything to CSV for R ---
outdir = fullfile(fc_dir, 'exports_csv');
if ~exist(outdir, 'dir'); mkdir(outdir); end

methods = fieldnames(all_fc);

for m = 1:numel(methods)
    method = methods{m};
    validNetworks = validNetworks_used.(method);
    labels_this = cellfun(@(k) networkID_to_label(k), num2cell(validNetworks), 'UniformOutput', false);
    nValid = numel(validNetworks);

    
    writetable(long_fc_data.(method), fullfile(outdir, sprintf('%s_long_fc.csv', method)));


    edge_results = all_edge_results.(method);
    writetable(edge_results, fullfile(outdir, sprintf('%s_edge_results.csv', method)));

    %Mean Adult/Child FC matrices
    adults = all_fc.(method).Adult;
    children = all_fc.(method).Child;
    mean_adult = squeeze(nanmean(adults, 3));
    mean_child = squeeze(nanmean(children, 3));
    T_adult = array2table(mean_adult, 'VariableNames', labels_this, 'RowNames', labels_this);
    T_child = array2table(mean_child, 'VariableNames', labels_this, 'RowNames', labels_this);
    writetable(T_adult, fullfile(outdir, sprintf('%s_mean_adult.csv', method)), 'WriteRowNames', true);
    writetable(T_child, fullfile(outdir, sprintf('%s_mean_child.csv', method)), 'WriteRowNames', true);


    beta_mat = nan(nValid); p_mat = nan(nValid); q_mat = nan(nValid);
    for r = 1:height(edge_results)
        parts = split(edge_results.Edge{r}, '–');  % 'NetA–NetB'
        i = find(strcmp(labels_this, parts{1})); j = find(strcmp(labels_this, parts{2}));
        if isempty(i) || isempty(j), continue; end
        beta_mat(i,j) = -edge_results.Beta(r);       % positive = Adult > Child
        p_mat(i,j)    =  edge_results.pValue(r);
        q_mat(i,j)    =  edge_results.pFDR(r);
    end

    T_beta = array2table(beta_mat, 'VariableNames', labels_this, 'RowNames', labels_this);
    T_p    = array2table(p_mat,    'VariableNames', labels_this, 'RowNames', labels_this);
    T_q    = array2table(q_mat,    'VariableNames', labels_this, 'RowNames', labels_this);
    writetable(T_beta, fullfile(outdir, sprintf('%s_beta_matrix.csv', method)), 'WriteRowNames', true);
    writetable(T_p,    fullfile(outdir, sprintf('%s_p_matrix.csv', method)),    'WriteRowNames', true);
    writetable(T_q,    fullfile(outdir, sprintf('%s_q_matrix.csv', method)),    'WriteRowNames', true);

  
    T_labels = table((1:nValid)', labels_this', validNetworks', 'VariableNames', {'index','label','network_id'});
    writetable(T_labels, fullfile(outdir, sprintf('%s_labels.csv', method)));
end
