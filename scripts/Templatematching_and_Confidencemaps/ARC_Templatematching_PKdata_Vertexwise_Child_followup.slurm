#!/bin/bash
# ============================================
#SBATCH --job-name=Templatematching_Child_followup
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=350gb
#SBATCH --array=1-2
#SBATCH -o Templatematching_Child_followup.output
#SBATCH -e Templatematching_Child_followup.error
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_Templatematching_PKdata_Vertexwise_Child_followup.sh
