# Surface area for LMA, LMC, HMC at 9 min vs 60 min

import os
import re
import numpy as np
import pandas as pd
import nibabel as nib

lma_nums = [2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26]
lmc_nums = [2,5,7,9,15,18,21,23,25,26]
hmc_nums = [4,6,8,10,11,12,13,14,16,17,19,20,22,24]

lma_ids  = [f"sub-1973{n:03d}P" for n in lma_nums]
lmc_ids  = [f"sub-1973{n:03d}C" for n in lmc_nums]
hmc_ids  = [f"sub-1973{n:03d}C" for n in hmc_nums]

group_map = (
    [(sid, "LMA") for sid in lma_ids] +
    [(sid, "LMC") for sid in lmc_ids] +
    [(sid, "HMC") for sid in hmc_ids]
)

data_dir_60  = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
data_dir_9   = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata/"
out_dir      = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
os.makedirs(out_dir, exist_ok=True)

#nets
network_nums   = [1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16]
network_labels = {1:"DMN", 2:"VIS", 3:"FP", 5:"DAN", 7:"VAN", 8:"SAL",
                  9:"CON", 10:"SMd", 11:"SMl", 12:"AUD", 16:"PON"}
name_to_num    = {v: k for k, v in network_labels.items()}


def read_60min_sa(subject_id):
    """Per-network SA % and total SA from 60-min txt file."""
    fname = (f"{subject_id}_alltasks_HCPAdultChild_overlap_14networkassignment"
             f"_Vertexwise_sample1_matchedconditions_Dice_network_surface_areas.txt")
    path  = os.path.join(data_dir_60, fname)
    if not os.path.exists(path):
        print(f"  missing 60-min SA: {subject_id}")
        return None, None

    net_pct  = {}
    total_sa = None
    with open(path) as f:
        for line in f:
            line = line.strip()
            m = re.match(r"(\w+):\s+([\d.]+)%", line)
            if m:
                name, pct = m.group(1), float(m.group(2))
                if name in name_to_num:
                    net_pct[name_to_num[name]] = pct
            m2 = re.match(r"Total cortical surface area:\s+([\d.]+)", line)
            if m2:
                total_sa = float(m2.group(1))
    return net_pct, total_sa


def read_9min_assignment(subject_id, sample="sample1"):
    """Network assignment from 9-min dscalar (integer 1-16 per vertex)."""
    fname = (f"{subject_id}_alltasks_HCPAdultChild_overlap_9min"
             f"_{sample}_Dice.dscalar.nii")
    path  = os.path.join(data_dir_9, fname)
    if not os.path.exists(path):
        print(f"  missing 9-min dscalar ({sample}): {subject_id}")
        return None
    data = np.asarray(nib.load(path).dataobj).squeeze()
    return np.round(data).astype(int)


#MAIN
rows = []

for sid, group in group_map:
    print(f"Processing {sid} ({group})...")

    net_pct_60, total_sa = read_60min_sa(sid)
    if net_pct_60 is None:
        continue

    assign_9 = read_9min_assignment(sid, sample="sample1")
    if assign_9 is None:
        continue

    n_cortical = len(assign_9)   # 59412

    for net_num in network_nums:
        net_name = network_labels[net_num]

        pct_60 = net_pct_60.get(net_num, np.nan)
        sa_60  = (pct_60 / 100.0) * total_sa if not np.isnan(pct_60) else np.nan

        n_verts_9 = int(np.sum(assign_9 == net_num))
        pct_9     = 100.0 * n_verts_9 / n_cortical
        sa_9      = (pct_9 / 100.0) * total_sa

        rows.append({
            "Subject":      sid,
            "Group":        group,
            "NetworkNum":   net_num,
            "NetworkLabel": net_name,
            "SA_60min_mm2": sa_60,
            "SA_9min_mm2":  sa_9,
            "Pct_60min":    pct_60,
            "Pct_9min":     pct_9,
            "Delta_pct":    pct_9 - pct_60,   # positive = larger at 9 min
        })

df = pd.DataFrame(rows)


desired_order = ["DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON"]

summary = df.groupby(["Group","NetworkLabel"]).agg(
    mean_pct_60 = ("Pct_60min", "mean"),
    mean_pct_9  = ("Pct_9min",  "mean"),
    mean_delta  = ("Delta_pct", "mean"),
).reset_index()

summary["NetworkLabel"] = pd.Categorical(
    summary["NetworkLabel"], categories=desired_order, ordered=True)
summary = summary.sort_values(["Group","NetworkLabel"])

df.to_csv(os.path.join(out_dir, "AllGroups_SurfaceArea_9vs60min_persubject.csv"),  index=False)
summary.to_csv(os.path.join(out_dir, "AllGroups_SurfaceArea_9vs60min_summary.csv"), index=False)
