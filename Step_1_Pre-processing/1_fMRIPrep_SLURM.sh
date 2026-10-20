#!/bin/bash
#SBATCH --job-name=fmriprep
#SBATCH --output=/data/project/PSILAUT/logs/%j.out
#SBATCH --export=none
#SBATCH --mem=25G
#SBATCH --cpus-per-task=16
#SBATCH --array=1-173

# ================= SHELL Configuration ===================
source /software/system/modules/latest/init/bash
module use /software/system/modules/NaN/generic
module purge
module load nan 

# Load script dependent modules here
module load afni/22.3.07
module load fsl/6.0.7.10
module load c3d/1.0.0

module load freesurfer/7.3.2
# Source this after module is loaded.
source /software/system/freesurfer/7.3.2/SetUpFreeSurfer.sh

module load ants/2.4.0
module load bids-validator/1.14.0
module load fmriprep/23.0.1

# set the working variables
DATA=/data/project/PSILAUT/
INDEX=$DATA/job_index
#FILE= "`awk FNR==$SLURM_ARRAY_TASK_ID $INDEX`"
FILE=$( awk FNR==$SLURM_ARRAY_TASK_ID $INDEX ) 
INPUT=$DATA/data/sourcedata
WORK=$DATA/work/$FILE
OUTPUT=$DATA/output/$FILE

# Remove existing work and output sub-folders for the respective subject
if [ -e "$WORK" ];then rm -rf "$WORK" ; fi 
echo "Work directory is ready."
if [ -e "$OUTPUT" ];then rm -rf "$OUTPUT" ; fi   
echo "Output directory is ready."

echo "Running on $HOSTNAME"
echo "Array ID: $SLURM_ARRAY_JOB_ID"
echo "Task ID: $SLURM_ARRAY_TASK_ID"
echo "Processing $FILE"
# If this exists then freesurfer was setup
echo "FREESURFER_HOME "$FREESURFER_HOME

now=$(date +"%T")
echo "Start Time : $now"

fmriprep \
$INPUT \
$OUTPUT \
participant \
-w $WORK \
--participant_label $FILE \
--bold2t1w-dof 12 \
--task-id rest \
--dummy-scans 10 \
--skull-strip-t1w force \
--output-spaces MNI152NLin6Asym:res-2 MNI152NLin2009cAsym \
--write-graph \
--use-aroma \
--error-on-aroma-warnings \
--omp-nthreads 6 \
--nthreads 9 \
--fs-license-file /data/project/PSILAUT/fmriprep/license.txt \
--stop-on-first-crash

then=$(date +"%T")
echo "Finish Time : $then"

echo "Pre-processing completed."

