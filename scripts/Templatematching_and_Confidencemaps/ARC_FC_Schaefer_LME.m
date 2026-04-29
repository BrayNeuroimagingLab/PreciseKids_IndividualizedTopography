% FC_Schaefer_SimilarityMatrix.m

disp('Building whole-connectome similarity matrix for 1000x1000 Schaefer data...');

fc_dir = '/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir/';
files = dir(fullfile(fc_dir, '*_fc_table_template_Schaefer.mat'));
nParcels = 1000;
nEdges = nParcels * (nParcels - 1) / 2;  % upper tri
nSubjects = length(files);

% Load behavioral data
beh_table = readtable(fullfile(fc_dir, 'prckids-task_beh.xlsx'));
beh_table.sub = strcat('sub-', string(beh_table.sub));


all_vectors = nan(nEdges, nSubjects);
subj_ids = cell(1, nSubjects);
group_labels = cell(1, nSubjects);


for i = 1:nSubjects
    fname = files(i).name;
    load(fullfile(fc_dir, fname), 'fc_table');
    tokens = regexp(fname, 'sub-(\d{7}[CP])', 'tokens');
    if isempty(tokens), continue; end
    subjID = tokens{1}{1};
    subj_ids{i} = ['sub-' subjID];
    group_labels{i} = 'Child'; if endsWith(subjID, 'P'), group_labels{i} = 'Adult'; end

    mat = nan(nParcels);
    for j = 1:height(fc_table)
        a = fc_table.NetworkA(j); b = fc_table.NetworkB(j); val = fc_table.FC(j);
        if iscell(val), val = val{1}; end
        if ischar(val), val = str2double(val); end
        if isfinite(val)
            mat(a,b) = val;
            mat(b,a) = val;
        end
    end

    
    vec = mat(triu(true(nParcels),1));
    all_vectors(:, i) = vec;
end

% Convert group to cat
group_labels = categorical(group_labels);
subj_ids = string(subj_ids);

% Compute P Corr
similarity_matrix = corr(all_vectors, 'Rows', 'pairwise');  % 48 x 48

% Save results
save(fullfile(fc_dir, 'Schaefer1000_similarity_matrix.mat'), ...
     'similarity_matrix', 'subj_ids', 'group_labels');

csvwrite(fullfile(fc_dir, 'Schaefer1000_similarity_matrix.csv'), similarity_matrix);

disp('Done.');

exit;
