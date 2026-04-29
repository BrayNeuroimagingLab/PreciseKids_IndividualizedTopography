%HCP Overlap reference map of all networks to compare with Sun et al 2025 

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
basedir = '/Users/shefalirai/Desktop/PK_networkassignment/OriginalHCP_DlabelTemplate/HCPtemplate_overlap/';
output_dir = basedir;

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

networks = [1:3, 5, 7:16];  
n_networks = length(networks);

combined_map = [];  
template_ref = [];  

for net = networks
    hcpname = sprintf('HCPnetwork%d_overlap.dscalar.nii', net);
    map = ciftiopen(fullfile(basedir, hcpname), wbcommand);


    if isempty(template_ref)
        template_ref = map;
        n_verts = size(map.cdata, 1);
        combined_map = zeros(n_verts, 1);
    end

    % Replace 1s with the network ID
    bin_map = map.cdata;  % binary (0 or 1)
    relabeled = bin_map * net;  % now 0 or net ID
    
    update_mask = (relabeled > 0) & (combined_map == 0);
    combined_map(update_mask) = relabeled(update_mask);

end

% Save the combined map
template_ref.cdata = combined_map;
outname = fullfile(output_dir, 'HCPOverlap_AllNetworkReference.dscalar.nii');
ciftisavereset(template_ref, outname, wbcommand);
fprintf('Saved combined HCP overlap map to: %s\n', outname);
