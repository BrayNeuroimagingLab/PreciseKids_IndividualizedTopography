#!/bin/bash
# ============================================
#SBATCH --job-name=ARC_FCconnectomes_Highconfidence
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=200gb
#SBATCH --array=1-49
#SBATCH -o FCconnectomes_Highconfidence.output
#SBATCH -e FCconnectomes_Highconfidence.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_FCconnectomes_PKdata_alltasks_highconfidence.sh
