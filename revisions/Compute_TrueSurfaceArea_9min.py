#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Area-weighted network surface-area proportions at 9 and 60 min.
Per-vertex surface area (individual midthickness) is summed under each subject's
9-min and 60-min assignment. Vertex areas are anatomy, so both data lengths use
the same areas and are directly comparable.
"""
import os
import numpy as np
import nibabel as nib
import pandas as pd

# per-vertex area source (external drive)
sa_dir = "/Volumes/Prckids2/EachSub_NetworkAssignment/"
left_cortex = os.path.join(sa_dir, "leftcortex.txt")  # col 1 = L cortex vertex indices (29696)
right_cortex = os.path.join(sa_dir, "rightcortex.txt")  # col 1 = R cortex vertex indices (29716)

assign_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata/"
full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
out_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
out_csv = os.path.join(out_dir, "TrueSurfaceArea_9vs60min_persubject.csv")

n_cortex = 59412
sample = "sample1"

child_nums = [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
adult_nums = [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
subjects = ([(f"1973{n:03d}C", "Child") for n in child_nums] +
            [(f"1973{n:03d}P", "Adult") for n in adult_nums])

net_labels = {1: "DMN", 2: "VIS", 3: "FP", 5: "DAN", 7: "VAN", 8: "SAL",
              9: "CON", 10: "SMd", 11: "SMl", 12: "AUD", 16: "PON"}
networks = list(net_labels.keys())

left_idx = np.loadtxt(left_cortex, dtype=int, usecols=1)
right_idx = np.loadtxt(right_cortex, dtype=int, usecols=1)


def load_area_vector(subID):
    txt = os.path.join(sa_dir, f"sub-{subID}_LRcortexvertices_surfacearea.txt")
    if os.path.exists(txt):
        v = np.loadtxt(txt)
        return v if v.shape[0] == n_cortex else None
    Lf = os.path.join(sa_dir, f"sub-{subID}.L.midthickness.32k_fs_LR_SURFACEAREA.shape.gii")
    Rf = os.path.join(sa_dir, f"sub-{subID}.R.midthickness.32k_fs_LR_SURFACEAREA.shape.gii")
    if not (os.path.exists(Lf) and os.path.exists(Rf)):
        return None
    L = nib.load(Lf).darrays[0].data
    R = nib.load(Rf).darrays[0].data
    v = np.concatenate([L[left_idx], R[right_idx]])
    return v if v.shape[0] == n_cortex else None


def load_assignment(path):
    if not os.path.exists(path):
        return None
    return np.round(np.asarray(nib.load(path).dataobj).squeeze()).astype(int)[:n_cortex]


def pct_by_network(area, assign):
    total = area[np.isin(assign, networks)].sum()
    return {net_labels[n]: 100.0 * area[assign == n].sum() / total for n in networks}


rows, missing = [], []
for subID, group in subjects:
    area = load_area_vector(subID)
    a9 = load_assignment(os.path.join(assign_dir, f"sub-{subID}_alltasks_HCPAdultChild_overlap_9min_{sample}_Dice.dscalar.nii"))
    a60 = load_assignment(os.path.join(full_dir, f"sub-{subID}_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii"))
    if area is None or a9 is None or a60 is None:
        missing.append(subID)
        continue
    p9 = pct_by_network(area, a9)
    p60 = pct_by_network(area, a60)
    for nm in net_labels.values():
        rows.append({"Subject": f"sub-{subID}", "Group": group, "NetworkLabel": nm,
                     "Pct_9min": p9[nm], "Pct_60min": p60[nm], "Delta_pct": p9[nm] - p60[nm]})

if missing:
    print("Missing inputs for:", missing)

df = pd.DataFrame(rows)
df.to_csv(out_csv, index=False)
print(f"Processed {df.Subject.nunique()} subjects. Saved: {out_csv}")
