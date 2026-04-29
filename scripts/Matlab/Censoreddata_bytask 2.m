
wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
%open 
task='DORA';
subject='P';

for sub=2:26
        if sub >=10
            try
                censoredptseries{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_matlabdir/censored_allses_ptseries/sub-19730%d%s_%s_allsessions_Gordon333parcels_censored.ptseries.nii', sub, subject, task)),wbcommand); 
                censoredptseries{sub}=censoredptseries{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        elseif sub <10
            try
                censoredptseries{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_matlabdir/censored_allses_ptseries//sub-197300%d%s_%s_allsessions_Gordon333parcels_censored.ptseries.nii', sub, subject, task)),wbcommand);
                censoredptseries{sub}=censoredptseries{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        else
            try
                censoredptseries{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_matlabdir/censored_allses_ptseries/sub-1973%d%s_%s_allsessions_Gordon333parcels_censored.ptseries.nii', sub, subject, task)),wbcommand);
                censoredptseries{sub}=censoredptseries{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        end
end

%% determine highest data for each task

% Get column size for each subject
for sub = 1:26
    if ~isempty(censoredptseries{sub})
        [~, cols] = size(censoredptseries{sub});
        column_sizes(sub) = cols;
    end
end

% Find max and its index
[max_cols, max_sub] = max(column_sizes);
% Sort from highest to lowest
[sorted_cols, sorted_idx] = sort(column_sizes, 'descend');

% Print results
fprintf('Subject %d has the most columns: %d\n', max_sub, max_cols);

% Print all subjects from highest to lowest (excluding zeros/empty subjects)
fprintf('\nAll subjects ordered by number of columns:\n');
for i = 1:length(sorted_cols)
    if sorted_cols(i) > 0  % Only print subjects that have data
        fprintf('Subject %d: %d columns\n', sorted_idx(i), sorted_cols(i));
    end
end

