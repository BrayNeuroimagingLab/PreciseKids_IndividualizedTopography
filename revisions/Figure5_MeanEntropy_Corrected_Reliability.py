#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mean-entropy model with the correct family structure plus a reliability covariate.
Family is taken from prckids-motion_beh.xlsx (22 families: parents, children, and
siblings). Runs the base model, the model with 30-min split-half connectome
reliability added, and a mediation of age -> reliability -> entropy.
"""
import warnings
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
import pingouin as pg
warnings.filterwarnings("ignore")

entropy_csv = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
               "entropy_analysis/subject_statistics_entropy_with_familyID_motion.csv")
covar_xlsx = "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"
reliab_csv = "/Users/shefalirai/Desktop/Prckids/connectome_correlation_data.csv"
out_txt = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/Figure5_MeanEntropy_Corrected_results.txt"

ent = pd.read_csv(entropy_csv)
ent['ID'] = ent.subject_id.str.replace('sub-', '')
cov = pd.read_excel(covar_xlsx).rename(columns={'sub': 'ID'})
cov['ID'] = cov['ID'].astype(str).str.strip()
rel = pd.read_csv(reliab_csv)
rel30 = rel[rel.time == 30][['subject_id', 'correlation']].rename(columns={'correlation': 'reliab'})
rel30['ID'] = rel30.subject_id.str.replace('sub-', '')

d = ent.merge(cov[['ID', 'family']], on='ID').merge(rel30[['ID', 'reliab']], on='ID')
d['group'] = pd.Categorical(d['group'], categories=['adult', 'child'])
d['child'] = (d.group == 'child').astype(float)
d['sexF'] = (d['sex'] == 'F').astype(float)

lines = []
def log(s):
    print(s)
    lines.append(s)

log(f"N = {len(d)} subjects, {d.family.nunique()} families\n")

def fit(formula, tag):
    m = smf.mixedlm(formula, d, groups=d['family']).fit()
    log(f"--- {tag} ---\n    {formula}")
    for t in ['group[T.child]', 'sex[T.F]', 'censored_volumes', 'reliab']:
        if t in m.params.index:
            log(f"    {t} beta={m.params[t]:+.5f}  z={m.tvalues[t]:+.3f}  p={m.pvalues[t]:.4g}")
    log("")

log("===== mean entropy, 22-family structure =====\n")
fit("mean ~ group + sex + censored_volumes", "base (no reliability)")
fit("mean ~ group + sex + censored_volumes + reliab", "with reliability")

log("===== mediation: age -> reliability -> entropy (covar sex, motion) =====")
med = pg.mediation_analysis(data=d, x='child', m='reliab', y='mean',
                            covar=['sexF', 'censored_volumes'], n_boot=5000, seed=0)
log(med.round(4).to_string(index=False))
prop = med.loc[med.path == 'Indirect', 'coef'].values[0] / med.loc[med.path == 'Total', 'coef'].values[0]
log(f"\nProportion mediated by reliability: {prop*100:.0f}%")

with open(out_txt, "w") as f:
    f.write("\n".join(lines))
print(f"Saved -> {out_txt}")
