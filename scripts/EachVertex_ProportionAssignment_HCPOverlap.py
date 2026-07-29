#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Analyze vertex network assignments for children and adults and output text file of differences for each network
with NaN handling for if substraction is with a NaN

Use NetworkPropDiff_Sample1.m after to viz

@author: shefalirai
"""


import os
import numpy as np
from collections import defaultdict
from scipy.stats import mannwhitneyu

def analyze_network_differences(base_dir='/Users/shefalirai/Desktop/PK_networkassignment/HCPOverlap_MaxDice_Entropy/'):
    child_network_vertices = defaultdict(lambda: defaultdict(int))
    adult_network_vertices = defaultdict(lambda: defaultdict(int))
    total_children = 0
    total_adults = 0
    all_vertices = set()
    
    for subject_num in range(2, 27):
        if subject_num == 3:
            continue
            
        subject_str = f"1973{subject_num:03d}"
        
        # Process child file
        child_file = f"sub-{subject_str}C_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_Dice_networkvertices_extractions.txt"
        if os.path.exists(os.path.join(base_dir, child_file)):
            with open(os.path.join(base_dir, child_file), 'r') as f:
                vertices = [int(line.strip()) for line in f if line.strip()]
                total_children += 1
                for vertex_idx, network in enumerate(vertices, 1):
                    if network != 4 and network != 6:
                        child_network_vertices[network][vertex_idx] += 1
                        all_vertices.add(vertex_idx)
        
        # Process adult file
        adult_file = f"sub-{subject_str}P_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_sample1_matchedconditions_Dice_networkvertices_extractions.txt"
        if os.path.exists(os.path.join(base_dir, adult_file)):
            with open(os.path.join(base_dir, adult_file), 'r') as f:
                vertices = [int(line.strip()) for line in f if line.strip()]
                total_adults += 1
                for vertex_idx, network in enumerate(vertices, 1):
                    if network != 4 and network != 6:
                        adult_network_vertices[network][vertex_idx] += 1
                        all_vertices.add(vertex_idx)

    networks = sorted(set(child_network_vertices.keys()) | set(adult_network_vertices.keys()))
    
    # vertex-wise differences
    def calculate_difference(child_count, adult_count, total_children, total_adults):
        """
        Calculate the difference between child and adult proportions with improved NaN handling.
        """
        child_prop = child_count / total_children if total_children > 0 else np.nan
        adult_prop = adult_count / total_adults if total_adults > 0 else np.nan
        
        if np.isnan(child_prop) and np.isnan(adult_prop):
            return np.nan, np.nan, np.nan
        if np.isnan(child_prop):
            return np.nan, adult_prop, -adult_prop
        if np.isnan(adult_prop):
            return child_prop, np.nan, child_prop
        return child_prop, adult_prop, child_prop - adult_prop


    # output vertex-wise differences 
    for network in networks:
        with open(f'network_{network}_differences.txt', 'w') as f:
            f.write("Vertex\tChild_Prop\tAdult_Prop\tDifference\n")
            
            for vertex in sorted(all_vertices):
                child_count = child_network_vertices[network][vertex]
                adult_count = adult_network_vertices[network][vertex]
                
                child_prop, adult_prop, difference = calculate_difference(
                    child_count, adult_count, total_children, total_adults
                )
                
                child_prop_str = f"{child_prop:.4f}" if not np.isnan(child_prop) else "NaN"
                adult_prop_str = f"{adult_prop:.4f}" if not np.isnan(adult_prop) else "NaN"
                diff_str = f"{difference:.4f}" if not np.isnan(difference) else "NaN"
                
                f.write(f"{vertex}\t{child_prop_str}\t{adult_prop_str}\t{diff_str}\n")
                
                
    # ######## Mean absolute difference in networks#########

    # network_diffs = {}

    # for network in networks:
    #     diffs = []
    #     with open(f'network_{network}_differences.txt', 'r') as f:
    #         next(f)  # skip header
    #         for line in f:
    #             _, _, _, diff_str = line.strip().split('\t')
    #             if diff_str != "NaN":
    #                 diffs.append(abs(float(diff_str)))
    #     network_diffs[network] = np.mean(diffs)
    
    # association_networks = [1, 3, 5, 7]  
    # sensory_networks = [2, 12, 10, 11]         


    # assoc_diffs = [network_diffs[n] for n in association_networks]
    # sensory_diffs = [network_diffs[n] for n in sensory_networks]

    # stat, p_value = mannwhitneyu(assoc_diffs, sensory_diffs, alternative='two-sided')
    # print(f"Mann–Whitney U: U={stat}, p={p_value:.4f}")


    
if __name__ == "__main__":
    analyze_network_differences()
    
    
    




