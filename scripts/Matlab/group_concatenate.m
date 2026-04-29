function group_concatenate(subID, task)
% Concatenate across all parents or children for each tasks
% subID='allparents' or 'allchildren'

%------------------------------------------------------------------------
%%The following should be added to the matlab path for successful processing
addpath(genpath('~/Programs/matlab/gifti-1.6/'))
addpath(genpath('~/Programs/matlab/BCT'))
addpath(genpath('~/Programs/matlab/cifti_matlab-master'))
wbcommand='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
outputcifti=sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/matlabdir/%s_%s_allsessions.dtseries.nii',subID, task);
%------------------------------------------------------------------------


for subject=1:26
        if subject >=10
            try
                subfile{subject}=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/matlabdir/sub-19730%dC_%s_allsessions.dtseries.nii', subject, task), wbcommand);
                sub{subject}=subfile.cdata;            
            catch
                fprintf('error: file does not exist\n')
            end
        elseif subject<10
            try
                subfile{subject}=ciftiopen(sprintf('/bulk/bray_bulk/Shefali_PreciseKIDS/matlabdir/sub-197300%dC_%s_allsessions.dtseries.nii', subject, task), wbcommand);
                sub{subject}=subfile.cdata;
            catch
                fprintf('error: file does not exist\n')
            end
        else
                fprintf('error: file does not exist\n')
        end
end


allsubs=[sub{1} sub{2} sub{4} sub{5} sub{6} sub{7} sub{8} sub{9} sub{10} sub{11} sub{12} sub{13} sub{14} %skipped sub{3} since excluding for children list
    sub{15} sub{16} sub{17} sub{18} sub{19} sub{20} sub{21} sub{22} sub{23} sub{24} sub{25} sub{26}];

%if needed, save cifti to folder as specified by path above
MSCavg=ciftiopen('/bulk/bray_bulk/Shefali_PreciseKIDS/matlabdir/MSCAveraged_Timeseries.dtseries.nii', wbcommand);
MSCavg.cdata=allsubs;
ciftisave(MSCavg, outputcifti, wbcommand); 

end
