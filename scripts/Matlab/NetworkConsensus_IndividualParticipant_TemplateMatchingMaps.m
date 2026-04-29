function NetworkConsensus_IndividualParticipant_TemplateMatchingMaps(path_to_probability_maps_list,run_locally,output_name, participant_group)

%This code is modified from the following source: https://github.com/DCAN-Labs/compare_matrices_to_assign_networks/tree/main
%This function loads a list of probabilistic maps and generates a
%whole-brain parecelation schema based on the highest region with the
%highest probability.

%inputs are: 
%path_to_probability_maps_list= a list of dcscalars that are probabilistic
%maps.
%assumed network order in conc file. =  {'DMN','Vis','FP','DAN','VAN','Sal','CO','SMd','SML','AUD', 'Tpole', 'MTL','PMN','PON'};
%run_locally, set to 1 if your Robert and running this on your local %edited for Shefali's paths =1 
%computer. Otherwise set to 0. (This option points to cifti dependencies.)
%output_name= full output name. i.e. /path/to/my/dscalar.nii
%run_clean_up_script= remove small islands of networks smaller than 20 grayordinates. % Shefali edits: we do not run this currently 

%Shefali notes:
%Example: NetworkConsensus_IndividualParticipant_TemplateMatchingMaps('/Users/shefalirai/Desktop/PK_networkassignment/Parent_alltasks_listofnetworkdscalars.txt', 1, '/Users/shefalirai/Desktop/PK_networkassignment/Parent_alltasks_templatematchingnetworkconsensus', 'Parent');
%OR
%For Dice: NetworkConsensus_IndividualParticipant_TemplateMatchingMaps('/Users/shefalirai/Desktop/PK_networkassignment/DiceSimilarity_TemplateMatching/Parent_alltasks_listofnetworkdscalars.txt', 1,  '/Users/shefalirai/Desktop/PK_networkassignment/DiceSimilarity_TemplateMatching/Parent_alltasks_templatematchingnetworkconsensus_Dice', 'Parent');
%Network label number & order: networks = {'DMN-1','VIS-2', 'FP-3', 4 - N/A, 'DAN-5', 6 - N/A ,'VAN-7','SAL-8','CON-9','SMd-10','SMl-11', 'AUD-12', 'Tpole-13', 'MTL-14','PMN-15','PON-16'};


%% Adding paths for this function
this_code = which('brain_gerrymander');
[code_dir,~] = fileparts(this_code);
support_folder=[code_dir filesep 'support_folder']; %find support files in the code directory.
%support_folder=[pwd '/support_files'];
addpath(genpath(support_folder));

if run_locally ==1
    %Some hardcodes:
    wb_command = ('/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command');
    addpath('/Users/shefalirai/Documents/MATLAB/PRCKIDS_1973_Scripts/PK_Paper2/compare_matrices_to_assign_networks-main')
else
    settings=settings_comparematrices;%
    np=size(settings.path,2);
    warning('off') %supress addpath warnings to nonfolders.
    for i=1:np
        addpath(genpath(settings.path{i}));
    end
    rmpath('/mnt/max/shared/code/external/utilities/MSCcodebase/Utilities/read_write_cifti') % remove non-working gifti path included with MSCcodebase
    rmpath('/home/exacloud/fnl_lab/code/external/utilities/MSCcodebase/Utilities/read_write_cifti')
    wb_command=settings.path_wb_c; %path to wb_command
    warning('on')
end

%%Step 1
%Load data
probability_maps_list = importdata(path_to_probability_maps_list);
probability_mat = zeros(91282, size(probability_maps_list,1));
for i=1:size(probability_maps_list,1)
    disp(['Loading subjects' num2str(i)])
    this_nets_path = probability_maps_list{i};
    cii=ciftiopen(this_nets_path,wb_command);
    this_net_probability = cii.cdata;
    probability_mat(:,i) = this_net_probability;
    
end

%%Step 2 find network of max probability at each grayordinate.

[~, max_vals] = max(probability_mat,[],2);
max_vals = max_vals';
%Step 2.5 adjust network indicies to account for no network 4 or 6.

greater_than_3 = find(max_vals >3);
max_vals(greater_than_3) = max_vals(greater_than_3)+1;

greater_than_5 = find(max_vals >5);
max_vals(greater_than_5) = max_vals(greater_than_5)+1;


%% save dscalar
cii.cdata = max_vals';
if strcmp(output_name(end-11:end),'dscalar.nii') ==0
    ciftisavereset(cii,[output_name '.dscalar.nii'],wb_command)
    output_name =[output_name '.dscalar.nii'];
else
    ciftisavereset(cii, output_name, wb_command)
end

disp(['Saved first dscalar consensus map output called ' output_name])


%% Creat consensus network map 

[vert, sub] = size(probability_mat);
new_consensus_mat = zeros(vert, 1); % Initialize the new consensus matrix

threshold = 0.66 * sub; % Threshold for agreement

for vertices = 1:vert
    count = zeros(16, 1); % Initialize count for each network
    for subs = 1:sub
        network = probability_mat(vertices, subs);
        count(network) = count(network) + 1;
    end
    % Check which network has the highest count
    [max_count, max_net] = max(count);
    % If there is no clear consensus (e.g., ties), set to 0
    if max_count < threshold
        new_consensus_mat(vertices) = 0;
    else
        new_consensus_mat(vertices) = max_net;
    end
end


% save consensus matrices
cii.cdata=new_consensus_mat;
Con_Network_output =['/Users/shefalirai/Desktop/PK_networkassignment/DiceSimilarity_TemplateMatching/' participant_group '_alltasks_templatematching_66percent_networkconsensusmap_Dice.dscalar.nii'];
ciftisavereset(cii, Con_Network_output, wb_command);

disp(['Done. Saved second dscalar 66% consensus map output called ' Con_Network_output])


%% Creat consensus network map for both adults and children, if needed

% both_probability_mat = [probability_mat probability_mat2];
% [vert, sub] = size(both_probability_mat);
% new_consensus_mat = zeros(vert, 1); % Initialize the new consensus matrix
% 
% threshold = 0.66 * sub; % Threshold for agreement
% 
% for vertices = 1:vert
%     count = zeros(16, 1); % Initialize count for each network
%     for subs = 1:sub
%         network = both_probability_mat(vertices, subs);
%         count(network) = count(network) + 1;
%     end
%     % Check which network has the highest count
%     [max_count, max_net] = max(count);
%     % If there is no clear consensus (e.g., ties), set to 0
%     if max_count < threshold
%         new_consensus_mat(vertices) = 0;
%     else
%         new_consensus_mat(vertices) = max_net;
%     end
% end
% 
% % save consensus matrices
% cii.cdata=new_consensus_mat;
% Con_Network_output ='BothParentandChild_templatematching_66percent_networkconsensusmap.dscalar.nii';
% ciftisavereset(cii, Con_Network_output, wb_command);


%% Create third consensus matrix between child and parent 

parent_consensus=ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/DiceSimilarity_TemplateMatching/Parent_alltasks_templatematching_66percent_networkconsensusmap_Dice.dscalar.nii', wb_command);
child_consensus=ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/DiceSimilarity_TemplateMatching/Child_alltasks_templatematching_66percent_networkconsensusmap_Dice.dscalar.nii', wb_command);

parent_consensus_data=parent_consensus.cdata;
child_consensus_data=child_consensus.cdata;

% Create third consensus matrix between adult and child
consensus = parent_consensus_data .* (parent_consensus_data == child_consensus_data);
consensus(parent_consensus_data ~= child_consensus_data) = NaN;

% save 3rd consensus matrices
parent_consensus.cdata=consensus;
Con3_Network_output = '/Users/shefalirai/Desktop/PK_networkassignment/DiceSimilarity_TemplateMatching/Thirdconsensus_adultchildcombined_templatematching_66percent_networkconsensusmap_Dice.dscalar.nii';
ciftisavereset(parent_consensus, Con3_Network_output, wb_command);



end