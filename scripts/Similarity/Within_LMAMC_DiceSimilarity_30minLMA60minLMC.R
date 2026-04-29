# ============================================================
# Within-group similarity: Adult–Adult vs LMC–LMC
# ============================================================

# Libraries
library(dplyr)
library(ggplot2)
library(rstatix)
library(tidyr)
library(readxl)
library(readr)
library(ciftiTools)
library(lme4)
library(lmerTest)
library(emmeans)
library(knitr)
library(kableExtra)

# Clear environment
rm(list = ls())

# Set Workbench path
ciftiTools.setOption("wb_path", "/Applications/workbench/bin_macosx64/wb_command")

# ------------------------------------------------------------
# Subject IDs (explicit)
# ------------------------------------------------------------
adult_nums <- c(2:16, 18:21, 23:26)           # 22 adults (exclude 17P, 22P)
parent_ids <- sprintf("sub-19730%02dP", adult_nums)

child_nums <- c(2, 5, 7, 9, 15, 18, 21, 23, 25, 26)  # 10 LMC children
child_ids  <- sprintf("sub-19730%02dC", child_nums)

all_ids <- c(child_ids, parent_ids)

# ------------------------------------------------------------
# Motion groups (Child only: LMC/HMC)
# ------------------------------------------------------------
motion_info <- read_excel("/Users/shefalirai/Desktop/Prckids/prckids-motion_beh.xlsx")
motion_info$sub_id <- paste0("sub-", motion_info$sub)
motion_info$motion_group <- factor(motion_info$motion_group, levels = c("LMC", "HMC"))

# ------------------------------------------------------------
# Networks
# ------------------------------------------------------------
task <- "alltasks"
base_path <- "/Users/shefalirai/Downloads/HCPOverlap_Sample1/"

network_nums <- c(1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16)
network_labels <- c('DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 
                    'CON', 'SMd', 'SMl', 'AUD', 'PON')

# (optional) desired display order
desired_order <- c("DMN", "FP", "DAN", "VAN", "SAL", "CON", "AUD", "SMd", "SMl", "VIS", "PON")


# ------------------------------------------------------------
# Load maps (Adults use only30min, Children use sample1)
# ------------------------------------------------------------
load_dice_map <- function(subj) {
  suffix <- if (grepl("P$", subj)) "only30min_Dice.dscalar.nii" else "sample1_Dice.dscalar.nii"
  f_expect <- file.path(base_path, paste0(subj, "_", task, "_HCPAdultChild_overlap_", suffix))
  f_child  <- file.path(base_path, paste0(subj, "_", task, "_HCPAdultChild_overlap_sample1_Dice.dscalar.nii"))
  f_adult  <- file.path(base_path, paste0(subj, "_", task, "_HCPAdultChild_overlap_only30min_Dice.dscalar.nii"))
  file <- if (file.exists(f_expect)) f_expect else if (file.exists(f_child)) f_child else if (file.exists(f_adult)) f_adult else NA_character_
  
  if (!is.na(file)) {
    d <- read_cifti(file)$data
    c(as.numeric(d$cortex_left), as.numeric(d$cortex_right))
  } else {
    message("Missing Dice file for: ", subj)
    NULL
  }
}

subject_maps <- lapply(all_ids, load_dice_map)
names(subject_maps) <- all_ids
subject_maps <- subject_maps[!sapply(subject_maps, is.null)]


# ------------------------------------------------------------
# Dice computation
# ------------------------------------------------------------
compute_pairwise_dice <- function(subj1, subj2, group_type) {
  if (!(subj1 %in% names(subject_maps)) || !(subj2 %in% names(subject_maps))) return(NULL)
  map1 <- subject_maps[[subj1]]
  map2 <- subject_maps[[subj2]]
  
  res <- lapply(network_nums, function(net) {
    bin1 <- map1 == net
    bin2 <- map2 == net
    dice_val <- if ((sum(bin1) + sum(bin2)) > 0) {
      2 * sum(bin1 & bin2) / (sum(bin1) + sum(bin2))
    } else {
      NA_real_
    }
    data.frame(Subject1 = subj1, Subject2 = subj2, GroupType = group_type, 
               Network = net, Dice = dice_val, stringsAsFactors = FALSE)
  })
  do.call(rbind, res)
}

# ------------------------------------------------------------
# Exclusions (siblings)
# ------------------------------------------------------------
excluded_pairs <- list(
  c("sub-1973005C", "sub-1973006C"), 
  c("sub-1973007C", "sub-1973010C")
)
is_excluded_pair <- function(pair) {
  any(sapply(excluded_pairs, function(ex) all(sort(pair) == sort(ex))))
}

# ------------------------------------------------------------
# Build pair lists
# ------------------------------------------------------------
child_motion <- motion_info %>% 
  filter(sub_id %in% child_ids) %>% 
  select(sub_id, motion_group)

child_pairs <- Filter(function(p) !is_excluded_pair(p),
                      combn(child_ids, 2, simplify = FALSE))

adult_pairs <- combn(parent_ids, 2, simplify = FALSE)

# ------------------------------------------------------------
# Compute results (LMC only + Adults)
# ------------------------------------------------------------
full_results <- data.frame()

# Children: keep only LMC–LMC
for (pair in child_pairs) {
  g1 <- child_motion$motion_group[child_motion$sub_id == pair[1]]
  g2 <- child_motion$motion_group[child_motion$sub_id == pair[2]]
  if (length(g1) == 1 && length(g2) == 1 && g1 == "LMC" && g2 == "LMC") {
    full_results <- bind_rows(full_results, compute_pairwise_dice(pair[1], pair[2], "LMC–LMC"))
  }
}

# Adults: all Adult–Adult
for (pair in adult_pairs) {
  full_results <- bind_rows(full_results, compute_pairwise_dice(pair[1], pair[2], "Adult–Adult"))
}

# Label networks
full_results$NetworkLabel <- factor(network_labels[match(full_results$Network, network_nums)], 
                                    levels = network_labels)

# ------------------------------------------------------------
# Metadata (sex info)
# ------------------------------------------------------------
meta <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv") %>%
  rename(Subject = sub) %>%
  mutate(group = ifelse(group == "C", "Child", "Adult")) %>%
  distinct(Subject, group, sex)

# Add SameSex info
full_results <- full_results %>%
  mutate(
    subj1_clean = sub("^sub-", "", Subject1),
    subj2_clean = sub("^sub-", "", Subject2)
  ) %>%
  left_join(meta %>% select(Subject, sex1 = sex), by = c("subj1_clean" = "Subject")) %>%
  left_join(meta %>% select(Subject, sex2 = sex), by = c("subj2_clean" = "Subject")) %>%
  mutate(SameSex = ifelse(sex1 == sex2, "Same", "Different")) %>%
  select(-subj1_clean, -subj2_clean, -sex1, -sex2)

# Drop NAs in Dice (and in SameSex if any) before stats/plot
full_results <- full_results %>% filter(!is.na(Dice))

# ------------------------------------------------------------
# Sample sizes (pairwise × network rows)
# ------------------------------------------------------------
print("Sample sizes (rows = subject-pairs × networks):")
print(table(full_results$GroupType))

# ------------------------------------------------------------
# Stats (LMM)
# ------------------------------------------------------------
full_results$GroupType <- factor(full_results$GroupType, 
                                 levels = c("Adult–Adult", "LMC–LMC"))
full_results$SameSex <- factor(full_results$SameSex, levels = c("Same", "Different"))

lmer_model <- lmer(Dice ~ GroupType + NetworkLabel + GroupType:NetworkLabel + SameSex +
                     (1 | Subject1) + (1 | Subject2),
                   data = full_results)
summary(lmer_model)

# Posthoc comparisons
emm <- emmeans(lmer_model, ~ GroupType | NetworkLabel)
posthoc <- contrast(emm, method = "pairwise", adjust = "fdr")
posthoc_summary <- summary(posthoc)

# Output table
results_table <- as.data.frame(posthoc_summary)
kable(results_table, format = "markdown", 
      caption = "Post-hoc comparisons of Dice similarity (Adult–Adult vs LMC–LMC), FDR-corrected") %>%
  kable_styling(full_width = FALSE, position = "center")




# ------------------------------------------------------------
# Plot
# ------------------------------------------------------------
pair_colors <- c("Adult–Adult" = "#0072B2", "LMC–LMC" = "#E69F00")

# desired order for plotting
full_results$NetworkLabel <- factor(full_results$NetworkLabel, levels = desired_order)

# positions per network (define BEFORE using)
network_positions <- data.frame(
  NetworkLabel = desired_order,
  NetworkIndex = seq_along(desired_order)
)

# Build contrast annotations (stars + fixed-height brackets at y = 0.88)
contrast_results <- as.data.frame(posthoc) %>%
  mutate(
    NetworkLabel = factor(NetworkLabel, levels = desired_order),
    Stars = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE ~ ""
    )
  ) %>%
  filter(Stars != "") %>%
  mutate(
    y_position = 0.88,                      
    xnum   = as.numeric(NetworkLabel),
    xstart = xnum - 0.20,                     
    xend   = xnum + 0.20,                     
    xtext  = xnum                              
  )




ggplot(full_results, aes(x = NetworkLabel, y = Dice, fill = GroupType)) +
  geom_violin(position = position_dodge(width = 0.9),
              width = 1, alpha = 0.9, color = "black", trim = FALSE) +
  stat_summary(fun = "mean", geom = "crossbar", width = 0.25,
               color = "black", position = position_dodge(width = 0.9)) +
  # --- stars and bracket at fixed height ---
  geom_text(
    data = contrast_results,
    aes(x = NetworkLabel, y = y_position + 0.02, label = Stars),
    inherit.aes = FALSE, size = 8, color = "black"
  ) +
  geom_segment(
    data = contrast_results,
    aes(x = xstart - 0.05, xend = xend + 0.05,
        y = y_position + 0.01, yend = y_position + 0.01),
    inherit.aes = FALSE, linewidth = 0.6, color = "black"
    ) +
  scale_fill_manual(values = pair_colors) +
  scale_y_continuous(limits = c(0, 0.92), expand = expansion(mult = c(0, 0.02))) +
  labs(x = "Network", y = "Topography Similarity (Dice Coefficient)", fill = "Group Comparisons") +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title = element_text(size = 18, color = "black"),
    axis.text = element_text(size = 16, color = "black"),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 16),
    legend.key = element_blank(),
    legend.background = element_blank(),
    legend.box.background = element_blank()
  )

ggsave("/Users/shefalirai/Downloads/HCPOverlap_Sample1/WithinGroup_LMCvsAdult_Dicecomparison_30minLMA60minLMC.svg", 
       width = 10, height = 6.5, dpi = 300)


























# ============================================================
# Within-group similarity (Matched Families Only):
# Adult–Adult (LMA, matched to LMC families) vs LMC–LMC
# ============================================================

# Libraries
library(dplyr)
library(ggplot2)
library(rstatix)
library(tidyr)
library(readxl)
library(readr)
library(ciftiTools)
library(lme4)
library(lmerTest)
library(emmeans)
library(knitr)
library(kableExtra)

# Clear environment
rm(list = ls())

# Set Workbench path
ciftiTools.setOption("wb_path", "/Applications/workbench/bin_macosx64/wb_command")

# ------------------------------------------------------------
# Subject IDs (Matched families)
#   - Children (LMC): fixed list you provided
#   - Adults (LMA): same subject numbers as LMC (matched families)
# ------------------------------------------------------------
child_nums <- c(2, 5, 7, 9, 15, 18, 21, 23, 25, 26)         # 10 LMC children
child_ids  <- sprintf("sub-19730%02dC", child_nums)

adult_nums <- child_nums                                     # match families 1:1
parent_ids <- sprintf("sub-19730%02dP", adult_nums)          # 10 matched LMA adults

all_ids <- c(child_ids, parent_ids)

# ------------------------------------------------------------
# Motion groups (Child only: LMC/HMC)
# ------------------------------------------------------------
motion_info <- read_excel("/Users/shefalirai/Desktop/Prckids/prckids-motion_beh.xlsx")
motion_info$sub_id <- paste0("sub-", motion_info$sub)
motion_info$motion_group <- factor(motion_info$motion_group, levels = c("LMC", "HMC"))

# ------------------------------------------------------------
# Networks
# ------------------------------------------------------------
task <- "alltasks"
base_path <- "/Users/shefalirai/Downloads/HCPOverlap_Sample1/"

network_nums <- c(1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16)
network_labels <- c('DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 
                    'CON', 'SMd', 'SMl', 'AUD', 'PON')

desired_order <- c("DMN", "FP", "DAN", "VAN", "SAL", "CON", "AUD", "SMd", "SMl", "VIS", "PON")

# ------------------------------------------------------------
# Load sample maps
# ------------------------------------------------------------
load_sample1_map <- function(subj) {
  file <- file.path(base_path, paste0(subj, "_", task, "_HCPAdultChild_overlap_sample1_Dice.dscalar.nii"))
  if (file.exists(file)) {
    d <- read_cifti(file)$data
    m <- c(as.numeric(d$cortex_left), as.numeric(d$cortex_right))
    return(m)
  } else {
    return(NULL)
  }
}

subject_maps <- lapply(all_ids, load_sample1_map)
names(subject_maps) <- all_ids
subject_maps <- subject_maps[!sapply(subject_maps, is.null)]

# ------------------------------------------------------------
# Dice computation
# ------------------------------------------------------------
compute_pairwise_dice <- function(subj1, subj2, group_type) {
  if (!(subj1 %in% names(subject_maps)) || !(subj2 %in% names(subject_maps))) return(NULL)
  map1 <- subject_maps[[subj1]]
  map2 <- subject_maps[[subj2]]
  
  res <- lapply(network_nums, function(net) {
    bin1 <- map1 == net
    bin2 <- map2 == net
    dice_val <- if ((sum(bin1) + sum(bin2)) > 0) {
      2 * sum(bin1 & bin2) / (sum(bin1) + sum(bin2))
    } else {
      NA_real_
    }
    data.frame(Subject1 = subj1, Subject2 = subj2, GroupType = group_type, 
               Network = net, Dice = dice_val, stringsAsFactors = FALSE)
  })
  do.call(rbind, res)
}

# ------------------------------------------------------------
# Exclusions (siblings)
# ------------------------------------------------------------
excluded_pairs <- list(
  c("sub-1973005C", "sub-1973006C"), 
  c("sub-1973007C", "sub-1973010C")
)
is_excluded_pair <- function(pair) {
  any(sapply(excluded_pairs, function(ex) all(sort(pair) == sort(ex))))
}

# ------------------------------------------------------------
# Build pair lists
# ------------------------------------------------------------
child_motion <- motion_info %>% 
  filter(sub_id %in% child_ids) %>% 
  select(sub_id, motion_group)

child_pairs <- Filter(function(p) !is_excluded_pair(p),
                      combn(child_ids, 2, simplify = FALSE))

adult_pairs <- combn(parent_ids, 2, simplify = FALSE)

# ------------------------------------------------------------
# Compute results (LMC only + matched Adults)
# ------------------------------------------------------------
full_results <- data.frame()

# Children: keep only LMC–LMC
for (pair in child_pairs) {
  g1 <- child_motion$motion_group[child_motion$sub_id == pair[1]]
  g2 <- child_motion$motion_group[child_motion$sub_id == pair[2]]
  if (length(g1) == 1 && length(g2) == 1 && g1 == "LMC" && g2 == "LMC") {
    full_results <- bind_rows(full_results, compute_pairwise_dice(pair[1], pair[2], "LMC–LMC"))
  }
}

# Adults (matched set): all Adult–Adult among matched parents
for (pair in adult_pairs) {
  full_results <- bind_rows(full_results, compute_pairwise_dice(pair[1], pair[2], "Adult–Adult"))
}

# Label networks
full_results$NetworkLabel <- factor(network_labels[match(full_results$Network, network_nums)], 
                                    levels = network_labels)

# ------------------------------------------------------------
# Metadata (sex info)
# ------------------------------------------------------------
meta <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv") %>%
  rename(Subject = sub) %>%
  mutate(group = ifelse(group == "C", "Child", "Adult")) %>%
  distinct(Subject, group, sex)

# Add SameSex info
full_results <- full_results %>%
  mutate(
    subj1_clean = sub("^sub-", "", Subject1),
    subj2_clean = sub("^sub-", "", Subject2)
  ) %>%
  left_join(meta %>% select(Subject, sex1 = sex), by = c("subj1_clean" = "Subject")) %>%
  left_join(meta %>% select(Subject, sex2 = sex), by = c("subj2_clean" = "Subject")) %>%
  mutate(SameSex = ifelse(sex1 == sex2, "Same", "Different")) %>%
  select(-subj1_clean, -subj2_clean, -sex1, -sex2)

# Drop NAs in Dice (and in SameSex if any) before stats/plot
full_results <- full_results %>% filter(!is.na(Dice))

# ------------------------------------------------------------
# Sanity checks (pairs and rows)
# ------------------------------------------------------------
cat("Matched adult IDs (LMA):\n"); print(parent_ids)
cat("LMC child IDs:\n");         print(child_ids)

cat("Adult pairs (expected choose(10,2)=45): ", choose(length(parent_ids), 2), "\n")
cat("LMC pairs   (expected choose(10,2)=45): ", choose(length(child_ids), 2), "\n")

cat("Rows (pairs × 11 networks):\n")
print(table(full_results$GroupType))

# ------------------------------------------------------------
# Stats (LMM)
# ------------------------------------------------------------
full_results$GroupType <- factor(full_results$GroupType, 
                                 levels = c("Adult–Adult", "LMC–LMC"))
full_results$SameSex <- factor(full_results$SameSex, levels = c("Same", "Different"))

lmer_model <- lmer(Dice ~ GroupType + NetworkLabel + GroupType:NetworkLabel + SameSex +
                     (1 | Subject1) + (1 | Subject2),
                   data = full_results)
summary(lmer_model)

# Posthoc comparisons
emm <- emmeans(lmer_model, ~ GroupType | NetworkLabel)
posthoc <- contrast(emm, method = "pairwise", adjust = "fdr")
posthoc_summary <- summary(posthoc)

# Output table
results_table <- as.data.frame(posthoc_summary)
kable(results_table, format = "markdown", 
      caption = "Post-hoc comparisons of Dice similarity (Adult–Adult vs LMC–LMC), FDR-corrected (Matched Families Only)") %>%
  kable_styling(full_width = FALSE, position = "center")

# ------------------------------------------------------------
# Plot
# ------------------------------------------------------------
pair_colors <- c("Adult–Adult" = "#0072B2", "LMC–LMC" = "#E69F00")

# desired order for plotting
full_results$NetworkLabel <- factor(full_results$NetworkLabel, levels = desired_order)

# positions per network (define BEFORE using)
network_positions <- data.frame(
  NetworkLabel = desired_order,
  NetworkIndex = seq_along(desired_order)
)

# Build contrast annotations (stars + fixed-height brackets at y = 0.88)
contrast_results <- as.data.frame(posthoc) %>%
  mutate(
    NetworkLabel = factor(NetworkLabel, levels = desired_order),
    Stars = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE ~ ""
    )
  ) %>%
  filter(Stars != "") %>%
  mutate(
    y_position = 0.88,                          
    xnum   = as.numeric(NetworkLabel),
    xstart = xnum - 0.20,                       
    xend   = xnum + 0.20,                 
    xtext  = xnum                              
  )


##PLOT##

ggplot(full_results, aes(x = NetworkLabel, y = Dice, fill = GroupType)) +
  geom_violin(position = position_dodge(width = 0.9),
              width = 1, alpha = 0.9, color = "black", trim = FALSE) +
  stat_summary(fun = "mean", geom = "crossbar", width = 0.25,
               color = "black", position = position_dodge(width = 0.9)) +
  geom_text(
    data = contrast_results,
    aes(x = NetworkLabel, y = y_position + 0.02, label = Stars),
    inherit.aes = FALSE, size = 8, color = "black"
  ) +
  geom_segment(
    data = contrast_results,
    aes(x = xstart - 0.05, xend = xend + 0.05,
        y = y_position + 0.01, yend = y_position + 0.01),
    inherit.aes = FALSE, linewidth = 0.6, color = "black"
  ) +
  scale_fill_manual(values = pair_colors) +
    scale_y_continuous(limits = c(0, 1), expand = expansion(mult = c(0, 0.02))) +
    labs(x = "Network", y = "Topography Similarity (Dice Coefficient)", fill = "Group Comparisons") +
    theme_classic() +
    theme(
      axis.title = element_text(size = 18),
      axis.text = element_text(size = 16),
      legend.position = "bottom",
      legend.title = element_blank(),
      legend.text = element_text(size = 16)
    )+
  scale_fill_manual(values = pair_colors) +
  labs(x = "Network", y = "Topography Similarity (Dice Coefficient)", fill = "Group Comparisons") +
  theme_classic() +
  theme(
    axis.title = element_text(size = 18),
    axis.text = element_text(size = 16),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.text = element_text(size = 16)
  )

ggsave("/Users/shefalirai/Downloads/HCPOverlap_Sample1/WithinGroup_LMCvsAdult_Dicecomparison_matchedFamilies.svg", 
       width = 10, height = 6.5, dpi = 300)

