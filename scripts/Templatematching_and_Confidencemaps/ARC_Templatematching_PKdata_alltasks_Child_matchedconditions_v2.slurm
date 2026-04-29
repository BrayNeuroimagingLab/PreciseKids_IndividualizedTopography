#!/bin/bash
# ============================================
#SBATCH --job-name=Templatematching_matchedconditions_Child
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=200gb
#SBATCH --array=1-24
#SBATCH -o Templatematching_matchedconditions_Child.output
#SBATCH -e Templatematching_matchedconditions_Child.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_Templatematching_PKdata_alltasks_Child_matchedconditions_v2.sh
