#!/bin/bash
# ============================================
#SBATCH --job-name=CreateDconnP15min
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=100gb
#SBATCH --array=1-25
#SBATCH -o CreateDconnP_processing.output
#SBATCH -e CreateDconnP_processing.error
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_CreateDconn_Leftover15min_Parent_Alltasks.sh
