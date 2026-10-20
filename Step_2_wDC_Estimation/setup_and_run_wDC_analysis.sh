#!/bin/bash
#SBATCH --job-name=PSILAUT_wDC
#SBATCH --output=/data/project/PSILAUT/wDC/logs/wDC/%j.out
#SBATCH --export=none
#SBATCH --mem=56G
#SBATCH --cpus-per-task=2
#SBATCH --array=1-173 # 173 in total

# ================= SHELL Configuration ===================
source /software/system/modules/latest/init/bash
module use /software/system/modules/NaN/generic
module purge
module load nan 

# Load script dependent modules here
module load miniconda

# Define paths
# Load fMRI filenames from a txt file (one filename per line)
fMRI_txt="/data/project/PSILAUT/wDC/BOLD/psilaut_sessions_3mm.txt"
fMRI_image=$( awk FNR==$SLURM_ARRAY_TASK_ID $fMRI_txt )
# Load GM mask
GM_mask="/data/project/PSILAUT/wDC/Masks/GM/binary_GM_Mask_3mm.nii.gz"

# Create a new Conda environment if it does not exist
if ! conda info --envs | grep -q 'wDC'; then
    conda env create -f wDC.yml
fi

# Activate the Conda environment
source activate wDC

now=$(date +"%s")  # Get the current time in seconds since the epoch
echo "Start Time : $(date +"%T")"

echo "Running wDC analysis on $fMRI_image"

# Run the Python script
/usr/bin/time -v python DC.py $fMRI_image $GM_mask

then=$(date +"%s")  # Get the end time in seconds since the epoch
echo "Finish Time : $(date +"%T")"

# Calculate the difference in seconds
diff=$((then - now))

# Convert seconds to hours
hours=$(echo "scale=2; $diff / 3600" | bc)

echo "Time taken: $hours hours"

echo "wDC analysis completed."


