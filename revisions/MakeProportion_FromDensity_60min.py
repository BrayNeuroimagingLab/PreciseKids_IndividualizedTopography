#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Convert 60-min motion-group density dscalars to proportion (density / N),
so LMA/LMC/HMC (N = 22/10/14) are comparable on a 0-1 scale.
"""
import os
import numpy as np
import nibabel as nib

density_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/PKWTA_MotionGroups_OverlapMaps"
n_subjects = {"LMA": 22, "LMC": 10, "HMC": 14}
networks = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]

max_prop = {}
for grp, n in n_subjects.items():
    gmax = 0.0
    for net in networks:
        f = os.path.join(density_dir, f"Network{net}_{grp}_density.dscalar.nii")
        if not os.path.exists(f):
            print("missing", f)
            continue
        img = nib.load(f)
        prop = np.asarray(img.dataobj).astype(np.float32) / n
        out = nib.Cifti2Image(prop.reshape(1, -1), header=img.header, nifti_header=img.nifti_header)
        nib.save(out, os.path.join(density_dir, f"Network{net}_{grp}_proportion.dscalar.nii"))
        gmax = max(gmax, float(prop.max()))
    max_prop[grp] = round(gmax, 3)
print("Saved proportion maps. Max proportion per group:", max_prop)
