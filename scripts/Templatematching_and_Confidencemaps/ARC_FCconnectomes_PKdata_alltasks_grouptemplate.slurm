#!/bin/bash
# ============================================
#SBATCH --job-name=ARC_FCconnectomes_grouptemplate
#SBATCH --time=12:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=200gb
#SBATCH --array=1-48
#SBATCH -o FCconnectomes_grouptemplate.output
#SBATCH -e FCconnectomes_grouptemplate.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_FCconnectomes_PKdata_alltasks_grouptemplate.sh
