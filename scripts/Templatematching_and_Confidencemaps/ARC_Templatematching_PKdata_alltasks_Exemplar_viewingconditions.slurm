#!/bin/bash
# ============================================
#SBATCH --job-name=Templatematching_viewingconditions_Exemplar
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=200gb
#SBATCH --array=1-8
#SBATCH -o Templatematching_viewingconditions_Exemplar.output
#SBATCH -e Templatematching_viewingconditions_Exemplar.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_Templatematching_PKdata_alltasks_Exemplar_viewingconditions.sh
