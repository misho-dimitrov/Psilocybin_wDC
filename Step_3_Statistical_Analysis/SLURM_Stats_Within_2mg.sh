#!/bin/bash
#SBATCH --job-name=PSILAUT_wDC_Stats
#SBATCH --output=/data/project/PSILAUT/wDC/logs/Stats/%j.out
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --cpus-per-task=16

# ================= SHELL Configuration ===================
source /software/system/modules/latest/init/bash
module use /software/system/modules/NaN/generic
module purge
module load nan 

# Load conda
module load miniconda/3

# Activate the environment
conda activate PSILAUT_Stats_env

# Run the R script
/usr/bin/time -v Rscript Stats_Within_2mg.R


