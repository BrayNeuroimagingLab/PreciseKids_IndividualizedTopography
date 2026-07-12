% Run CreateMotionGroup / MakeProportion_FromDensity_60min.py first.
% After this, open the *_proportion.dscalar.nii files in wb_view to make the figure.

wbcommand   = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
density_dir = '/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/PKWTA_MotionGroups_OverlapMaps';

networks = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
groups   = {'LMA', 'LMC', 'HMC'};

% Common scale for all groups. Colorbar label in the figure = "Proportion 0-1".
scale_min = 0;
scale_max = 1;

% Rainbow look matching the original Figure 3 density maps. If your Figure 3
% used a different palette, change this name (e.g. 'ROY-BIG-BL', 'videen_style').
palette = 'JET256';

for g = 1:length(groups)
    grp = groups{g};
    for net = networks
        in_file = fullfile(density_dir, sprintf('Network%d_%s_proportion.dscalar.nii', net, grp));
        if ~exist(in_file, 'file')
            fprintf('Missing: %s\n', in_file);
            continue;
        end
        palette_cmd = sprintf(['%s -cifti-palette %s MODE_USER_SCALE ' ...
            '-palette-name "%s" ' ...
            '-disp-pos true -disp-neg false -disp-zero false ' ...
            '-pos-user %g %g ' ...
            '%s'], ...
            wbcommand, in_file, palette, scale_min, scale_max, in_file);
        status = system(palette_cmd);
        if status ~= 0
            fprintf('Warning: palette failed for %s net%d\n', grp, net);
        end
    end
    fprintf('Common 0-1 proportion palette set for %s\n', grp);
end

fprintf('\nDone. Open the *_proportion.dscalar.nii files in wb_view; all three\n');
fprintf('groups now share a 0-1 scale so overlap is directly comparable.\n');
