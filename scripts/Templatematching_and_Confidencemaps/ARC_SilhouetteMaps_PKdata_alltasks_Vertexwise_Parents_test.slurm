#!/bin/bash
#SBATCH --job-name=ConfidenceMaps_PKdata_Vertexwise_alltasks_Test
#SBATCH --time=24:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8               
#SBATCH --mem=500gb                     
#SBATCH --array=1
#SBATCH -o ConfidenceMaps_PKdata_Vertexwise_alltasks_Test.output
#SBATCH -e ConfidenceMaps_PKdata_Vertexwise_alltasks_Test.error
#SBATCH --mail-type=ALL
#SBATCH --mail-user=shefali.rai1@ucalgary.ca

# Run your script
bash /home/shefali.rai1/scripts_surfacebrains/ARC_ConfidenceMaps_PKdata_alltasks_Vertexwise_Parents_test.sh
