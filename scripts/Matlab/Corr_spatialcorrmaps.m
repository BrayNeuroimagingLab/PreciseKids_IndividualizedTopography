function spatialcorrmap = Corr_spatialcorrmaps(subject, task)
%subject is either 'C' or 'P' depending on if you are running on child or parent 
%open all original spatial corrlelation maps (unthresholded) from ARC across
%all children and parents


wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
%open each individual spatial variant
for sub=2:26
        if sub >=10
            try
                spatialcorrmap{sub}=ciftiopen((sprintf('/Volumes/Prckids2/spatialcorr/sub-19730%d%s_%s_allsessions_RM_spatialCorrMap.dtseries.nii', sub, subject, task)),wbcommand);
                spatialcorrmap{sub}=spatialcorrmap{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        elseif sub <10
            try
                spatialcorrmap{sub}=ciftiopen((sprintf('/Volumes/Prckids2/spatialcorr/sub-197300%d%s_%s_allsessions_RM_spatialCorrMap.dtseries.nii', sub, subject, task)),wbcommand);
                spatialcorrmap{sub}=spatialcorrmap{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        else
            try
                spatialcorrmap{sub}=ciftiopen((sprintf('/Volumes/Prckids2/spatialcorr/sub-1973%d%s_%s_allsessions_RM_spatialCorrMap.dtseries.nii', sub, subject, task)),wbcommand);
                spatialcorrmap{sub}=spatialcorrmap{sub}.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        end
end

%Delete rows 1 and 3 before continuing, since there is no 001 family and
%003C is excluded from analysis


% %correlation 
% for ncoeff = 1:24
%     for ncross = 1:24
%         try
%             fprintf('now correlating child %d and parent %d', ncoeff, ncross);
%             % Calculate the correlation
%             allcorr(ncoeff, ncross) = corr(spatialcorrmapP_RX{1,ncoeff}, spatialcorrmapP_RX{1,ncross});
%         catch
%             fprintf('error in corr function \n')
%         end
%     end
% end
% 
% imagesc(allcorr)

% %mean of upper traingular matrix for child
% spatialcorrmapCflip = spatialcorrmapC_RX';
% uppervector = tril(true(size(spatialcorrmapCflip)));
% spatialcorrmapCvector = spatialcorrmapCflip(uppervector);
% spatialcorrmapCvector_mean = mean(cell2mat(spatialcorrmapCvector));
% 
% %mean of upper traingular matrix for parents
% spatialcorrmapPflip = spatialcorrmapP_RX';
% uppervector = tril(true(size(spatialcorrmapPflip)));
% spatialcorrmapPvector = spatialcorrmapPflip(uppervector);
% spatialcorrmapPvector_mean = mean(cell2mat(spatialcorrmapPvector));


end

