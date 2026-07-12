#!/usr/bin/env python3
"""
CreateMotionGroup_DensityMaps_9min.py

For LMC and HMC, create per-network density dscalars using 9 min data scalars
Each vertex value = number of subs assigned that network to that vertex


"""

import os
import numpy as np
import nibabel as nib

DATA_DIR   = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata/"
TEMPLATE   = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/"
              "HCPOverlap_MaxDice_Entropy/"
              "Allchildren_groupaverage_winnertakeall_HCPAdultChild_overlap_entropy.dscalar.nii")
OUTPUT_DIR = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/"
              "HCPOverlap_MaxDice_Entropy/PKWTA_MotionGroups_OverlapMaps_9min")


#SUBS
LMA_NUMS = [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 24, 25, 26]
LMC_NUMS = [2, 5, 7, 9, 15, 18, 21, 23, 25, 26]
HMC_NUMS = [4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 24]

MOTION_GROUPS = {
    "LMA": LMA_NUMS,
    "LMC": LMC_NUMS,
    "HMC": HMC_NUMS,
}
#only doing 11 nets for viz
NETWORKS = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16]

N_GRAYORDINATES = 91282
SAMPLE = "sample1"


def load_9min_dice(sub_num, group_letter):
    """Load 9-min Dice assignment dscalar, return (91282,) array."""
    sub_str = f"1973{sub_num:03d}"
    fname   = (f"sub-{sub_str}{group_letter}_alltasks_HCPAdultChild_overlap"
               f"_9min_{SAMPLE}_Dice.dscalar.nii")
    fpath   = os.path.join(DATA_DIR, fname)
    if not os.path.exists(fpath):
        print(f"  MISSING: {fname}")
        return None
    img  = nib.load(fpath)
    data = img.get_fdata().flatten()
    if data.shape[0] != N_GRAYORDINATES:
        # cifti cortex-only files have 59412 vertices — handle both
        pass
    return data


def main():
    template_img = nib.load(TEMPLATE)
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    counts     = {g: {n: np.zeros(N_GRAYORDINATES, dtype=np.float32)
                      for n in NETWORKS}
                  for g in ("LMA", "LMC", "HMC")}
    n_subjects = {"LMA": 0, "LMC": 0, "HMC": 0}

    for grp, nums in MOTION_GROUPS.items():
        grp_letter = "P" if grp == "LMA" else "C"
        for sub_num in nums:
            data = load_9min_dice(sub_num, grp_letter)
            if data is None:
                continue

            if data.shape[0] == 59412:
                padded = np.zeros(N_GRAYORDINATES, dtype=np.float32)
                padded[:59412] = data
                data = padded
            for net in NETWORKS:
                counts[grp][net] += (np.round(data) == net).astype(np.float32)
            n_subjects[grp] += 1

    print("\nSubject counts loaded:")
    for g, n in n_subjects.items():
        print(f"  {g}: {n} subjects")

    for grp in ("LMA", "LMC", "HMC"):
        n = n_subjects[grp]
        for net in NETWORKS:
            density    = counts[grp][net]
            proportion = density / n if n > 0 else density

            for data_arr, suffix in [(density, "density"), (proportion, "proportion")]:
                new_img = nib.Cifti2Image(
                    data_arr.reshape(1, -1),
                    header=template_img.header,
                    nifti_header=template_img.nifti_header
                )
                out_name = f"Network{net}_{grp}_{suffix}.dscalar.nii"
                nib.save(new_img, os.path.join(OUTPUT_DIR, out_name))
                print(f"  Saved {out_name}")

    print(f"\nDone. Files saved to:\n  {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
