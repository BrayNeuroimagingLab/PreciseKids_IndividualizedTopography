#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Family-matched low-motion comparison: the 10 low-motion children (LMC) vs their
parents (LMA, n=10). Writes LMA10 density-proportion maps for the figure and a
union surface-area table (spatial spread) for LMC vs the family-matched LMA.
"""
import os
import csv
import numpy as np
import nibabel as nib

full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
map_dir = os.path.join(full_dir, "PKWTA_MotionGroups_OverlapMaps")
out_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults"
area_cache = os.path.join(out_dir, "per_vertex_area_cache.npz")
template_path = os.path.join(full_dir, "Allchildren_groupaverage_winnertakeall_HCPAdultChild_overlap_entropy.dscalar.nii")

n_cortex = 59412
n_gray = 91282
net_labels = {1: "DMN", 2: "VIS", 3: "FP", 5: "DAN", 7: "VAN", 8: "SAL", 9: "CON",
              10: "SMd", 11: "SMl", 12: "AUD", 13: "Tpole", 14: "MTL", 15: "PMN", 16: "PON"}
networks = list(net_labels.keys())

families = [2, 5, 7, 9, 15, 18, 21, 23, 25, 26]
lma10 = [f"1973{n:03d}P" for n in families]  # family-matched adults
lmc10 = [f"1973{n:03d}C" for n in families]  # low-motion children

def wta(subID):
    f = os.path.join(full_dir, f"sub-{subID}_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii")
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)[:n_cortex]

tmpl = nib.load(template_path)
assign = {s: wta(s) for s in lma10 + lmc10}

# LMA10 density-proportion maps for the figure
for net in networks:
    prop = np.mean([(assign[s] == net) for s in lma10], axis=0).astype(np.float32)
    full = np.zeros(n_gray, dtype=np.float32)
    full[:n_cortex] = prop
    nib.save(nib.Cifti2Image(full.reshape(1, -1), header=tmpl.header, nifti_header=tmpl.nifti_header),
             os.path.join(map_dir, f"Network{net}_LMA10fam_proportion.dscalar.nii"))
print(f"Saved family-matched LMA10 proportion maps -> {map_dir}")

# union surface area (spatial spread) per network, weighted by group-median vertex areas
areas = {k: v for k, v in np.load(area_cache).items()}

def union_area(ids):
    med = np.median(np.vstack([areas[s] for s in ids]), axis=0)
    out = {}
    for net in networks:
        u = np.zeros(n_cortex, dtype=bool)
        for s in ids:
            u |= (assign[s] == net)
        out[net] = float(med[u].sum())
    return out

lma_sa = union_area(lma10)
lmc_sa = union_area(lmc10)

rows = []
for net in networks:
    direction = "Children > Adults" if lmc_sa[net] > lma_sa[net] else "Adults > Children"
    rows.append({"Network": net_labels[net], "LMA10_fam_SA_mm2": round(lma_sa[net], 2),
                 "LMC10_SA_mm2": round(lmc_sa[net], 2), "Direction_LMCvsLMA": direction})
    print(f"{net_labels[net]:6}{lma_sa[net]:12.0f}{lmc_sa[net]:12.0f}   {direction}")

with open(os.path.join(out_dir, "SupplTableWY_FamilyMatched_UnionSA.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
print("Saved: SupplTableWY_FamilyMatched_UnionSA.csv")
