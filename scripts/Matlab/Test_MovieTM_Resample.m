

wbcommand = '/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command';
%Open
dscalar =ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Network16_difference.dscalar.nii',wbcommand);
dscalar_data = dscalar.cdata;

%Save
for networks = 1:24
    dscalar.cdata=dscalar_data(:,networks);
    ciftisavereset(dscalar, sprintf('/Users/shefalirai/Desktop/PK_networkassignment/MovieParcellation_Km_V6D4z/moviescalar91282_network%d.dscalar.nii', networks), wbcommand);
end

%Test open cifti
dscalar2 =ciftiopen('/Users/shefalirai/Desktop/PK_networkassignment/MovieParcellation_Km_V6D4z/moviescalar91282_network16.dscalar.nii',wbcommand);
dscalar2_data = dscalar2.cdata;