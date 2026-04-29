#!/bin/bash

cd /home/shefali.rai1/scripts_surfacebrains/
echo "Current working directory is `pwd`"

sleep $((Random % 29)) # this is here to prevent errors when
# multiple jobs attempt to start at the exact same time

echo "Loading MATLAB 2017b"
module load matlab/r2017b

((i=SLURM_ARRAY_TASK_ID-1))

MATDIR=/bulk/bray_bulk/Shefali_PreciseKIDS/newmc_matlabdir
export PATH=~/workbench/bin_rh_linux64:$PATH
export PATH=~/matlab:$PATH
export PATH=~/matlab/Utilities:$PATH
export PATH=~/matlab/gifti-1.6:$PATH

# which subjects are we running?
subject="sub-1973006C"

task="alltasks"

echo "Starting Template matching for PK Child data vertex wise at `date`"

matlab -nodisplay -nodesktop -nosplash -r "ARC_Templatematching_PKdata_Vertexwise_followup('${subject}', '${task}')"

echo "Finished Template matching for PK Child data vertex wise at `date`"
