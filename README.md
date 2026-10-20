# Psilocybin wDC

Analysis pipeline for a resting-state fMRI study of psilocybin in autistic and non-autistic individuals, estimating
voxel-wise weighted degree centrality (wDC) and testing for group/dose
effects with linear mixed models.

The pipeline is organized into four sequential steps, each in its own folder.

## Pipeline overview

### [Step_1_Pre-processing/](Step_1_Pre-processing)
- `1_fMRIPrep_SLURM.sh` — runs [fMRIPrep](https://fmriprep.org/) (with AROMA
  denoising) on raw BIDS data via a SLURM array job.
- `2_post-fMRIPrep_processing.py` / `2_setup_and_run_post-fMRIPrep_processing.sh`
  — additional confound regression and standardization of the fMRIPrep output,
  producing denoised, z-scored BOLD timeseries images.
- `3_downsample_BOLD_3mm.sh` — resamples the denoised BOLD images to 3mm
  isotropic resolution (via FSL `flirt`) ahead of the wDC estimation step.

### [Step_2_wDC_Estimation/](Step_2_wDC_Estimation)
Voxel-wise weighted degree centrality estimation:
- `DC.py` — orchestrates the full per-subject wDC pipeline (entry point run
  by `setup_and_run_wDC_analysis.sh`).
- `img_load.py` / `mask_img_load.py` — load the BOLD image and grey-matter mask.
- `extract_time_series.py` — extracts voxel-wise timeseries within the mask.
- `cos_sim_func.py` — computes the voxel-by-voxel cosine similarity
  (connectivity/adjacency) matrix.
- `thresh_mat.py` — thresholds the adjacency matrix (r > 0.25).
- `to_graph_tool.py` — builds an undirected, weighted graph from the
  thresholded adjacency matrix using `graph-tool`.
- `calc_dc.py` — computes weighted degree centrality from the graph.
- `z_score_dc.py` — z-scores the resulting wDC values.
- `array_to_nifti.py` — converts the wDC array back into a NIfTI image.
- `wDC.yml` — conda environment specification for this step.

### [Step_3_Statistical_Analysis/](Step_3_Statistical_Analysis)
Voxel-wise linear mixed-model (LMM) analysis of the wDC maps in R:
- `Stats_Main.R` — fits `wDC ~ group * drug + (1|id)` per voxel across all
  subjects/sessions and produces t-statistic maps, followed by pTFCE
  cluster enhancement.
- `Stats_Within_2mg.R` / `Stats_Within_5mg.R` — within-group, within-dose
  follow-up models (`wDC ~ drug + (1|id)`) for the 2mg and 5mg sessions.
- Corresponding `SLURM_Stats_*.sh` scripts submit each R script as a SLURM job.
- `PSILAUT_Stats_env.yml` — conda environment specification for this step.

### [Step_4_Summary_and_Visualisations/](Step_4_Summary_and_Visualisations)
Post-hoc summary and plotting notebooks:
- `1_annotate_voxels_with_clusters_and_labels.ipynb` — labels significant
  voxel clusters in a Z-score map with anatomical (Harvard-Oxford,
  cerebellar) and functional network (Yeo 7-network/Buckner) atlases.
- `2_simple_descriptive_stats_from_csv.ipynb` — descriptive summaries
  (voxel counts, peak Z-scores) per anatomical region and network, exported
  to Excel.
- `3_plot_final_results_simple.ipynb` — plots thresholded Z-score maps on
  the MNI152 template across multiple slices, optionally overlaid with
  default mode network (DMN) contours.

## Requirements

Each step provides its own environment file:
- Step 2: `Step_2_wDC_Estimation/wDC.yml` (conda/Python)
- Step 3: `Step_3_Statistical_Analysis/PSILAUT_Stats_env.yml` (conda/R)

Step 1 relies on environment modules (AFNI, FSL, FreeSurfer, ANTs,
BIDS-validator, fMRIPrep) loaded on the compute cluster — see the module
`load` calls at the top of `1_fMRIPrep_SLURM.sh`.

## Notes

- All scripts were written to run on a SLURM-managed HPC cluster and contain
  cluster-specific absolute paths (e.g. `/data/project/PSILAUT/...`) that
  will need to be adjusted for your own environment.
- Notebooks in Step 4 reference a local output directory
  (`/Users/X/PSILAUT/wDC/Output`) that should be updated to your own path.
