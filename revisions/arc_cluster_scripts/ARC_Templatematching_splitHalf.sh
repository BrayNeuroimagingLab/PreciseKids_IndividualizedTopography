#!/bin/bash
# Template matching (Dice) for split-half samples.
# Called by slurm with DURATION and SAMPLE set via --export.
# e.g.  DURATION=15min  SAMPLE=1

cd /home/shefali.rai1/scripts_surfacebrains/
echo "Working directory: $(pwd)"
sleep $((RANDOM % 29))

echo "Loading MATLAB 2017b"
module load matlab/r2017b

((i=SLURM_ARRAY_TASK_ID-1))

subjects_file=/bulk/bray_bulk/Shefali_PreciseKIDS/datalist.txt
if [ ! -e "${subjects_file}" ]; then
  >&2 echo "error: datalist.txt not found"
  exit 1
fi

IFS=$'\n'; subjects=( $(cat "${subjects_file}") )
subject=${subjects[${i}]}
task="alltasks"

MATDIR=/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir
export PATH=~/workbench/bin_rh_linux64:$PATH
export PATH=~/matlab:$PATH
export PATH=~/matlab/BCT:$PATH
export PATH=~/matlab/Utilities:$PATH
export PATH=~/matlab/gifti-1.6:$PATH

echo "Subject: ${subject}  Duration: ${DURATION}  Sample: ${SAMPLE}"
echo "Starting Templatematching split-half at $(date)"

matlab -nodisplay -nodesktop -nosplash -r \
  "ARC_Templatematching_PKdata_splitHalf('${subject}', '${task}', '${DURATION}', '${SAMPLE}')"

echo "Finished Templatematching split-half at $(date)"
