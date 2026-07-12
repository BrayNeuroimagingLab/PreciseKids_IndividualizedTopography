% From CreateMotionGroup_DensityDiffMaps_60vs9min.py
%
% Each map = proportion_60min - proportion_9min, range -1..+1, centered at 0:
%   positive (red)  = network assignment MORE prevalent at 60 min
%   negative (blue) = network assignment MORE prevalent at 9 min
%
% LMA, LMC, and HMC

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
diff_dir  = '/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/PKWTA_MotionGroups_DensityDiff_60vs9min';

networks = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16];
groups   = {'LMA', 'LMC', 'HMC'};

% symmetric diverging scale around zero — adjust the bound if your printed
% diff ranges (from the .py output) suggest a tighter/looser scale
diff_bound = 0.5;

for g = 1:length(groups)
    grp = groups{g};

    for k = 1:length(networks)
        net = networks(k);

        in_file = fullfile(diff_dir, ...
            sprintf('Network%d_%s_diff_60vs9min.dscalar.nii', net, grp));

        if ~exist(in_file, 'file')
            fprintf('Missing: %s\n', in_file);
            continue;
        end

        palette_cmd = sprintf(['%s -cifti-palette %s MODE_USER_SCALE ' ...
            '-palette-name "ROY-BIG-BL" ' ...
            '-disp-pos true -disp-neg true -disp-zero false ' ...
            '-pos-user 0 %.2f -neg-user 0 -%.2f ' ...
            '%s'], ...
            wbcommand, in_file, diff_bound, diff_bound, in_file);

        status = system(palette_cmd);
        if status ~= 0
            fprintf('Warning: palette command failed for %s net%d\n', grp, net);
        end
    end
    fprintf('Palette set for %s (diverging, +/- %.2f)\n', grp, diff_bound);
end

fprintf('\nDone..', diff_dir);

