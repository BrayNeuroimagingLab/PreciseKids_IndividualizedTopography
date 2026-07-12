# PreciseKids — Individualized Topography

This repository contains MATLAB, Python, R, and shell scripts supporting the following work:

> **Individualized network topography in pre-adolescent children and adults using naturalistic precision fMRI**

> First-author and script creation: Shefali Rai
> Under Review
> BioRxiv DOI: https://doi.org/10.64898/2026.03.05.709899

This repository covers  **individualized network topography** analyses using naturalistic precision fMRI data, including generation of individual-level network maps, comparison with HCP templates, surface area gradiation, and network similarity between adults and children.

---

## Repository Structure

```
PreciseKids_IndividualizedTopography/
├── scripts/        # MATLAB, Python, R, and shell analysis scripts
├── data/           # Supporting data files
└── README.md
```

---

## Requirements

- **MATLAB R2021b** or later
- **Python 3** (for vertex-wise proportion assignment)
- **R** (for VertexwiseR TFCE analyses)
- Connectome Workbench (`wb_view`, `wb_command`) for visualization
- `cifti-matlab` and `gifti-1.6` in your MATLAB path

---

## Script Descriptions

### Network Map Generation

**`MatchedCensoring_NetworkMaps_Allsubs.m`**
Censors data across all tasks and sessions, then uses a sliding-window approach to randomly draw matched sections of usable (good) and censored data equally across sessions into two independent samples (Sample 1 and Sample 2). Note: since sampling is still within-session, this is split-half iterative sampling rather than true test-retest.

**`createMaxDice_WinnerTakeAll.m`**
Creates a group-average network map using a winner-take-all (median) approach across participants. Used to generate the visual children and adult average maps.

### HCP Template Comparisons

**`HCP_overlapbetweentemplates.m`**
Quantifies the overlap between the Dworetsky HCP adult template and the HCP 8–9 year old template.

**`HCP_overlaptemplate_creation.m`**
Creates the overlap map between the two HCP templates for visualization.

**`HCPOverlap_AllDiceValues_ExtractNetworkValues.m`**
Extracts the full range of Dice overlap values per network for each participant. Recommended as input for VertexwiseR TFCE analyses, since it preserves the continuous range of values per person.

**`ExtractBinaryNetworks_HCPoverlapnetworks.m`**
Extracts each network column as a binary mask and saves it separately as a `.dscalar.nii` file. Note: not recommended for VertexwiseR TFCE since the binary output loses within-person variability.

### Network Proportion & Surface Area

**`NetworkPropDiff_Sample1.m`**
For each vertex, computes the proportion of children and adults assigned to each network, then visualizes the absolute difference as a `.dscalar` map. Uses output from `EachVertex_ProportionAssignment.py`.

**`EachVertex_ProportionAssignment.py`** *(Python)*
Computes child-minus-adult network assignment proportions at each vertex and outputs a `differences.txt` file used by `NetworkPropDiff_Sample1.m`.

**`SurfaceArea_Gradiation.m`**
Computes surface area and HCP overlap network assignment for each participant to generate gradiation (density) maps across all individuals — not averaged across participants.

---

## Notes on Visualization

- Open `.dscalar.nii` output files in **Connectome Workbench** (`wb_view`)
- Load the appropriate `.spec` file from your `data_path/subject/MNINonLinear/fsaverage_LR32k` folder
- Set the surface view to `inflated.32k_fs_LR.surf.gii` for both hemispheres

---

## Citation

If you use these scripts, please cite our bio archive doi: https://doi.org/10.64898/2026.03.05.709899
