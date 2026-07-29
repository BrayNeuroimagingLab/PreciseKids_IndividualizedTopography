#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Per-subject 9-vs-60 conjunction map for one network (default DMN), for exemplars.
Each vertex: 1 = network at both 9 and 60 (stable), 2 = 9 min only (removed by 60),
3 = 60 min only (filled in by 60). Saves dscalars and colour-labelled dlabels.
"""
import os
import subprocess
import numpy as np
import nibabel as nib

data9_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
full_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
out_dir = os.path.join(full_dir, "Exemplar_NetworkConjunction_9vs60")
os.makedirs(out_dir, exist_ok=True)
wb_command = "/Applications/workbench/bin_macosx64/wb_command"
if not os.path.exists(wb_command):
    wb_command = "/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command"

networks = {1: "DMN", 2: "VIS"}  # association (DMN) and sensory (VIS) exemplar networks
# motion-group exemplars first, then participants picked for the fragmentation figure:
# PK13/PK22 had the largest 9-to-60 drop in visual fragments, PK18/PK26/PK08/PK15
# show networks that consolidate by filling in rather than by losing scattered patches
exemplars = {"LMC": "1973002C", "HMC": "1973010C", "LMA": "1973019P",
             "LMA_PK13": "1973013P", "HMC_PK22": "1973022C",
             "LMC_PK18": "1973018C", "LMA_PK26": "1973026P",
             "PK08_child": "1973008C", "PK15_adult": "1973015P"}
n_cortex = 59412
n_gray = 91282

# label colours: stable = light teal (recedes), 9-only = deep orange, 60-only = deep purple.
# The two change categories are dark so they stand out against the grey surface.
label_txt = os.path.join(out_dir, "conjunction_labels_v2.txt")
with open(label_txt, "w") as f:
    f.write("both_9and60\n1 147 201 194 255\n9min_only\n2 143 46 7 255\n60min_only_filled\n3 53 26 87 255\n")

def load_wta(subID, length):
    if length == "9min":
        f = f"{data9_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_9min_sample1_Dice.dscalar.nii"
    else:
        f = f"{full_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii"
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)[:n_cortex]

tmpl = nib.load(f"{full_dir}/sub-1973002C_alltasks_HCPAdultChild_overlap_Dice.dscalar.nii")
wta = {(subID, ln): load_wta(subID, ln) for subID in exemplars.values() for ln in ("9min", "60min")}
for net, net_name in networks.items():
    for grp, subID in exemplars.items():
        d9 = wta[(subID, "9min")] == net
        d60 = wta[(subID, "60min")] == net
        cat = np.zeros(n_cortex, dtype=np.float32)
        cat[d9 & d60] = 1    # both (stable)
        cat[d9 & ~d60] = 2   # 9 only (removed)
        cat[~d9 & d60] = 3   # 60 only (filled in)
        full = np.zeros(n_gray, dtype=np.float32)
        full[:n_cortex] = cat
        dscalar = os.path.join(out_dir, f"{grp}_sub-{subID}_{net_name}_conjunction_9vs60.dscalar.nii")
        nib.save(nib.Cifti2Image(full.reshape(1, -1), header=tmpl.header, nifti_header=tmpl.nifti_header), dscalar)
        dlabel = dscalar.replace(".dscalar.nii", ".dlabel.nii")
        subprocess.run([wb_command, "-cifti-label-import", dscalar, label_txt, dlabel], check=True)
        print(f"{net_name} {grp} {subID}: both={int((cat==1).sum())}  9only={int((cat==2).sum())}  60only(filled)={int((cat==3).sum())}")
