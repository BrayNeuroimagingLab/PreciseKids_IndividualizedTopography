MatchedCensoring_NetworkMaps_Allsubs.m censors across all tasks and sessions, then randomly (as in sliding window approach) takes sections of 'good' and censored data equally across sessions in each sample 1 and sample 2. These samples are independent from each other, however since it is still within session sampling, it is not true test-retest, but more split-half iterative sampling. 

createMaxDice_WinnerTakeAll.m function creates a visual group average map that is needed to show the children and adult maps using 'median'.

HCP_overlapbetweentemplates.m to show the overlap between Dworetsky HCP and HCP 8 to 9 year old maps and then HCP_overlaptemplate_creation.m to create the overlap map.

NetworkPropDiff_Sample1.m is for each vertex proportion of children and adults assigned to network, visualized as the absolute difference in dscalar maps. Coming from EachVertex_ProportionAssignment.py which takes child minus adult proportion and outputs differences.txt

HCPOverlap_AllDiceValues_ExtractNetworkValues.m extracts all dice values ranges for that network for each person (recommend for VertexwiseR TFCE since range of dice values for each person).

ExtractBinaryNetworks_HCPoverlapnetworks.m is to extract each column/network values as a mask and save separately as a dscalar (NOT recommended for VertexwiseRTFCE since this is binary)

SurfaceArea_Gradiation.m to get the surface area and HCP overalp network assignment for each participant to create gradiation or density maps across all people (not averages)
