#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Individual DMN fragment maps at 9 and 60 min, for all motion-group subjects.
Each vertex is labelled 1 (main body) or 2 (small fragment < 15 mm^2).
"""
import os
import numpy as np
import nibabel as nib
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

conte_dir = "/Users/shefalirai/Desktop/Paper3/MATLAB/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb"
data_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
out_dir = f"{full_dir}/Fragmentation_IndividualDMN"
os.makedirs(out_dir, exist_ok=True)
floor_mm2 = 15.0
net = 1  # DMN

groups = {"LMC": [f"1973{n:03d}C" for n in [2, 5, 7, 9, 15, 18, 21, 23, 25, 26]],
          "HMC": [f"1973{n:03d}C" for n in [4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 24]],
          "LMA": [f"1973{n:03d}P" for n in [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 24, 25, 26]]}

tmpl = nib.load(f"{full_dir}/sub-1973002C_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii")
for name, sl, model in tmpl.header.get_axis(1).iter_structures():
    if 'CORTEX_LEFT' in name:
        left_vtx = np.array(model.vertex)
        n_left = len(left_vtx)
    if 'CORTEX_RIGHT' in name:
        right_vtx = np.array(model.vertex)
        n_right = len(right_vtx)
aL = nib.load(f"{conte_dir}/Conte69.L.midthickness.32k_fs_LR_surfaceareas.func.gii").darrays[0].data
aR = nib.load(f"{conte_dir}/Conte69.R.midthickness.32k_fs_LR_surfaceareas.func.gii").darrays[0].data
vertex_areas = np.concatenate([aL[left_vtx], aR[right_vtx]]).astype(float)

def surface_adjacency(surf_file, nv=32492):
    faces = nib.load(surf_file).darrays[1].data
    edges = np.vstack([faces[:, [0, 1]], faces[:, [1, 2]], faces[:, [0, 2]]])
    r = np.concatenate([edges[:, 0], edges[:, 1]])
    c = np.concatenate([edges[:, 1], edges[:, 0]])
    return coo_matrix((np.ones(len(r), bool), (r, c)), shape=(nv, nv)).tocsr()

adj_left = surface_adjacency(f"{conte_dir}/Conte69.L.midthickness.32k_fs_LR.surf.gii")
adj_right = surface_adjacency(f"{conte_dir}/Conte69.R.midthickness.32k_fs_LR.surf.gii")

def label_fragments(mask, vtx, adj, areas, out):
    idx = vtx[mask]
    if len(idx) == 0:
        return
    n, lab = connected_components(adj[idx][:, idx], directed=False)
    sizes = np.array([areas[mask][lab == k].sum() for k in range(n)])
    out[mask] = np.where(sizes[lab] >= floor_mm2, 1, 2)

def load_wta(subID, length):
    if length == "9min":
        f = f"{data_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_9min_sample1_Dice.dscalar.nii"
    else:
        f = f"{full_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii"
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)[:59412]

for grp, ids in groups.items():
    for subID in ids:
        for length in ["9min", "60min"]:
            wta = load_wta(subID, length)
            mask = (wta == net)
            lab = np.zeros(59412, dtype=np.float32)
            label_fragments(mask[:n_left], left_vtx, adj_left, vertex_areas[:n_left], lab[:n_left])
            label_fragments(mask[n_left:n_left + n_right], right_vtx, adj_right, vertex_areas[n_left:n_left + n_right], lab[n_left:n_left + n_right])
            full = np.zeros(91282, dtype=np.float32)
            full[:59412] = lab
            nib.save(nib.Cifti2Image(full.reshape(1, -1), header=tmpl.header, nifti_header=tmpl.nifti_header),
                     f"{out_dir}/{grp}_sub-{subID}_DMN_{length}_fragments.dscalar.nii")
    print("done", grp)
