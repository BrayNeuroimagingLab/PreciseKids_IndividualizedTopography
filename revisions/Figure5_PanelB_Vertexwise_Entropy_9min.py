#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Figure 5B at 9 min: per-vertex mixed model of entropy, child vs adult.
  entropy ~ group + sex + motion + (1 | family)   (family fixed-effects OLS fallback)
Outputs group-beta and uncorrected p-value dscalars.
"""
import os
import warnings
import numpy as np
import pandas as pd
import nibabel as nib
import statsmodels.api as sm
import statsmodels.formula.api as smf
warnings.filterwarnings("ignore")

data_dir = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
base_dir = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy"
template_path = os.path.join(base_dir, "Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii")
covar_xlsx = os.path.join(base_dir, "prckids-motion_beh.xlsx")
out_dir = os.path.join(base_dir, "Figure5_PanelB_9min")
os.makedirs(out_dir, exist_ok=True)
fmt = "sub-{sid}_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_9min_entropy.dscalar.nii"

template = nib.load(template_path)
n_vertices = template.get_fdata().shape[-1]

cov = pd.read_excel(covar_xlsx, engine="openpyxl")
cov['sub'] = cov['sub'].astype(str).str.strip()
cov['sex01'] = cov['sex'].str.lower().map({'m': 0, 'f': 1}).astype(float)
cov['motion'] = cov['censored_volumes'].astype(float)
sex_dict, mot_dict, fam_dict = (dict(zip(cov['sub'], cov[c])) for c in ['sex01', 'motion', 'family'])

subs = [f"{n:03d}" for n in range(2, 27) if n != 3]
child_subs = [f"1973{s}C" for s in subs]
adult_subs = [f"1973{s}P" for s in subs]

def load_entropy(subID):
    return nib.load(os.path.join(data_dir, fmt.format(sid=subID))).get_fdata()[0, :]

child_data = np.vstack([load_entropy(s) for s in child_subs]).T   # n_vertices x n
adult_data = np.vstack([load_entropy(s) for s in adult_subs]).T
ids = child_subs + adult_subs
print(f"Loaded {len(child_subs)} children + {len(adult_subs)} adults; n_vertices = {n_vertices}")

group = np.array([1] * len(child_subs) + [0] * len(adult_subs), float)
sex = np.array([sex_dict[s] for s in ids], float)
mot = np.array([mot_dict[s] for s in ids], float)
mot = (mot - mot.mean()) / mot.std()
fam = np.array([fam_dict[s] for s in ids], object)
design = pd.DataFrame({'group': group, 'sex': sex, 'motion': mot, 'family': fam})

def fit_vertex(yv, df):
    df = df.copy()
    df['y'] = yv.astype(float)
    if df['y'].nunique() <= 1:
        raise ValueError
    try:
        r = smf.mixedlm("y ~ group + sex + motion", df, groups=df['family']).fit(method="lbfgs", reml=True, maxiter=200, disp=False)
        return float(r.params.get('group', np.nan)), float(r.pvalues.get('group', np.nan))
    except Exception:
        fam_dum = pd.get_dummies(df['family'], drop_first=True, dtype=float)
        X = pd.concat([pd.DataFrame({'I': 1.0, 'group': df['group'], 'sex': df['sex'], 'motion': df['motion']}), fam_dum], axis=1)
        r = sm.OLS(df['y'].values, X.values).fit()
        return float(r.params[1]), float(r.pvalues[1])

coefs = np.full(n_vertices, np.nan)
pvals = np.full(n_vertices, np.nan)
for v in range(n_vertices):
    y = np.concatenate([child_data[v, :], adult_data[v, :]])
    ok = np.isfinite(y)
    if ok.sum() < 4:
        continue
    try:
        b, p = fit_vertex(y[ok], design.loc[ok])
        coefs[v] = b
        pvals[v] = p
    except Exception:
        continue
    if v % 10000 == 0:
        print(f"  vertex {v}/{n_vertices}")

valid = np.isfinite(coefs) & np.isfinite(pvals)
print(f"Valid fits: {valid.sum()}/{n_vertices}; p<0.05: {int(np.sum(pvals < 0.05))}")
for arr, name, fill in [(coefs, "GroupBeta", 0.0), (pvals, "Pvals_uncorrected", 1.0)]:
    m = np.nan_to_num(arr, nan=fill).reshape(1, -1).astype(np.float32)
    nib.save(nib.Cifti2Image(m, header=template.header), os.path.join(out_dir, f"Entropy_ChildVsAdult_{name}_9min.dscalar.nii"))
print("Saved ->", out_dir)
