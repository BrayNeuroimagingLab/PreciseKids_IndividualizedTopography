% Figure3_MotionGroups_DensityMaps.m
%
% 15 mins sample 1 and sample 2 for HMC
% from: HMC_DensityMaps_15min.py and uses wb_command to VIZ
%


wbcommand  = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
density_dir = '/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/HMC_15min_DensityMaps/';

networks = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

n_subjects = struct('HMC', 14);
groups = 'HMC';
samples = {'sample1', 'sample2'};

for s = 1:length(samples)
    grp  = groups;
    n_max = n_subjects.(grp);
    smpl = samples{s};

    for net = networks
        in_file = fullfile(density_dir, sprintf('Network%d_%s_15min_%s_density.dscalar.nii', net, grp, smpl));

        if ~exist(in_file, 'file')
            fprintf('Missing: %s\n', in_file);
            continue;
        end

        palette_cmd = sprintf(['%s -cifti-palette %s MODE_AUTO_SCALE ' ...
            '-palette-name "ROY-BIG-BL" ' ...
            '-disp-pos true -disp-neg false -disp-zero false ' ...
            '-pos-user 1 %d ' ...
            '%s'], ...
            wbcommand, in_file, n_max, in_file);

        status = system(palette_cmd);
        if status ~= 0
            fprintf('Warning: palette command failed for %s %s net%d\n', grp, net);
        end
    end
    fprintf('Palette set for %s (%d subjects)\n', grp, n_max);
end


