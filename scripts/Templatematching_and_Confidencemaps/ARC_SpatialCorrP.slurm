#!/bin/bash
# ============================================
#SBATCH --job-name=SpatialCorrP
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200gb
#SBATCH --array=1-25
#SBATCH -o SpatialCorrP_processing.output
#SBATCH -e SpatialCorrP_processing.error
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_SpatialCorrP.sh
