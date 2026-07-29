# Mean vertex-wise entropy at 9, 15, 30, 60 min,assignment confidence diff.

library(ciftiTools)
library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)
library(cowplot)
library(lme4)
library(lmerTest)
library(emmeans)

ciftiTools.setOption("wb_path", "/Applications/workbench/bin_macosx64/wb_command")
data_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
out_dir  <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"

lma_nums <- c(2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26)
lmc_nums <- c(2,5,7,9,15,18,21,23,25,26)
hmc_nums <- c(4,6,8,10,11,12,13,14,16,17,19,20,22,24)

lma_subs <- paste0("1973", sprintf("%03d", lma_nums), "P")
lmc_subs <- paste0("1973", sprintf("%03d", lmc_nums), "C")
hmc_subs <- paste0("1973", sprintf("%03d", hmc_nums), "C")
all_subs <- c(lma_subs, lmc_subs, hmc_subs)

assign_group <- function(subID) {
  if (subID %in% lma_subs) return("LMA")
  if (subID %in% lmc_subs) return("LMC")
  if (subID %in% hmc_subs) return("HMC")
  return(NA_character_)
}

get_entropy_path <- function(subID, duration) {
  file.path(data_dir,
            sprintf("sub-%s_alltasks_HCPAdultChild_overlap_14networkassignment_Vertexwise_%s_entropy.dscalar.nii",
                    subID, duration))
}

load_mean_entropy <- function(filepath) {
  tryCatch({
    xii  <- read_cifti(filepath)
    vals <- c(xii$data$cortex_left, xii$data$cortex_right)
    mean(vals, na.rm = TRUE)
  }, error = function(e) {
    message("  Could not load: ", filepath); return(NA_real_)
  })
}

# mean entropy
results <- list()

for (subID in all_subs) {
  group <- assign_group(subID)
  if (is.na(group)) next
  message("Processing: ", subID, " (", group, ")")

  durations <- c("9min", "15min", "30min", "60min")
  ent_vals  <- setNames(vector("numeric", 4), durations)
  skip      <- FALSE

  for (dur in durations) {
    fp <- get_entropy_path(subID, dur)
    if (!file.exists(fp)) {
      message("  Skipping — file missing: ", fp)
      skip <- TRUE; break
    }
    ent_vals[dur] <- load_mean_entropy(fp)
    message(sprintf("  Entropy %s = %.4f", dur, ent_vals[dur]))
  }
  if (skip) next

  results[[subID]] <- data.frame(
    subID      = subID,
    group      = group,
    entropy_9  = ent_vals[["9min"]],  
    entropy_15 = ent_vals[["15min"]],
    entropy_30 = ent_vals[["30min"]],
    entropy_60 = ent_vals[["60min"]]
  )
}

df <- bind_rows(results)

df_long <- df %>%
  pivot_longer(cols = c(entropy_9, entropy_15, entropy_30, entropy_60),
               names_to  = "duration",
               values_to = "MeanEntropy") %>%
  mutate(
    duration = recode(duration,
                      "entropy_9" = "9 min",
                      "entropy_15" = "15 min",
                      "entropy_30" = "30 min",
                      "entropy_60" = "60 min"),
    duration = factor(duration, levels = c("9 min", "15 min", "30 min", "60 min")),
    group    = factor(group, levels = c("LMA", "LMC", "HMC")),
    familyID = factor(str_extract(subID, "\\d{7}"))
  )

#LMER group x duration
m <- lmer(MeanEntropy ~ group * duration + (1|familyID) + (1|subID),
          data = df_long, REML = TRUE)

# main emmeans objects
emm_duration <- emmeans(m, ~ duration)
emm_group    <- emmeans(m, ~ group)
emm_interact <- emmeans(m, ~ duration | group)   # duration contrasts within group

contrast_duration <- contrast(emm_duration, method = "pairwise", adjust = "fdr")
contrast_group    <- contrast(emm_group,    method = "pairwise", adjust = "fdr")
contrast_interact <- contrast(emm_interact, method = "pairwise", adjust = "fdr")

emm_group_at_dur  <- emmeans(m, ~ group | duration)
contrast_group_at_dur <- contrast(emm_group_at_dur, method = "pairwise", adjust = "fdr")

sink(file.path(out_dir, "lmer_Entropy_results.txt"))
cat("=== Mean Entropy: LMER group × duration (LMA / LMC / HMC) ===\n\n")
print(summary(m))
cat("\n--- ANOVA (Satterthwaite) ---\n");                   print(anova(m))
cat("\n--- Marginal means: duration ---\n");                print(emm_duration)
cat("\n--- Duration pairwise (FDR) ---\n");                 print(contrast_duration)
cat("\n--- Marginal means: group ---\n");                   print(emm_group)
cat("\n--- Group pairwise (FDR) ---\n");                    print(contrast_group)
cat("\n--- Duration contrast within group ---\n");          print(contrast_interact)
cat("\n--- Group contrast at each duration ---\n");         print(contrast_group_at_dur)
sink()


#Plot setup
group_means <- df_long %>%
  group_by(duration, group) %>%
  summarise(mean_entropy = mean(MeanEntropy, na.rm = TRUE), .groups = "drop")

#PLOT
group_colors <- c("LMA" = "#0072B2", "LMC" = "#E69F00", "HMC" = "#CC79A7")
group_shapes <- c("LMA" = 21,        "LMC" = 24,        "HMC" = 22)
group_labels <- c("LMA" = "Low-Motion Adults (LMA)",
                  "LMC" = "Low-Motion Children (LMC)",
                  "HMC" = "High-Motion Children (HMC)")

p <- ggplot() +
  # individual subject lines — thin, semi-transparent
  geom_line(
    data      = df_long,
    aes(x = duration, y = MeanEntropy, group = subID, color = group),
    linewidth = 0.35, alpha = 0.35
  ) +
  # individual points
  geom_point(
    data  = df_long,
    aes(x = duration, y = MeanEntropy, color = group, shape = group),
    size  = 1.2, alpha = 0.45
  ) +
  # group mean lines — thick
  geom_line(
    data      = group_means,
    aes(x = duration, y = mean_entropy, group = group, color = group),
    linewidth = 1.1
  ) +
  # group mean points — large, black outline
  geom_point(
    data   = group_means,
    aes(x = duration, y = mean_entropy, fill = group, shape = group),
    color  = "black", size = 4, stroke = 0.7
  ) +
  scale_color_manual(values = group_colors, labels = group_labels, name = NULL) +
  scale_fill_manual( values = group_colors, labels = group_labels, name = NULL) +
  scale_shape_manual(values = group_shapes, labels = group_labels, name = NULL) +
  labs(
    x = "Data Length",
    y = "Mean Vertex-Wise Entropy\n(Network Assignment Confidence)"
  ) +
  theme_classic(base_size = 9) +
  theme(
    legend.position    = "bottom",
    legend.text        = element_text(size = 8, color = "black"),
    legend.margin      = margin(0, 0, 0, 0),
    axis.text          = element_text(size = 8, color = "black"),
    axis.title         = element_text(size = 9, color = "black"),
    axis.line          = element_line(color = "black"),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.3),
    plot.margin        = margin(8, 8, 5, 8)
  )

ggsave(file.path(out_dir, "Entropy_Trajectory_9_15_30_60min.svg"),
       plot = p, width = 6.5, height = 5.5, units = "in")

