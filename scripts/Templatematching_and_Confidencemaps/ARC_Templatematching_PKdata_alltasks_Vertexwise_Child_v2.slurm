#!/bin/bash
# ============================================
#SBATCH --job-name=Templatematching_PKdata_Vertexwise_alltasks_Child
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200gb
#SBATCH --array=1-24
#SBATCH -o Templatematching_PKdata_Vertexwise_alltasks_Child.output
#SBATCH -e Templatematching_PKdata_Vertexwise_alltasks_Child.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_Templatematching_PKdata_alltasks_Vertexwise_Child_v2.sh
