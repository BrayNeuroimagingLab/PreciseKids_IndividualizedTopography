#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mean entropy (assignment confidence) controlled for topographic reliability and motion.
Reliability is 30-min split-half NMI between two independent network assignments.
Primary model is length-matched (30-min entropy + 30-min NMI); also reports 60-min
entropy with NMI as a subject-level reliability trait.
"""
import warnings
import numpy as np
import pandas as pd
import nibabel as nib
import statsmodels.formula.api as smf
from sklearn.metrics import normalized_mutual_info_score as nmi_score
warnings.filterwarnings("ignore")

data_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
covar_xlsx = "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"
out_txt = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/Figure5_Entropy_NMIcontrol_results.txt"
n_cortex = 59412
subs = [f"1973{n:03d}{s}" for n in range(2, 27) if n != 3 for s in ["C", "P"]]

def mean_entropy(subID, length):
    f = f"{data_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_{length}_entropy.dscalar.nii"
    return float(np.nanmean(np.asarray(nib.load(f).dataobj).squeeze()))

def wta(subID, sample):
    f = f"{data_dir}/sub-{subID}_alltasks_HCPAdultChild_overlap_30min_sample{sample}_Dice.dscalar.nii"
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)[:n_cortex]

rows = []
for subID in subs:
    rows.append({"ID": subID,
                 "ent30": mean_entropy(subID, "30min"),
                 "ent60": mean_entropy(subID, "60min"),
                 "NMI30": nmi_score(wta(subID, 1), wta(subID, 2))})  # 30-min split-half reliability
d = pd.DataFrame(rows)
cov = pd.read_excel(covar_xlsx).rename(columns={"sub": "ID"})
cov["ID"] = cov["ID"].astype(str).str.strip()
d = d.merge(cov[["ID", "sex", "censored_volumes", "family"]], on="ID")
d["group"] = pd.Categorical(np.where(d.ID.str.endswith("C"), "child", "adult"), categories=["adult", "child"])
d["g"] = (d.group == "child").astype(int)

lines = []
def log(s):
    print(s)
    lines.append(s)

log(f"N = {len(d)} subjects, {d.family.nunique()} families\n")
log("Correlations: entropy30-NMI30 = %.2f | group-NMI30 = %.2f\n"
    % (np.corrcoef(d.ent30, d.NMI30)[0, 1], np.corrcoef(d.g, d.NMI30)[0, 1]))

def fit(y, formula, tag):
    d["Y"] = d[y]
    m = smf.mixedlm(formula, d, groups=d["family"]).fit()
    log(f"--- {tag} ---\n    {formula.replace('Y', y)}")
    for t in ["group[T.child]", "NMI30", "censored_volumes", "sex[T.M]"]:
        if t in m.params.index:
            log(f"    {t} beta={m.params[t]:+.4f}  z={m.tvalues[t]:+.3f}  p={m.pvalues[t]:.4g}")
    log("")

log("===== length-matched: 30-min entropy + 30-min NMI =====\n")
fit("ent30", "Y ~ group + sex + censored_volumes", "base (+motion)")
fit("ent30", "Y ~ group + sex + censored_volumes + NMI30", "+ motion + NMI")
log("===== 60-min entropy, NMI as reliability trait =====\n")
fit("ent60", "Y ~ group + sex + censored_volumes + NMI30", "60-min entropy + motion + NMI")

with open(out_txt, "w") as fh:
    fh.write("\n".join(lines))
print(f"Saved -> {out_txt}")
