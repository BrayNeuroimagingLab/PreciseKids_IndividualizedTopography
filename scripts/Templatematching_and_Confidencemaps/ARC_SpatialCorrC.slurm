#!/bin/bash
# ============================================
#SBATCH --job-name=SpatialCorrC
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200gb
#SBATCH --array=1-25
#SBATCH -o SpatialCorrC_processing.output
#SBATCH -e SpatialCorrC_processing.error
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_SpatialCorrC.sh
