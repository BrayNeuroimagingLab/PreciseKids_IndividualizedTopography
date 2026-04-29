#!/bin/bash
# ============================================
#SBATCH --job-name=IDVariantsC
#SBATCH --time=2:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16gb
#SBATCH --array=1-25
#SBATCH -o IDVariantsC_processing.output
#SBATCH -e IDVariantsC_processing.error
# ============================================

bash /home/shefali.rai1/scripts_surfacebrains/ARC_IDVariants_Sample1C.sh
