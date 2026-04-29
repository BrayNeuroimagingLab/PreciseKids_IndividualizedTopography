
wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';

subject='P';
task='task-RX';

%open each individual spatial variant
for sub=2:26
        if sub >=10
            try
                spatvar{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_spatialcorr/sub-19730%d%s_%s_allsessions_15RM_spatialCorrMap.dtseries.nii', sub, subject, task)),wbcommand);
                spatvar{sub}=spatvar{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        elseif sub <10
            try
                spatvar{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_spatialcorr/sub-197300%d%s_%s_allsessions_15RM_spatialCorrMap.dtseries.nii', sub, subject, task)),wbcommand);
                spatvar{sub}=spatvar{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        else
            try
                spatvar{sub}=ciftiopen((sprintf('/Volumes/Prckids2/newmc_spatialcorr/sub-1973%d%s_%s_allsessions_15RM_spatialCorrMap.dtseries.nii', sub, subject, task)),wbcommand);
                spatvar{sub}=spatvar{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        end
end

neighLoc = '/Volumes/Prckids2/newmc_spatialcorr';
neigh = load([neighLoc '/Cifti_surf_neighbors_LR_normalwall.mat']);
neigh = neigh.neighbors;

% compute binary spatial variant map less than 0.1 threshold
for sub=2:26
    try
        cThresh = 0.1;
        sorted{sub}=sort(spatvar{sub});
        cThresh_new{sub} = sorted{sub}(floor(cThresh*length(sorted{sub})));
        binData{sub} = logical(spatvar{sub} < cThresh_new{sub});
    catch
        fprintf('error: subject does not exist\n')
    end
end

% compute average of all spatial variant maps excluding each subject
spatvar_avg_sub002C = cat(3,spatvar{3:26});
spatvar_avg_sub002C = mean(spatvar_avg_sub002C,3);

spatvar_avg_sub026P = cat(3,spatvar{2:25});
spatvar_avg_sub026P = mean(spatvar_avg_sub026P,3);

% compute binary spatial variant map less than 0.1 threshold and average spatvar is 0.5
cThresh = 0.1;
sorted{2}=sort(spatvar{2});
cThresh_new{2} = sorted{2}(floor(cThresh*length(sorted{2})));
binData_realvariant_002C = logical(spatvar{2} < cThresh_new{2} & spatvar_avg_sub002C > 0.5);

cThresh = 0.1;
sorted{26}=sort(spatvar{26});
cThresh_new{26} = sorted{26}(floor(cThresh*length(sorted{26})));
binData_realvariant_026P = logical(spatvar{26} < cThresh_new{26} & spatvar_avg_sub026P > 0.5);

template = ft_read_cifti_mod('/Volumes/Prckids2/newmc_spatialcorr/sub-1973026P_task-RX_allsessions_15RM_spatialCorrMap.dtseries.nii');
template.data = binData_realvariant_026P;
ft_write_cifti_mod('/Volumes/Prckids2/newmc_spatialcorr/sub-1973026P_task-RX_allsessions_15RM_spatialCorrMap_comparedtoaverage.dtseries.nii', template);




