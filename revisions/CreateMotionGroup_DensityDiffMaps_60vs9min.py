#!/usr/bin/env python3
"""
CreateMotionGroup_DensityDiffMaps_60vs9min.py

Instead of looking at a wall of individual brains (60-min vs 9-min
density maps side by side), make a difference map per network per
group (LMC, HMC) so we can see density diff. changes between 60 minutes and 9 minutes of data.
"""

import os
import numpy as np
import nibabel as nib

BASE_DIR    = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
DIR_60MIN   = os.path.join(BASE_DIR, "PKWTA_MotionGroups_OverlapMaps")
DIR_9MIN    = os.path.join(BASE_DIR, "PKWTA_MotionGroups_OverlapMaps_9min")
OUTPUT_DIR  = os.path.join(BASE_DIR, "PKWTA_MotionGroups_DensityDiff_60vs9min")

TEMPLATE = os.path.join(BASE_DIR,
           "Allchildren_groupaverage_winnertakeall_HCPAdultChild_overlap_entropy.dscalar.nii")

GROUPS   = ["LMA", "LMC", "HMC"]
NETWORKS = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16]

# the 60-min OverlapMaps folder only has *_density (no *_proportion saved),
# so derive proportion = density / N_subjects using the known group sizes
N_SUBJECTS_60MIN = {"LMA": 22, "LMC": 10, "HMC": 14}


def load_proportion(directory, net, grp):
    """Load a *_proportion map directly if present; otherwise derive it
    from a *_density map using the known group N (used for the 60-min dir,
    which only has density maps saved)."""
    prop_fname = f"Network{net}_{grp}_proportion.dscalar.nii"
    prop_fpath = os.path.join(directory, prop_fname)
    if os.path.exists(prop_fpath):
        return nib.load(prop_fpath).get_fdata().flatten()

    dens_fname = f"Network{net}_{grp}_density.dscalar.nii"
    dens_fpath = os.path.join(directory, dens_fname)
    if os.path.exists(dens_fpath):
        n = N_SUBJECTS_60MIN.get(grp)
        if n is None:
            print(f"  No known N for group {grp} to derive proportion — skipping {dens_fname}")
            return None
        density = nib.load(dens_fpath).get_fdata().flatten()
        print(f"  Derived proportion for {dens_fname} (density / N={n})")
        return density / float(n)

    print(f"  MISSING: {prop_fpath}  (and no density fallback found)")
    return None


def main():
    template_img = nib.load(TEMPLATE)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for grp in GROUPS:
        for net in NETWORKS:
            prop_60 = load_proportion(DIR_60MIN, net, grp)
            prop_9  = load_proportion(DIR_9MIN,  net, grp)
            if prop_60 is None or prop_9 is None:
                continue
            if prop_60.shape[0] != prop_9.shape[0]:
                print(f"  shape mismatch net{net} {grp}: "
                      f"{prop_60.shape} vs {prop_9.shape} — skipping")
                continue

            diff = (prop_60 - prop_9).astype(np.float32)

            new_img = nib.Cifti2Image(
                diff.reshape(1, -1),
                header=template_img.header,
                nifti_header=template_img.nifti_header
            )
            out_name = f"Network{net}_{grp}_diff_60vs9min.dscalar.nii"
            nib.save(new_img, os.path.join(OUTPUT_DIR, out_name))
            print(f"  Saved {out_name}   "
                  f"(diff range: {diff.min():.3f} .. {diff.max():.3f}, "
                  f"mean |diff| = {np.mean(np.abs(diff)):.3f})")

    print(f"\nDone. Difference maps saved to:\n  {OUTPUT_DIR}")
    print("Positive = assignment MORE prevalent at 60 min (grows with more data)")
    print("Negative = assignment MORE prevalent at 9 min  (shrinks with more data)")


if __name__ == "__main__":
    main()
