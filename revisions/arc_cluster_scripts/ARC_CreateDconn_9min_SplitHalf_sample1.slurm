#!/bin/bash
#SBATCH --job-name=Dconn_9min_s1
#SBATCH --time=6:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=200gb
#SBATCH --array=1-49
#SBATCH -o Dconn_9min_sample1.output
#SBATCH -e Dconn_9min_sample1.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca
#SBATCH --export=DURATION=9min,SAMPLE=1

bash /home/shefali.rai1/scripts_surfacebrains/ARC_CreateDconn_splitHalf.sh
