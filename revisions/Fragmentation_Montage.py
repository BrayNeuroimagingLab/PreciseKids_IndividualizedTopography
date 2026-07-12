#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Montage of individual DMN topography at 9 vs 60 min, grouped by motion group.
Left-hemisphere lateral view, showing main body (red) and small fragments (yellow).
Every subject in each motion group is displayed.
"""
import os
import warnings
import numpy as np
import nibabel as nib
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from nilearn import plotting
warnings.filterwarnings('ignore')

conte_dir = "/Users/shefalirai/Desktop/Paper3/MATLAB/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb"
frag_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Fragmentation_IndividualDMN"
full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
out_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults"

img = nib.load(f"{full_dir}/sub-1973002C_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii")
for name, sl, model in img.header.get_axis(1).iter_structures():
    if 'CORTEX_LEFT' in name:
        left_vtx = np.array(model.vertex)
        n_left = len(left_vtx)
surf = nib.load(f"{conte_dir}/Conte69.L.inflated.32k_fs_LR.surf.gii")
mesh = (surf.darrays[0].data, surf.darrays[1].data)

groups = {"LMC": [f"1973{n:03d}C" for n in [2, 5, 7, 9, 15, 18, 21, 23, 25, 26]],
          "HMC": [f"1973{n:03d}C" for n in [4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 24]],
          "LMA": [f"1973{n:03d}P" for n in [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 24, 25, 26]]}
cmap = ListedColormap(['#d62728', '#ffd21e'])  # 1 = main body, 2 = small fragment

def left_map(grp, subID, length):
    d = np.asarray(nib.load(f"{frag_dir}/{grp}_sub-{subID}_DMN_{length}_fragments.dscalar.nii").dataobj).squeeze()[:59412]
    v = np.zeros(32492)
    v[left_vtx] = d[:n_left]
    return v

for grp, ids in groups.items():
    n = len(ids)
    fig = plt.figure(figsize=(4.2, 1.7 * n))
    for i, subID in enumerate(ids):
        for j, length in enumerate(["9min", "60min"]):
            ax = fig.add_subplot(n, 2, i * 2 + j + 1, projection='3d')
            plotting.plot_surf_roi(mesh, left_map(grp, subID, length), hemi='left', view='lateral',
                                   cmap=cmap, vmin=1, vmax=2, axes=ax, figure=fig,
                                   colorbar=False, bg_on_data=False, darkness=0.5)
            if i == 0:
                ax.set_title(length.replace('min', ' min'), fontsize=11, fontweight='bold')
            if j == 0:
                ax.text2D(-0.05, 0.5, subID[-4:], transform=ax.transAxes, rotation=90, va='center', fontsize=8)
    fig.suptitle(f"{grp}: DMN, 9 vs 60 min (red = main, yellow = fragment < 15 mm2)", fontsize=11, y=0.995)
    fig.subplots_adjust(wspace=-0.1, hspace=-0.15, top=0.97)
    fig.savefig(f"{out_dir}/Fragmentation_Montage_{grp}.png", dpi=110, bbox_inches='tight')
    plt.close(fig)
    print("saved", grp, f"({n} subjects)")
