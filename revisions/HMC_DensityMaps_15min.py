#!/usr/bin/env python3
"""
Density dscalar files for HMC using 15 min sample 1 and sample2 
"""

import os
import numpy as np
import nibabel as nib

DATA_DIR = ("/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/"
            "JNeuroSci_Revisionsdata/")
OUT_DIR  = ("/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/"
            "JNeuroSci_RevisionsResults/HMC_15min_DensityMaps/")
TEMPLATE_PATH = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/"
                 "HCPOverlap_MaxDice_Entropy/"
                 "Allchildren_groupaverage_winnertakeall_HCPAdultChild_"
                 "overlap_entropy.dscalar.nii")

os.makedirs(OUT_DIR, exist_ok=True)

# HMC = 14 subs
HMC_SUBS = [4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 24]

# Networks except 4, 6
NETWORKS = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
NETWORK_MAP = {
    1: "DMN",  2: "VIS",  3: "FP",   5: "DAN",
    7: "VAN",  8: "SAL",  9: "CON", 10: "SMd",
   11: "SMl", 12: "AUD", 13: "Tpole", 14: "MTL",
   15: "PMN", 16: "PON"
}

N_GRAYORDINATES = 91282
SAMPLES = ["1", "2"]


def sub_id(num):
    """Build child subject ID, e.g. 4 -> 1973004C."""
    return f"1973{num:03d}C"


def load_dice_map(sub_num, sample):
    sid = sub_id(sub_num)
    fname = (f"sub-{sid}_alltasks_HCPAdultChild_overlap_"
             f"15min_sample{sample}_Dice.dscalar.nii")
    fpath = os.path.join(DATA_DIR, fname)
    if not os.path.exists(fpath):
        print(f"  MISSING: {fname}")
        return None
    return nib.load(fpath).get_fdata().flatten()


def main():
    template_img = nib.load(TEMPLATE_PATH)
    counts = {s: {n: np.zeros(N_GRAYORDINATES, dtype=np.float32)
                  for n in NETWORKS}
              for s in SAMPLES}
    n_found = {s: 0 for s in SAMPLES}

    for sample in SAMPLES:
        print(f"\nSample {sample}")
        for sub in HMC_SUBS:
            data = load_dice_map(sub, sample)
            if data is None:
                continue
            n_found[sample] += 1
            for net in NETWORKS:
                counts[sample][net] += (data == net).astype(np.float32)
        print(f"  {n_found[sample]}/{len(HMC_SUBS)} HMC subs "
              f"for sample{sample}")

    print("\nSaving dscalars")
    for sample in SAMPLES:
        n = n_found[sample]
        for net in NETWORKS:
            density    = counts[sample][net]
            proportion = density / n if n > 0 else density

            for data_arr, suffix in [(density, "density"),
                                     (proportion, "proportion")]:
                new_img = nib.Cifti2Image(
                    data_arr.reshape(1, -1),
                    header=template_img.header,
                    nifti_header=template_img.nifti_header,
                )
                out_name = (f"Network{net}_HMC_15min_sample{sample}_"
                            f"{suffix}.dscalar.nii")
                nib.save(new_img, os.path.join(OUT_DIR, out_name))


if __name__ == "__main__":
    main()
