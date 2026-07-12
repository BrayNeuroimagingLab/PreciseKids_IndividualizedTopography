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
├── revisions/      # Revision analysis scripts (age, motion, and data length)
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

## Revision Analyses

Scripts in `revisions/` extend the main analyses to examine effects of age, head
motion, and amount of data (scan time). Paths at the top of each script point to
local data locations. Motion groups are LMA (low-motion adults), LMC (low-motion
children), and HMC (high-motion children).

### Surface Area

**`SurfaceArea_AgeByNetwork.R`**
Within-motion-group age-by-network surface-area models.

### Density and Proportion Maps

**`CreateMotionGroup_DensityMaps.py` / `CreateMotionGroup_DensityMaps_9min.py`** *(Python)*
Per-network group density maps for each motion group at 60 and 9 minutes.

**`MakeProportion_FromDensity_60min.py`** *(Python)*
Converts density maps to proportion (density / N) so motion groups of different sizes are comparable.

**`Figure3_MotionGroups_DensityMaps.m` / `Figure3_MotionGroups_ProportionMaps.m`**
Apply Connectome Workbench palettes to the density and proportion maps for figures.

**`FamilyMatched_LMA10_Figure_and_Table.py`** *(Python)*
Family-matched low-motion comparison (low-motion children vs their parents) of network spatial spread.

### Assignment Confidence (Entropy) and Reliability

**`Figure5_PanelA_GroupMeanEntropy.py`** *(Python)*
Group-mean vertex-wise entropy maps for children and adults at 9 and 60 minutes.

**`Figure5_PanelB_Vertexwise_Entropy_9min.py`** *(Python)*
Per-vertex mixed model of entropy (child vs adult) at 9 minutes.

**`Figure5_Entropy_NMIcontrol.py`** *(Python)*
Mean entropy controlled for topographic reliability (30-minute split-half NMI) and head motion.

**`Entropy_IncreasingData_Stats.R`**
Mean entropy across data lengths (9, 15, 30, 60 minutes) by motion group.

**`NMI_IncreasingData_Stats.R`**
Split-half NMI reliability across data lengths by motion group.

### Similarity

**`FamilialSimilarity_SexDyad.R` / `WithinGroup_SexDyad.R`**
Related vs unrelated (and within-group) Dice similarity, recoded by sex dyad (MM / FF / MF).

### Split-Half Sampling (cluster)

**`MatchedCensoring_NetworkMaps_Revisions9min_SplitHalf.m` / `15min` / `30min`**
Matched-censoring split-half network maps at 9, 15, and 30 minutes. `arc_cluster_scripts/` holds the associated SLURM and shell job scripts.

---

## Notes on Visualization

- Open `.dscalar.nii` output files in **Connectome Workbench** (`wb_view`)
- Load the appropriate `.spec` file from your `data_path/subject/MNINonLinear/fsaverage_LR32k` folder
- Set the surface view to `inflated.32k_fs_LR.surf.gii` for both hemispheres

---

## Citation

If you use these scripts, please cite our bio archive doi: https://doi.org/10.64898/2026.03.05.709899
