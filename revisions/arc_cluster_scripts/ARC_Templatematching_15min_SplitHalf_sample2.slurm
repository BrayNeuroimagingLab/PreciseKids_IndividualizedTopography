#!/bin/bash
#SBATCH --job-name=Tmatch_15min_s2
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=200gb
#SBATCH --array=1-49
#SBATCH -o Templatematching_15min_sample2.output
#SBATCH -e Templatematching_15min_sample2.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
#SBATCH --export=DURATION=15min,SAMPLE=2

bash /home/shefali.rai1/scripts_surfacebrains/ARC_Templatematching_splitHalf.sh
