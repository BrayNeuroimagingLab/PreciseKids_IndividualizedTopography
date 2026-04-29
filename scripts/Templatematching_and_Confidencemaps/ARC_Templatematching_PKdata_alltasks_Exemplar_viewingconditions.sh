#!/bin/bash

cd /home/shefali.rai1/scripts_surfacebrains/
echo "Current working directory is `pwd`"

sleep $((Random % 29)) # this is here to prevent errors when
# multiple jobs attempt to start at the exact same time

echo "Loading MATLAB 2017b"
module load matlab/r2017b

((i=SLURM_ARRAY_TASK_ID-1))

#check existence of subjects directory list file
subjects_file=/bulk/bray_bulk/Shefali_PreciseKIDS/datalist_exemplarparent_dconn.txt

if [ ! -e "${subjects_file}" ]; then
  >&2 echo "error: subjects file named datalist.txt does not exist"
  exit 1
fi

# read the subjects, session and task txt files
IFS=$'\n'; subjects=( $(cat "${subjects_file}") );

MATDIR=/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir
export PATH=~/workbench/bin_rh_linux64:$PATH
export PATH=~/matlab:$PATH
export PATH=~/matlab/BCT:$PATH
export PATH=~/matlab/Utilities:$PATH
export PATH=~/matlab/gifti-1.6:$PATH

# which subjects are we running?
subject=${subjects[${i}]}
#subject="sub-1973011P"

tasks=("task-DORA" "task-RX" "task-YT")
#tasks="task-YT"

echo "Starting Template matching for PK Exemplar data vertex wise at `date`"

for task in "${tasks[@]}"; do
    matlab -nodisplay -nodesktop -nosplash -r "ARC_Templatematching_PKdata_alltasks_Exemplar_viewingconditions('${subject}', '${task}')"
done


echo "Finished Template matching for PK Exemplar data vertex wise at `date`"
