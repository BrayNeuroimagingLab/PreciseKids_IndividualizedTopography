#!/bin/bash
# Create dconn

# Set the correct path to the script
cd /home/shefali.rai1/scripts_surfacebrains/
echo "Current working directory is $(pwd)"

# Use $RANDOM instead of Random
sleep $((RANDOM % 29))

echo "Loading MATLAB 2017b"
module load matlab/r2017b

((i=SLURM_ARRAY_TASK_ID-1))

# Check existence of subjects directory list file
subjects_file=/bulk/bray_bulk/Shefali_PreciseKIDS/datalist_child_dconn.txt #all children excludes 003C

if [ ! -e "${subjects_file}" ]; then
  >&2 echo "error: subjects file named datalist.txt does not exist"
  exit 1
fi

# read the subjects, session, and task txt files
IFS=$'\n'; subjects=( $(cat "${subjects_file}") )

MATDIR=/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir
export PATH=~/workbench/bin_rh_linux64:$PATH
export PATH=~/matlab:$PATH
export PATH=~/matlab/Utilities:$PATH
export PATH=~/matlab/gifti-1.6:$PATH

# which subjects are we running?
subject=${subjects[${i}]}
tasks="alltasks"

echo "Starting CreateDconn for each child subject at $(date)"

matlab -nodisplay -nodesktop -nosplash -r "arc_create_dconn_Leftover15min('$MATDIR/${subject}_alltasks_sample1_leftover15min.dtseries.nii', '${subject}', '${tasks}')"

echo "Finished CreateDconn for each child subject at $(date)"
