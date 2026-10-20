#!/bin/bash

# Load Miniconda module if needed
# module load miniconda

# Create a new Conda environment if it does not exist
if ! conda info --envs | grep -q 'post-fmriprep_env'; then
    conda create -n post-fmriprep_env -c conda-forge -y python=3.8 pandas scipy nibabel nilearn
fi

# Activate the Conda environment
source activate post-fmriprep_env

# Run the Python script
python /data/project/PSILAUT/2_post-fMRIPrep_processing.py /data/project/PSILAUT/Freesurfer_final/output/ cosine00 cosine01 cosine02 cosine03 csf white_matter
