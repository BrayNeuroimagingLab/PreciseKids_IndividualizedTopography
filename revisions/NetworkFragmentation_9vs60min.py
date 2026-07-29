#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Network fragmentation in individualized network maps at 9 vs 60 minutes.
Vertices assigned to the same network are grouped into spatially contiguous clusters
using fs_LR 32k surface adjacency, and clusters >= 15 mm2 are kept as fragments.
Cluster areas use Conte69 group midthickness vertex areas, so the 15 mm2 floor means
the same thing in every participant. Writes one long-format row per
subject x network x data length.
"""
import numpy as np
import pandas as pd
import nibabel as nib
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

data9_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
conte_dir = "/Users/shefalirai/Desktop/Paper3/MATLAB/PRCKIDS_1973_Scripts/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb"
out_csv = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/NetworkFragmentation_9vs60min_LONG.csv"

min_area = 15  # mm2, drops single-vertex speckle
n_hemi = 32492
networks = {1: "DMN", 2: "VIS", 3: "FP", 5: "DAN", 7: "VAN", 8: "SAL",
            9: "CON", 10: "SMd", 11: "SMl", 12: "AUD", 16: "PON"}
subs = [f"1973{n:03d}{s}" for n in range(2, 27) if n != 3 for s in ["C", "P"]]

# Conte69 midthickness vertex areas and triangles (fs_LR 32k, vertex-matched across subjects)
vertex_area = {}
adjacency = {}
for hemi in ("L", "R"):
    vertex_area[hemi] = nib.load(f"{conte_dir}/Conte69.{hemi}.midthickness.32k_fs_LR_surfaceareas.func.gii").darrays[0].data
    tri = nib.load(f"{conte_dir}/Conte69.{hemi}.midthickness.32k_fs_LR.surf.gii").darrays[1].data
    edges = np.vstack([tri[:, [0, 1]], tri[:, [1, 2]], tri[:, [0, 2]]])
    edges = np.vstack([edges, edges[:, ::-1]])  # undirected
    adjacency[hemi] = coo_matrix((np.ones(len(edges)), (edges[:, 0], edges[:, 1])),
                                 shape=(n_hemi, n_hemi)).tocsr()

# cortex vertex indices per hemisphere, taken from the CIFTI brain models
tmpl = nib.load(f"{full_dir}/sub-1973002C_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii")
cortex = {}
for bm in tmpl.header.get_index_map(1).brain_models:
    if bm.brain_structure == "CIFTI_STRUCTURE_CORTEX_LEFT":
        cortex["L"] = (np.array(bm.vertex_indices), bm.index_offset, bm.index_count)
    if bm.brain_structure == "CIFTI_STRUCTURE_CORTEX_RIGHT":
        cortex["R"] = (np.array(bm.vertex_indices), bm.index_offset, bm.index_count)

def load_wta(subID, length):
    if length == "9min":
        f = f"{data9_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_9min_sample1_Dice.dscalar.nii"
    else:
        f = f"{full_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii"
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)

def cluster_areas(wta, net):
    """Area of every spatially contiguous cluster of one network, both hemispheres."""
    areas = []
    for hemi in ("L", "R"):
        verts, offset, count = cortex[hemi]
        on_surface = np.zeros(n_hemi, dtype=bool)
        on_surface[verts] = wta[offset:offset + count] == net
        sel = np.where(on_surface)[0]
        if len(sel) == 0:
            continue
        n_clust, labels = connected_components(adjacency[hemi][sel][:, sel], directed=False)
        areas += [vertex_area[hemi][sel[labels == k]].sum() for k in range(n_clust)]
    return np.array(areas)

rows = []
for subID in subs:
    group = "Child" if subID.endswith("C") else "Adult"
    for length in ("9min", "60min"):
        wta = load_wta(subID, length)
        for net, net_name in networks.items():
            areas = cluster_areas(wta, net)
            rows.append({"Subject": f"sub-{subID}",
                         "Group": group,
                         "Network": net_name,
                         "DataLength": length,
                         "n_clusters_all": len(areas),
                         "n_clusters_ge15": int((areas >= min_area).sum()),
                         "n_small_lt15": int((areas < min_area).sum()),
                         "largest_frac": float(areas.max() / areas.sum()),
                         "total_mm2": float(areas.sum())})
    print(f"{subID} done")

pd.DataFrame(rows).to_csv(out_csv, index=False)
print(f"Saved -> {out_csv}")
