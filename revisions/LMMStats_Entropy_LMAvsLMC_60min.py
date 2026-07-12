#!/usr/bin/env python3
"""
Per-vertex LMM: entropy ~ group(LMC vs LMA) + sex + motion + (1|family)
at 60min

Outputs same as Fig 5
  Entropy_LMAvsLMC_GroupBeta.dscalar.nii 
  Entropy_LMAvsLMC_Pvals_uncorrected.dscalar.nii
  Entropy_LMAvsLMC_GroupAverage_LMA.dscalar.nii
  Entropy_LMAvsLMC_GroupAverage_LMC.dscalar.nii
"""

import os, glob, warnings
import numpy as np
import pandas as pd
import nibabel as nib
import statsmodels.formula.api as smf
import statsmodels.api as sm
from statsmodels.tools.sm_exceptions import ConvergenceWarning

# suppress LMM convergence noise — expected with small N per-vertex models
warnings.filterwarnings("ignore", category=ConvergenceWarning)
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=RuntimeWarning)

ENTROPY_DIR  = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
COVAR_XLSX   = "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"
TEMPLATE     = os.path.join(ENTROPY_DIR,
               "Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii")
OUTPUT_DIR   = ENTROPY_DIR

lma_nums = [2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26]
lmc_nums = [2,5,7,9,15,18,21,23,25,26]

lma_ids = [f"1973{n:03d}P" for n in lma_nums]   # no "sub-" prefix (matches filenames)
lmc_ids = [f"1973{n:03d}C" for n in lmc_nums]

FILE_TOKEN = "matchedconditions_entropy.dscalar.nii"

tmpl        = nib.load(TEMPLATE)
n_vertices  = tmpl.get_fdata().shape[-1]
tmpl_header = tmpl.header
print(f"Template: {n_vertices} vertices")
#COVARS
covars = pd.read_excel(COVAR_XLSX)
covars["sub"] = covars["sub"].astype(str).str.strip()
covars["sex01"]  = covars["sex"].map({"M":0,"F":1,"m":0,"f":1}).astype(float)
covars["motion"] = covars["censored_volumes"].astype(float)
# z-score motion across the LMA+LMC subset
cov_dict = covars.set_index("sub")[["sex01","motion","family"]].to_dict("index")
#Entropy files
def find_entropy(sid):
    for patt in [f"*{sid}*{FILE_TOKEN}", f"*sub-{sid}*{FILE_TOKEN}"]:
        hits = glob.glob(os.path.join(ENTROPY_DIR, patt))
        if hits:
            return sorted(hits, key=os.path.getmtime, reverse=True)[0]
    return None

rows = []
entropy_mat = [] 

for sid, grp in [(s, "LMA") for s in lma_ids] + [(s, "LMC") for s in lmc_ids]:
    fp = find_entropy(sid)
    if fp is None:
        print(f"  missing entropy: {sid}"); continue
    if sid not in cov_dict:
        print(f"  missing covariates: {sid}"); continue

    data = nib.load(fp).get_fdata()[0, :]
    if data.shape[0] != n_vertices:
        print(f"  vertex mismatch: {sid}"); continue

    entropy_mat.append(data)
    rows.append({
        "sid":    sid,
        "group":  1 if grp == "LMC" else 0,   # LMC=1, LMA=0
        "sex":    cov_dict[sid]["sex01"],
        "motion": cov_dict[sid]["motion"],
        "family": str(cov_dict[sid]["family"]),
    })

df_sub = pd.DataFrame(rows)
entropy_mat = np.array(entropy_mat)   # [n_subjects, n_vertices]

# z-score motion
m_mot, s_mot = df_sub["motion"].mean(), df_sub["motion"].std()
if s_mot > 0:
    df_sub["motion"] = (df_sub["motion"] - m_mot) / s_mot

n_lma = (df_sub["group"] == 0).sum()
n_lmc = (df_sub["group"] == 1).sum()
print(f"Loaded: LMA={n_lma}, LMC={n_lmc}  total={len(df_sub)}")

# checkin group vs. motion confound before z-scoring
print("\n--- Diagnostic: motion (censored_volumes) by group (raw, pre z-score) ---")
print(df_sub.groupby("group")["motion"].describe())
grp_motion_corr = df_sub["group"].astype(float).corr(df_sub["motion"].astype(float))
print(f"Correlation(group, motion) = {grp_motion_corr:.3f}")
if abs(grp_motion_corr) > 0.4:
    print("  WARNING: group and motion are substantially correlated — "
          "the 'group' beta may be partly absorbing motion-driven variance.")

# group avg
lma_idx = df_sub["group"] == 0
lmc_idx = df_sub["group"] == 1

avg_lma = np.nanmean(entropy_mat[lma_idx.values, :], axis=0).reshape(1, -1)
avg_lmc = np.nanmean(entropy_mat[lmc_idx.values, :], axis=0).reshape(1, -1)

nib.save(nib.Cifti2Image(avg_lma, header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_GroupAverage_LMA.dscalar.nii"))
nib.save(nib.Cifti2Image(avg_lmc, header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_GroupAverage_LMC.dscalar.nii"))
print("Saved group average maps.")

# LMM per vertex: y ~ group + sex + motion + (1|family)
def fit_lmm(yv, df_base):
    df = df_base.copy()
    df["y"] = yv.astype(float)
    if np.isnan(df["y"]).all() or df["y"].nunique(dropna=True) <= 1:
        raise ValueError("no variation")
    model = smf.mixedlm("y ~ group + sex + motion", df, groups=df["family"])
    res   = model.fit(method="lbfgs", reml=True, maxiter=200, disp=False)
    return float(res.params.get("group", np.nan)), float(res.pvalues.get("group", np.nan))

def fit_fe(yv, df_base):
    """Fallback: family fixed effects OLS."""
    df = df_base.copy()
    df["y"] = yv.astype(float)
    if np.isnan(df["y"]).all() or df["y"].nunique(dropna=True) <= 1:
        raise ValueError("no variation")
    fam_dum = pd.get_dummies(df["family"], drop_first=True, dtype=float)
    X = pd.DataFrame({"Intercept":1.0, "group":df["group"].astype(float),
                       "sex":df["sex"].astype(float), "motion":df["motion"].astype(float)})
    if fam_dum.shape[1] > 0:
        X = pd.concat([X, fam_dum], axis=1)
    if np.linalg.matrix_rank(X.values) < min(X.shape):
        raise ValueError("rank-deficient")
    res = sm.OLS(df["y"].values, X.values).fit()
    return float(res.params[1]), float(res.pvalues[1])

coefs = np.full(n_vertices, np.nan)
pvals = np.full(n_vertices, np.nan)

# checkin which method actually produced each vertex's fit
n_lmm_used  = 0
n_fe_used   = 0
n_failed    = 0
n_skipped   = 0

for v in range(n_vertices):
    if v % 5000 == 0:
        print(f"  vertex {v}/{n_vertices}...")
    y = entropy_mat[:, v]
    valid = np.isfinite(y)
    if valid.sum() < 6:
        n_skipped += 1
        continue
    yv  = y[valid]
    dfv = df_sub.loc[valid].copy()
    try:
        try:
            coefs[v], pvals[v] = fit_lmm(yv, dfv)
            n_lmm_used += 1
        except Exception:
            coefs[v], pvals[v] = fit_fe(yv, dfv)
            n_fe_used += 1
    except Exception:
        n_failed += 1

n_fit_total = n_lmm_used + n_fe_used
print("\n--- Diagnostic: per-vertex fitting method breakdown ---")
print(f"  LMM converged : {n_lmm_used} / {n_vertices} "
      f"({100*n_lmm_used/n_vertices:.1f}%)")
print(f"  FE fallback   : {n_fe_used} / {n_vertices} "
      f"({100*n_fe_used/n_vertices:.1f}%)")
print(f"  Failed (NaN)  : {n_failed} / {n_vertices}")
print(f"  Skipped (<6)  : {n_skipped} / {n_vertices}")
if n_fit_total > 0 and (n_fe_used / n_fit_total) > 0.25:
    print("  WARNING: >25% of vertices required the FE fallback — with N="
          f"{len(df_sub)} subjects and family fixed effects, this can overfit "
          "and inflate apparent significance of the 'group' term. Treat the "
          "thresholded map with caution.")

valid_mask = np.isfinite(coefs) & np.isfinite(pvals)
print(f"\nValid fits: {valid_mask.sum()} / {n_vertices}")
print(f"p<0.05 (uncorrected): {int(np.sum(pvals < 0.05))}")
print(f"p<0.001 (uncorrected): {int(np.sum(pvals < 0.001))}")
print(f"Beta range: {np.nanmin(coefs):.3f} .. {np.nanmax(coefs):.3f}")

# save group beta and p-value maps as dscalar.nii (NaNs replaced with 0 for betas, 1 for pvals)
coef_map = np.nan_to_num(coefs, nan=0.0).reshape(1, -1)
pval_map = np.nan_to_num(pvals, nan=1.0).reshape(1, -1)

coef_out = os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_GroupBeta.dscalar.nii")
pval_out = os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_Pvals_uncorrected.dscalar.nii")

nib.save(nib.Cifti2Image(coef_map, header=tmpl_header), coef_out)
nib.save(nib.Cifti2Image(pval_map, header=tmpl_header), pval_out)

