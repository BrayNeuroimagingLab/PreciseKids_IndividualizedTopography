#!/usr/bin/env python3
"""
9-min inputs to re-make Fig 4 (vertex-wise child vs adult
assignment differences) at 9 min instead of 60 min.

"""
import os, numpy as np, nibabel as nib

WTA_DIR   = "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
TEMPLATE  = ("/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
             "Allchildren_groupaverage_winnertakeall_HCPAdultChild_overlap_entropy.dscalar.nii")
OUT_BIN   = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/networkassignment_gradiation_9min"
OUT_DIFF  = "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/PanelA_ChildAdult_propdiff_9min"

N_CORTEX = 59412
N_GRAY = 91282
NETWORKS = [n for n in range(1, 17) if n not in (4, 6)]

subs = [f"{n:03d}" for n in range(2, 27) if n != 3]  # skip 003
CHILD = [f"1973{s}C" for s in subs]
ADULT = [f"1973{s}P" for s in subs]
ALL = CHILD + ADULT


def load_wta(sid):
    f = os.path.join(WTA_DIR, f"sub-{sid}_alltasks_HCPAdultChild_overlap_9min_sample1_Dice.dscalar.nii")
    if not os.path.exists(f):
        print("  MISSING 9min WTA:", sid)
        return None
    return np.round(np.asarray(nib.load(f).dataobj).squeeze()).astype(int)[:N_CORTEX]


def save_cifti(vec91282, path, template_img):
    img = nib.Cifti2Image(vec91282.reshape(1, -1).astype(np.float32),
                          header=template_img.header, nifti_header=template_img.nifti_header)
    nib.save(img, path)


def main():
    os.makedirs(OUT_BIN, exist_ok=True)
    os.makedirs(OUT_DIFF, exist_ok=True)
    tmpl = nib.load(TEMPLATE)

    wta = {}
    for sid in ALL:
        w = load_wta(sid)
        if w is not None:
            wta[sid] = w
    print(f"Loaded {len(wta)} subjects.")

    # 1. per-subject per-network binary maps
    for net in NETWORKS:
        for sid, w in wta.items():
            b = np.zeros(N_GRAY, dtype=np.float32)
            b[:N_CORTEX] = (w == net).astype(np.float32)
            save_cifti(b, os.path.join(OUT_BIN, f"Network{net}_Assignment_sub{sid}.dscalar.nii"), tmpl)
    print(f"Binary maps -> {OUT_BIN}")

    # 2. group child/adult proportion difference (Panel A)
    nC = sum(1 for s in CHILD if s in wta)
    nA = sum(1 for s in ADULT if s in wta)
    for net in NETWORKS:
        cprop = np.mean([(wta[s] == net) for s in CHILD if s in wta], axis=0)  # 59412
        aprop = np.mean([(wta[s] == net) for s in ADULT if s in wta], axis=0)
        diff = np.zeros(N_GRAY, dtype=np.float32)
        diff[:N_CORTEX] = (cprop - aprop).astype(np.float32)   # warm = children > adults
        save_cifti(diff, os.path.join(OUT_DIFF, f"Network{net}_ChildMinusAdult_propdiff_9min.dscalar.nii"), tmpl)
    print(f"Panel A diff maps (nC={nC}, nA={nA}) -> {OUT_DIFF}")
    print("Set Panel A palette to +/-0.6 (60%), warm=children>adults, to match 60-min Figure 4A.")


if __name__ == "__main__":
    main()
