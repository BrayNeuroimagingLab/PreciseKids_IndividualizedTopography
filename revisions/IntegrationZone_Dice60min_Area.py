#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Integration zone or low confidence zone at 60 min = cortical vertices where max Dice vals < 0.3

Max dice from ex: sub-1973XXXC/P_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_maxdice.dscalar.nii

"""

import os
import csv
import numpy as np
import pandas as pd
import nibabel as nib

MAXDICE_DIR = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/"
               "HCPOverlap_MaxDice_Entropy/")
RESULTS_DIR = ("/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/"
               "JNeuroSci_RevisionsResults/")
META_CSV    = os.path.join(RESULTS_DIR, "mean_entropy_summary.csv")
TEMPLATE_LABEL = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/"
                  "HCPOverlap_MaxDice_Entropy/"
                  "Allchildren_groupaverage_winnertakeall_alltasks_"
                  "HCPAdultChild_overlap_14networkassignment.dscalar.nii")

OUT_CSV     = os.path.join(RESULTS_DIR, "integration_zone_dice60min.csv")

DICE_THRESHOLD = 0.3   # vertex is "low confidence" if max Dice < 0.3 since max Dice >=0.3 is high confidence in paper

NETWORKS = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]
NETWORK_MAP = {
    1: "DMN",  2: "VIS",  3: "FP",   5: "DAN",
    7: "VAN",  8: "SAL",  9: "CON", 10: "SMd",
   11: "SMl", 12: "AUD", 13: "Tpole", 14: "MTL",
   15: "PMN", 16: "PON",
    0: "WholeCortex",
}


def maxdice_path(subject_id):
    fname = (f"{subject_id}_alltasks_HCPAdultChild_overlap_"
             f"14networkassignment_Vertexwise_sample1_matchedconditions_"
             f"maxdice.dscalar.nii")
    return os.path.join(MAXDICE_DIR, fname)


def matched_entropy_path(subject_id):
    fname = (f"{subject_id}_alltasks_HCPAdultChild_overlap_"
             f"14networkassignment_Vertexwise_sample1_matchedconditions_"
             f"entropy.dscalar.nii")
    return os.path.join(MAXDICE_DIR, fname)


def load_maxdice(subject_id):
    fpath = maxdice_path(subject_id)
    if not os.path.exists(fpath):
        return None
    return nib.load(fpath).get_fdata().flatten().astype(float)


def load_entropy_for_mask(subject_id):
    fpath = matched_entropy_path(subject_id)
    if not os.path.exists(fpath):
        return None
    return nib.load(fpath).get_fdata().flatten().astype(float)


def cortical_valid_mask(entropy_arr):
    return np.isfinite(entropy_arr) & (entropy_arr > 0)


print(f"Loading metadata: {META_CSV}")
meta = pd.read_csv(META_CSV)
required = {"subject_id", "family_id", "group", "age", "sex",
            "motion_group", "data_length_min", "n_cortical_vertices",
            "total_surface_area_mm2"}
missing = required - set(meta.columns)
if missing:
    raise SystemExit(f"mean_entropy_summary.csv missing columns: {missing}")

# Per-subject mean vertex area (mm^2)
meta["mean_vertex_area_mm2"] = (
    meta["total_surface_area_mm2"] / meta["n_cortical_vertices"]
)

meta_subjects = (meta[["subject_id", "family_id", "group", "age", "sex",
                       "motion_group", "total_surface_area_mm2",
                       "n_cortical_vertices", "mean_vertex_area_mm2"]]
                 .drop_duplicates(subset="subject_id")
                 .reset_index(drop=True))

before = len(meta_subjects)
meta_subjects = meta_subjects[
    meta_subjects["motion_group"].isin(["LMA", "LMC", "HMC"])
].reset_index(drop=True)
print(f"  excluded {before - len(meta_subjects)} subject(s) with no motion_group "
      f"(e.g. 017P / 022P)")
print(f"  retained {len(meta_subjects)} subjects "
      f"({meta_subjects['motion_group'].value_counts().to_dict()})")

# Group template label
label_arr = nib.load(TEMPLATE_LABEL).get_fdata().flatten().astype(int)


#INTEGRATION ZONES
rows = []
n_missing = 0

for _, srow in meta_subjects.iterrows():
    sid          = srow["subject_id"]
    motion_group = srow["motion_group"]
    family_id    = srow["family_id"]
    group        = srow["group"]
    age          = srow["age"]
    sex          = srow["sex"]
    mean_vert    = float(srow["mean_vertex_area_mm2"])
    total_sa     = float(srow["total_surface_area_mm2"])

    dice = load_maxdice(sid)
    if dice is None:
        print(f"  [missing maxdice] {sid}")
        n_missing += 1
        continue

    entropy = load_entropy_for_mask(sid)
    if entropy is None:
        print(f"  [missing matched-entropy → falling back to dice-finite] {sid}")
        valid = np.isfinite(dice)
    else:
        valid = cortical_valid_mask(entropy) & np.isfinite(dice)

    n_cortex_v = int(valid.sum())
    if n_cortex_v == 0:
        print(f"  [no valid cortex] {sid}")
        continue

    iz_mask = valid & (dice < DICE_THRESHOLD)

    iz_n         = int(iz_mask.sum())
    iz_pct_v     = iz_n / n_cortex_v * 100.0
    iz_mm2       = iz_n * mean_vert
    iz_pct_sa    = iz_mm2 / total_sa * 100.0 if total_sa > 0 else 0.0

    rows.append({
        "subject_id"         : sid,
        "family_id"          : family_id,
        "group"              : group,
        "age"                : age,
        "sex"                : sex,
        "motion_group"       : motion_group,
        "dice_threshold"     : DICE_THRESHOLD,
        "network_num"        : 0,
        "network_name"       : "WholeCortex",
        "n_cortical_vertices": n_cortex_v,
        "iz_n_vertices"      : iz_n,
        "iz_pct_vertices"    : round(iz_pct_v, 4),
        "iz_area_mm2"        : round(iz_mm2, 2),
        "iz_pct_cortex_area" : round(iz_pct_sa, 4),
    })
    for net in NETWORKS:
        net_mask    = (label_arr == net)
        iz_net_mask = iz_mask & net_mask
        net_valid_n = int((valid & net_mask).sum())

        iz_net_n      = int(iz_net_mask.sum())
        iz_net_pct_v  = (iz_net_n / net_valid_n * 100.0) if net_valid_n > 0 else 0.0
        iz_net_mm2    = iz_net_n * mean_vert
        iz_net_pct_sa = (iz_net_mm2 / total_sa * 100.0) if total_sa > 0 else 0.0

        rows.append({
            "subject_id"         : sid,
            "family_id"          : family_id,
            "group"              : group,
            "age"                : age,
            "sex"                : sex,
            "motion_group"       : motion_group,
            "dice_threshold"     : DICE_THRESHOLD,
            "network_num"        : net,
            "network_name"       : NETWORK_MAP[net],
            "n_cortical_vertices": net_valid_n,
            "iz_n_vertices"      : iz_net_n,
            "iz_pct_vertices"    : round(iz_net_pct_v, 4),
            "iz_area_mm2"        : round(iz_net_mm2, 2),
            "iz_pct_cortex_area" : round(iz_net_pct_sa, 4),
        })



df = pd.DataFrame.from_records(rows)
df.to_csv(OUT_CSV, index=False)
print(f"\nWrote {len(df):,} rows → {OUT_CSV}")
if n_missing:
    print(f"  ({n_missing} subjects missing max-Dice files)")

