#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Figure 5A: group-mean vertex-wise entropy maps for children and adults, at 9 and
60 min. Averaged over the full 91282 grayordinates. Lower entropy = higher confidence.
"""
import os
import numpy as np
import nibabel as nib

data_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
out_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/Figure5_PanelA_GroupMeanEntropy"
os.makedirs(out_dir, exist_ok=True)

subs = [f"{n:03d}" for n in range(2, 27) if n != 3]
child_subs = [f"1973{s}C" for s in subs]
adult_subs = [f"1973{s}P" for s in subs]
fmt = "sub-{sid}_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_{length}_entropy.dscalar.nii"

def load_entropy(subID, length):
    f = os.path.join(data_dir, fmt.format(sid=subID, length=length))
    return np.asarray(nib.load(f).dataobj).squeeze().astype(np.float32)

for length in ["9min", "60min"]:
    tmpl = nib.load(os.path.join(data_dir, fmt.format(sid=child_subs[0], length=length)))
    for group, ids in [("Children", child_subs), ("Adults", adult_subs)]:
        mean_map = np.nanmean(np.vstack([load_entropy(s, length) for s in ids]), axis=0).astype(np.float32)
        img = nib.Cifti2Image(mean_map.reshape(1, -1), header=tmpl.header, nifti_header=tmpl.nifti_header)
        out = os.path.join(out_dir, f"GroupMeanEntropy_{group}_{length}.dscalar.nii")
        nib.save(img, out)
        print(f"{group} {length}: mean = {np.nanmean(mean_map):.3f}")
