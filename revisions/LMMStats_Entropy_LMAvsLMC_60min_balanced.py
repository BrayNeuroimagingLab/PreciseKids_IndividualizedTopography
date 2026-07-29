#!/usr/bin/env python3
"""
Per-vertex LMM REDO again wihtout motion: entropy ~ group(LMC vs LMA) + sex + (1|family)
at 60 min

  - Original unbalanced: LMA n=22 vs LMC n=10. The larger LMA
    sample maybe  dominating per-vertex variance
    -dropped motion covariate, since groups are pre-stratified by motion 
    (i.e. LMA subjects were selected to match the LMC subjects on motion)

This script does:
  - random subsample of n_LMC (=10) subjects from the 22
    LMA subjects, pair with all 10 LMC subjects (balanced 10 vs 10), and
    refit the per-vertex LMM each iteration.
  - Average beta maps across iterations, and combine the
    p-values across iterations using Fisher's method


"""

import os, glob, warnings
import numpy as np
import pandas as pd
import nibabel as nib
import statsmodels.formula.api as smf
import statsmodels.api as sm
from statsmodels.tools.sm_exceptions import ConvergenceWarning
from scipy.stats import chi2

warnings.filterwarnings("ignore", category=ConvergenceWarning)
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=RuntimeWarning)

ENTROPY_DIR = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
COVAR_XLSX  = "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"
TEMPLATE    = os.path.join(ENTROPY_DIR,
              "Allchildren_groupaverage_winnertakeall_alltasks_HCPAdultChild_overlap_14networkassignment.dscalar.nii")
OUTPUT_DIR  = ENTROPY_DIR
#check with 10 iterations for now; can increase later (longer)
N_ITER       = 10
RANDOM_SEED  = 42
rng          = np.random.default_rng(RANDOM_SEED)

lma_nums = [2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26]
lmc_nums = [2,5,7,9,15,18,21,23,25,26]

lma_ids = [f"1973{n:03d}P" for n in lma_nums]
lmc_ids = [f"1973{n:03d}C" for n in lmc_nums]
n_lmc   = len(lmc_ids)   

FILE_TOKEN = "matchedconditions_entropy.dscalar.nii"

tmpl        = nib.load(TEMPLATE)
n_vertices  = tmpl.get_fdata().shape[-1]
tmpl_header = tmpl.header
print(f"Template: {n_vertices} vertices")

# COVARS 
covars = pd.read_excel(COVAR_XLSX)
covars["sub"]   = covars["sub"].astype(str).str.strip()
covars["sex01"] = covars["sex"].map({"M": 0, "F": 1, "m": 0, "f": 1}).astype(float)
cov_dict = covars.set_index("sub")[["sex01", "family"]].to_dict("index")


def find_entropy(sid):
    for patt in [f"*{sid}*{FILE_TOKEN}", f"*sub-{sid}*{FILE_TOKEN}"]:
        hits = glob.glob(os.path.join(ENTROPY_DIR, patt))
        if hits:
            return sorted(hits, key=os.path.getmtime, reverse=True)[0]
    return None


rows, entropy_mat = [], []
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
        "family": str(cov_dict[sid]["family"]),
    })

df_sub      = pd.DataFrame(rows)
entropy_mat = np.array(entropy_mat)   # [n_subjects, n_vertices]

lma_idx_all = np.where(df_sub["group"].values == 0)[0]
lmc_idx_all = np.where(df_sub["group"].values == 1)[0]
print(f"Loaded: LMA={len(lma_idx_all)}, LMC={len(lmc_idx_all)}  total={len(df_sub)}")

# group-average maps
avg_lma = np.nanmean(entropy_mat[lma_idx_all, :], axis=0).reshape(1, -1)
avg_lmc = np.nanmean(entropy_mat[lmc_idx_all, :], axis=0).reshape(1, -1)
nib.save(nib.Cifti2Image(avg_lma, header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_Balanced_GroupAverage_LMA.dscalar.nii"))
nib.save(nib.Cifti2Image(avg_lmc, header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_Balanced_GroupAverage_LMC.dscalar.nii"))
print("Saved group average maps.")


# Per-vertex LMM: y ~ group + sex + (1|family) (motion none)
def fit_lmm(yv, df_base):
    df = df_base.copy()
    df["y"] = yv.astype(float)
    if np.isnan(df["y"]).all() or df["y"].nunique(dropna=True) <= 1:
        raise ValueError("no variation")
    model = smf.mixedlm("y ~ group + sex", df, groups=df["family"])
    res   = model.fit(method="lbfgs", reml=True, maxiter=200, disp=False)
    return float(res.params.get("group", np.nan)), float(res.pvalues.get("group", np.nan))


def fit_fe(yv, df_base):
    """Fallback: family fixed effects OLS."""
    df = df_base.copy()
    df["y"] = yv.astype(float)
    if np.isnan(df["y"]).all() or df["y"].nunique(dropna=True) <= 1:
        raise ValueError("no variation")
    fam_dum = pd.get_dummies(df["family"], drop_first=True, dtype=float)
    X = pd.DataFrame({"Intercept": 1.0,
                      "group": df["group"].astype(float),
                      "sex":   df["sex"].astype(float)})
    if fam_dum.shape[1] > 0:
        X = pd.concat([X, fam_dum], axis=1)
    if np.linalg.matrix_rank(X.values) < min(X.shape):
        raise ValueError("rank-deficient")
    res = sm.OLS(df["y"].values, X.values).fit()
    return float(res.params[1]), float(res.pvalues[1])


coefs_iter = np.full((N_ITER, n_vertices), np.nan)
pvals_iter = np.full((N_ITER, n_vertices), np.nan)

for it in range(N_ITER):
    sub_lma_idx = rng.choice(lma_idx_all, size=n_lmc, replace=False)
    keep_idx    = np.concatenate([sub_lma_idx, lmc_idx_all])
    df_iter     = df_sub.iloc[keep_idx].reset_index(drop=True)
    mat_iter    = entropy_mat[keep_idx, :]

    print(f"\n=== Iteration {it+1}/{N_ITER}  "
          f"(LMA subsample subs: {df_iter.loc[df_iter.group==0,'sid'].tolist()}) ===")

    n_lmm_used = n_fe_used = n_failed = n_skipped = 0
    for v in range(n_vertices):
        if v % 20000 == 0:
            print(f"  vertex {v}/{n_vertices}...")
        y = mat_iter[:, v]
        valid = np.isfinite(y)
        if valid.sum() < 6:
            n_skipped += 1
            continue
        yv  = y[valid]
        dfv = df_iter.loc[valid].copy()
        try:
            try:
                coefs_iter[it, v], pvals_iter[it, v] = fit_lmm(yv, dfv)
                n_lmm_used += 1
            except Exception:
                coefs_iter[it, v], pvals_iter[it, v] = fit_fe(yv, dfv)
                n_fe_used += 1
        except Exception:
            n_failed += 1

    print(f"  iter {it+1}: LMM={n_lmm_used}  FE={n_fe_used}  "
          f"failed={n_failed}  skipped={n_skipped}")

# combine
mean_beta = np.nanmean(coefs_iter, axis=0)

# Fisher's combined-probability test per vertex across the N_ITER draws
with np.errstate(divide="ignore"):
    valid_p = np.clip(pvals_iter, 1e-300, 1.0)
    fisher_stat = -2.0 * np.nansum(np.log(valid_p), axis=0)
    n_valid     = np.sum(np.isfinite(pvals_iter), axis=0)
    fisher_p    = np.full(n_vertices, np.nan)
    has_valid   = n_valid > 0
    fisher_p[has_valid] = chi2.sf(fisher_stat[has_valid], df=2 * n_valid[has_valid])

prop_sig = np.nanmean(pvals_iter < 0.05, axis=0)

print(f"\n=== Combined across {N_ITER} balanced draws ===")
print(f"Mean beta range: {np.nanmin(mean_beta):.3f} .. {np.nanmax(mean_beta):.3f}")
print(f"Fisher-combined p<0.05: {int(np.nansum(fisher_p < 0.05))}")
print(f"Fisher-combined p<0.001: {int(np.nansum(fisher_p < 0.001))}")
print(f"Vertices significant (p<0.05) in >=80% of draws: "
      f"{int(np.nansum(prop_sig >= 0.8))}")
print(f"Vertices significant (p<0.05) in 0% of draws: "
      f"{int(np.nansum(prop_sig == 0))}")

beta_map     = np.nan_to_num(mean_beta, nan=0.0).reshape(1, -1)
fisher_map   = np.nan_to_num(fisher_p,  nan=1.0).reshape(1, -1)
propsig_map  = np.nan_to_num(prop_sig,  nan=0.0).reshape(1, -1)

nib.save(nib.Cifti2Image(beta_map,    header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_Balanced_GroupBeta_mean.dscalar.nii"))
nib.save(nib.Cifti2Image(fisher_map,  header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_Balanced_Pvals_Fisher.dscalar.nii"))
nib.save(nib.Cifti2Image(propsig_map, header=tmpl_header),
         os.path.join(OUTPUT_DIR, "Entropy_LMAvsLMC_Balanced_PropSig_p05.dscalar.nii"))

print("\nDone. Saved balanced-redo beta, Fisher-combined p-value, and "
      "proportion-significant maps.")
