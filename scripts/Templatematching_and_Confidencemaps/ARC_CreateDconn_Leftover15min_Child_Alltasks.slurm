#!/bin/bash
# ============================================
#SBATCH --job-name=CreateDconnC15min
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=100gb
#SBATCH --array=1-25
#SBATCH -o CreateDconnC_processing.output
#SBATCH -e CreateDconnC_processing.error
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_CreateDconn_Leftover15min_Child_Alltasks.sh
