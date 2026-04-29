wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

basedir = '/Users/shefalirai/Desktop/PK_networkassignment/OriginalHCP_DlabelTemplate/';
output_dir = fullfile(basedir, 'OriginalUnThresh_OverlapMaps_thresh0.01');
adult_prefix = 'dworetsky-hcp';
child_prefix = 'hcp-d_ages08-09';

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Network
networks = {'Vis','VAN','Tpole','Sal','SMl','SMd','PON','PMN','MTL','FP','DMN','DAN','CO','Aud'};

% Load template
template = ciftiopen(fullfile(basedir, sprintf('%s_%s_thresh0.01.dscalar.nii', adult_prefix, networks{1})), wbcommand);
n_verts = 59412; % surface vertices only

for i = 1:length(networks)
    net = networks{i};

    % Load files
    adult_file = fullfile(basedir, sprintf('%s_%s_thresh0.01.dscalar.nii', adult_prefix, net));
    child_file = fullfile(basedir, sprintf('%s_%s_thresh0.01.dscalar.nii', child_prefix, net));

    % Load data
    raw_adult = ciftiopen(adult_file, wbcommand).cdata > 0;
    adult_data = single(raw_adult(:,1) | raw_adult(:,2));  

    raw_child = ciftiopen(child_file, wbcommand).cdata > 0;
    child_data = single(raw_child(:,1) | raw_child(:,2));  
    child_data = child_data(1:n_verts);

    % Build overlap map
    overlap_map = zeros(n_verts, 1);
    overlap_map(adult_data & ~child_data) = 1;
    overlap_map(child_data & ~adult_data) = 2;
    overlap_map(adult_data & child_data) = 3;

    % Save result
    template.cdata = overlap_map;
    outname = fullfile(output_dir, sprintf('Overlap_%s_thresh0.01_Adults1_Children2_Both3.dscalar.nii', net));
    ciftisavereset(template, outname, wbcommand);
    fprintf('Saved: %s\n', outname);
end

