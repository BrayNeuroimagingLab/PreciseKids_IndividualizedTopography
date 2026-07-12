#!/usr/bin/env python3
"""
CreateMotionGroup_DensityMaps.py

For each motion group (LMA, LMC, HMC) and each network, create a density
dscalar where each vertex value = number of subjects in that group who
assigned that network to that vertex.

Output files in PKWTA_MotionGroups_OverlapMaps/:
  Network{N}_LMA_density.dscalar.nii  (max value = 22)
  Network{N}_LMC_density.dscalar.nii  (max value = 10)
  Network{N}_HMC_density.dscalar.nii  (max value = 14)
"""

import os
import numpy as np
import nibabel as nib

BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(BASE_DIR, "PKWTA_MotionGroups_OverlapMaps")

# Subject IDs from PK_Overlap_Maps_MotionGroups.m  (sub numbers, skip 3)
ALL_SUBS = [s for s in range(2, 27) if s != 3]

MOTION_GROUPS = {
    "LMA": [s for s in ALL_SUBS],               # all P subjects EXCEPT 17 and 22
    "LMC": [2, 5, 7, 9, 15, 18, 21, 23, 25, 26], # low-motion children
    "HMC": [4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 24],  # high-motion children
}

# LMA 
LMA_PARENT_SUBS = [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                   18, 19, 20, 21, 23, 24, 25, 26]  # exclude 17P and 22P

NETWORKS = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]  # exclude 4 and 6

N_GRAYORDINATES = 91282


def load_dice_map(sub_num, group_letter):
    """Load individual Dice assignment dscalar, return (91282,) array."""
    sub_str = f"1973{sub_num:03d}"
    fname = (f"sub-{sub_str}{group_letter}_alltasks_HCPAdultChild_overlap_"
             "Dice.dscalar.nii")
    fpath = os.path.join(BASE_DIR, fname)
    if not os.path.exists(fpath):
        print(f"  MISSING: {fname}")
        return None
    img = nib.load(fpath)
    return img.get_fdata().flatten()


def main():
    # Load template CIFTI header (for saving)
    template_path = os.path.join(
        BASE_DIR,
        "Allchildren_groupaverage_winnertakeall_HCPAdultChild_overlap_entropy.dscalar.nii"
    )
    template_img = nib.load(template_path)

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    counts = {g: {n: np.zeros(N_GRAYORDINATES, dtype=np.float32)
                  for n in NETWORKS}
              for g in ("LMA", "LMC", "HMC")}
    n_subjects = {"LMA": 0, "LMC": 0, "HMC": 0}

    for sub in ALL_SUBS:
        # LMA
        if sub in LMA_PARENT_SUBS:
            data = load_dice_map(sub, "P")
            if data is not None:
                for net in NETWORKS:
                    counts["LMA"][net] += (data == net).astype(np.float32)
                n_subjects["LMA"] += 1

        # LMC 
        if sub in MOTION_GROUPS["LMC"]:
            data = load_dice_map(sub, "C")
            if data is not None:
                for net in NETWORKS:
                    counts["LMC"][net] += (data == net).astype(np.float32)
                n_subjects["LMC"] += 1

        # HMC
        if sub in MOTION_GROUPS["HMC"]:
            data = load_dice_map(sub, "C")
            if data is not None:
                for net in NETWORKS:
                    counts["HMC"][net] += (data == net).astype(np.float32)
                n_subjects["HMC"] += 1

    print("\nSubject counts loaded:")
    for g, n in n_subjects.items():
        print(f"  {g}: {n} subjects")

    # Two versions per group × network:
    #   *_density.dscalar.nii   : raw subject count (range 0-N diff eachgroup)
    #   *_proportion.dscalar.nii: count / N_group   (range 0-1socomparable across groups)
    for group_name in ("LMA", "LMC", "HMC"):
        n = n_subjects[group_name]
        for net in NETWORKS:
            density    = counts[group_name][net]
            proportion = density / n if n > 0 else density

            for data_arr, suffix in [(density, "density"), (proportion, "proportion")]:
                new_img = nib.Cifti2Image(
                    data_arr.reshape(1, -1),
                    header=template_img.header,
                    nifti_header=template_img.nifti_header
                )
                out_name = f"Network{net}_{group_name}_{suffix}.dscalar.nii"
                nib.save(new_img, os.path.join(OUTPUT_DIR, out_name))


if __name__ == "__main__":
    main()
