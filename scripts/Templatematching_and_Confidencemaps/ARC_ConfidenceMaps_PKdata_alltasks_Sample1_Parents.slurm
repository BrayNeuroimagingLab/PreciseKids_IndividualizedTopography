#!/bin/bash
# ============================================
#SBATCH --job-name=ConfidenceMaps_PKdata_Sample1_alltasks_Parents
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200gb
#SBATCH --array=1-24
#SBATCH -o ConfidenceMaps_PKdata_Sample1_alltasks_Parents.output
#SBATCH -e ConfidenceMaps_PKdata_Sample1_alltasks_Parents.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_ConfidenceMaps_PKdata_alltasks_Sample1_Parents.sh
