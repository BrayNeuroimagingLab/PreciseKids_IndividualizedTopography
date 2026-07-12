% Figure3_MotionGroups_DensityMaps.m
%
% Loads the per-network density dscalars for LMA, LMC, and HMC
% (created by CreateMotionGroup_DensityMaps.py) and uses wb_command to VIZ
%


wbcommand  = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
density_dir = '/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/PKWTA_MotionGroups_OverlapMaps';

networks = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

n_subjects = struct('LMA', 22, 'LMC', 10, 'HMC', 14);
groups     = {'LMA', 'LMC', 'HMC'};

for g = 1:length(groups)
    grp      = groups{g};
    n_max    = n_subjects.(grp);

    for net = networks
        in_file = fullfile(density_dir, sprintf('Network%d_%s_density.dscalar.nii', net, grp));

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


