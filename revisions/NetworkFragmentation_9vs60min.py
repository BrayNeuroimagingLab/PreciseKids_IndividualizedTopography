#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Network fragmentation per subject at 9 vs 60 min.
Counts contiguous surface clusters (>= 15 mm^2) of each winner-take-all network.
"""
import os
import csv
import numpy as np
import nibabel as nib
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

conte_dir = "/Users/shefalirai/Desktop/Paper3/MATLAB/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb"
data_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
out_csv = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/NetworkFragmentation_9vs60min_LONG.csv"
floor_mm2 = 15.0

networks = {1:"DMN", 2:"VIS", 3:"FP", 5:"DAN", 7:"VAN", 8:"SAL", 9:"CON", 10:"SMd", 11:"SMl", 12:"AUD", 16:"PON"}
subs = [f"{n:03d}" for n in range(2, 27) if n != 3]
child_subs = [f"1973{s}C" for s in subs]
adult_subs = [f"1973{s}P" for s in subs]

# cortex vertex indices and Conte69 per-vertex surface areas
img = nib.load(f"{full_dir}/sub-1973002C_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii")
for name, sl, model in img.header.get_axis(1).iter_structures():
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

def cluster_areas(mask, vtx, adj, areas):
    idx = vtx[mask]
    if len(idx) == 0:
        return np.array([])
    n, lab = connected_components(adj[idx][:, idx], directed=False)
    a = areas[mask]
    return np.array([a[lab == k].sum() for k in range(n)])

def load_wta(subID, length):
    if length == "9min":
        f = f"{data_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_9min_sample1_Dice.dscalar.nii"
    else:
        f = f"{full_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii"
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)[:59412]

rows = []
for group, ids in [("Child", child_subs), ("Adult", adult_subs)]:
    for subID in ids:
        for length in ["9min", "60min"]:
            wta = load_wta(subID, length)
            for net in networks:
                mask = (wta == net)
                cl = np.concatenate([
                    cluster_areas(mask[:n_left], left_vtx, adj_left, vertex_areas[:n_left]),
                    cluster_areas(mask[n_left:n_left + n_right], right_vtx, adj_right, vertex_areas[n_left:n_left + n_right])])
                cl = np.sort(cl)[::-1]
                total = cl.sum()
                big = cl[cl >= floor_mm2]
                rows.append(dict(Subject=f"sub-{subID}", Group=group, Network=networks[net], DataLength=length,
                                 n_clusters_all=len(cl), n_clusters_ge15=len(big),
                                 n_small_lt15=int((cl < floor_mm2).sum()),
                                 largest_frac=(cl[0] / total if total > 0 else np.nan), total_mm2=total))
        print(f"  done {subID}")

with open(out_csv, "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
print("Saved", out_csv)
