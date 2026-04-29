#!/bin/bash
# ============================================
#SBATCH --job-name=schaefer_lme
#SBATCH --time=2:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=150gb
#SBATCH -o schaefer_lme.output
#SBATCH -e schaefer_lme.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
# ============================================

module purge
module load matlab

matlab -nodisplay -r "run('/home/shefali.rai1/scripts_surfacebrains/ARC_FC_Schaefer_LME.m');"
