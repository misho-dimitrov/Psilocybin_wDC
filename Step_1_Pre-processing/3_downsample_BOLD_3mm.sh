#!/bin/bash
#SBATCH --job-name=psilaut_3mm
#SBATCH --output=/data/project/PSILAUT/wDC/logs/resample/%j.out
#SBATCH --export=none
#SBATCH --mem=8G
#SBATCH --cpus-per-task=2
#SBATCH --array=3-173

# ================= SHELL Configuration ===================
source /software/system/modules/latest/init/bash
module use /software/system/modules/NaN/generic
module purge
module load nan 

# Load script dependent modules here
module load fsl

# set the working variables
DATA=/data/project/PSILAUT/wDC/BOLD
cd $DATA
INDEX=$DATA/job_index
#echo $INDEX
FILE="`awk FNR==$SLURM_ARRAY_TASK_ID $INDEX`"
#FILE=$( awk '{FNR==$SLURM_ARRAY_TASK_ID}' $INDEX )
#echo $FILE 

echo "Starting the resampling process.."
echo "Running on $HOSTNAME"
echo "Array ID: $SLURM_ARRAY_JOB_ID"
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Processing $FILE"

# Set the path to the identity mat
IDENTITY_MAT="/data/project/PSILAUT/wDC/BOLD/identity.mat"

# Set the session name
base_name=$(basename "${FILE}" .nii.gz)

# Construct the output filename
output_file="${base_name}_3mm.nii.gz"

# Run the flirt command for resampling
/usr/bin/time -v flirt -in "${FILE}" -ref "${FILE}" -applyisoxfm 3 -init "${IDENTITY_MAT}" -out "${output_file}"

echo "Resampled ${FILE} to ${output_file}"


