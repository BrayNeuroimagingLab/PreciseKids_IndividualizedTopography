# Split-half NMI computed at each data length per subject 9 to 30 mins

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
data_dir  <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata"
out_dir   <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"

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

get_filepath <- function(subID, duration, sample) {
  file.path(data_dir,
            sprintf("sub-%s_alltasks_HCPAdultChild_overlap_%s_sample%d_Dice.dscalar.nii",
                    subID, duration, sample))
}

load_labels <- function(filepath) {
  tryCatch({
    xii <- read_cifti(filepath)
    as.integer(round(c(xii$data$cortex_left, xii$data$cortex_right)))
  }, error = function(e) {
    message("  Could not load: ", filepath); return(NULL)
  })
}

compute_nmi <- function(a, b) {
  valid <- !is.na(a) & !is.na(b)
  a <- a[valid]; b <- b[valid]
  n <- length(a)
  if (n == 0) return(NA_real_)
  ha <- table(a)/n; hb <- table(b)/n
  H_a <- -sum(ha * log2(ha + .Machine$double.eps))
  H_b <- -sum(hb * log2(hb + .Machine$double.eps))
  if (H_a + H_b == 0) return(NA_real_)
  joint   <- table(a, b)/n
  H_joint <- -sum(joint * log2(joint + .Machine$double.eps))
  2 * (H_a + H_b - H_joint) / (H_a + H_b)
}

# compute split-half NMI at 9, 15, 30 min per subject
results <- list()

for (subID in all_subs) {
  group <- assign_group(subID)
  if (is.na(group)) next
  message("Processing: ", subID, " (", group, ")")

  durations <- list(
    "9min"  = list(s1 = get_filepath(subID, "9min",  1), s2 = get_filepath(subID, "9min",  2)),
    "15min" = list(s1 = get_filepath(subID, "15min", 1), s2 = get_filepath(subID, "15min", 2)),
    "30min" = list(s1 = get_filepath(subID, "30min", 1), s2 = get_filepath(subID, "30min", 2))
  )

  nmi_vals <- list()
  skip <- FALSE
  for (dur in names(durations)) {
    f1 <- durations[[dur]]$s1; f2 <- durations[[dur]]$s2
    if (!file.exists(f1) || !file.exists(f2)) {
      message("  Skipping ", dur, " — file missing"); skip <- TRUE; break
    }
    m1 <- load_labels(f1); m2 <- load_labels(f2)
    if (is.null(m1) || is.null(m2)) { skip <- TRUE; break }
    nmi_vals[[dur]] <- compute_nmi(m1, m2)
    message(sprintf("  NMI %s = %.3f", dur, nmi_vals[[dur]]))
  }
  if (skip) next

  results[[subID]] <- data.frame(
    subID  = subID,
    group  = group,
    nmi_9  = nmi_vals[["9min"]],
    nmi_15 = nmi_vals[["15min"]],
    nmi_30 = nmi_vals[["30min"]]
  )
}

df <- bind_rows(results)

df_long <- df %>%
  pivot_longer(cols = c(nmi_9, nmi_15, nmi_30),
               names_to  = "duration",
               values_to = "NMI") %>%
  mutate(
    duration_label = recode(duration, "nmi_9" = "9 min", "nmi_15" = "15 min", "nmi_30" = "30 min"),
    duration = recode(duration, "nmi_9" = 9, "nmi_15" = 15, "nmi_30" = 30),  # numeric now
    duration = as.numeric(duration),
    group    = factor(group, levels = c("LMA", "LMC", "HMC")),
    familyID = factor(str_extract(subID, "\\d{7}"))
  )

# LMER: duration × group
m <- lmer(NMI ~ duration * group + (1|familyID) + (1|subID),
          data = df_long, REML = TRUE)

emm_duration <- emmeans(m, ~ duration)
emm_group    <- emmeans(m, ~ group)
emm_interact <- emmeans(m, ~ duration | group)

contrast_duration <- contrast(emm_duration, method = "pairwise", adjust = "fdr")
contrast_group    <- contrast(emm_group,    method = "pairwise", adjust = "fdr")
contrast_interact <- contrast(emm_interact, method = "pairwise", adjust = "fdr")

sink(file.path(out_dir, "lmer_NMI_splitHalf_results.txt"))
cat("=== Split-Half NMI: LMER duration × group (LMA / LMC / HMC) ===\n\n")
print(summary(m))
cat("\n--- ANOVA (Satterthwaite) ---\n");           print(anova(m))
cat("\n--- Marginal means: duration ---\n");         print(emm_duration)
cat("\n--- Duration pairwise (FDR) ---\n");          print(contrast_duration)
cat("\n--- Marginal means: group ---\n");             print(emm_group)
cat("\n--- Group pairwise (FDR) ---\n");              print(contrast_group)
cat("\n--- Duration contrast within group ---\n");    print(contrast_interact)
sink()

# group means per duration
group_means <- df_long %>%
  group_by(duration, group) %>%
  summarise(mean_NMI = mean(NMI, na.rm = TRUE), .groups = "drop")

group_colors <- c("LMA" = "#0072B2", "LMC" = "#E69F00", "HMC" = "#CC79A7")
group_shapes <- c("LMA" = 21, "LMC" = 24, "HMC" = 22)
group_labels <- c("LMA" = "Low-Motion Adults (LMA)",
                  "LMC" = "Low-Motion Children (LMC)",
                  "HMC" = "High-Motion Children (HMC)")

# trajectory plot
p <- ggplot() +
  # individual subject lines — thin, semi-transparent
  geom_line(
    data    = df_long,
    aes(x = duration, y = NMI, group = subID, color = group),
    linewidth = 0.35, alpha = 0.35
  ) +
  # individual points
  geom_point(
    data    = df_long,
    aes(x = duration, y = NMI, color = group, shape = group),
    size    = 1.2, alpha = 0.45
  ) +
  # group mean lines — thick
  geom_line(
    data      = group_means,
    aes(x = duration, y = mean_NMI, group = group, color = group),
    linewidth = 1.1
  ) +
  # group mean points — large, black outline
  geom_point(
    data   = group_means,
    aes(x = duration, y = mean_NMI, fill = group, shape = group),
    color  = "black", size = 4, stroke = 0.7
  ) +
  scale_color_manual(values = group_colors, labels = group_labels, name = NULL) +
  scale_fill_manual( values = group_colors, labels = group_labels, name = NULL) +
  scale_shape_manual(values = group_shapes, labels = group_labels, name = NULL) +
  scale_x_continuous(
    breaks = c(9, 12, 15, 18, 21, 24, 27, 30),
    labels = function(x) ifelse(x %in% c(9, 15, 30),
                                paste0(x, " min\n(split-half)"),
                                as.character(x)),
    limits = c(8, 31) 
  ) +
  labs(
    x = "Data Length",
    y = "Split-Half NMI\n(Topography Reliability)"
  ) +
  theme_classic(base_size = 9) +
  theme(
    legend.position   = "bottom",
    legend.text       = element_text(size = 7.5, color = "black"),
    legend.key.size = unit(0.9, "lines"),
    legend.margin     = margin(0, 0, 0, 0),
    axis.text         = element_text(size = 8, color = "black"),
    axis.title        = element_text(size = 9, color = "black"),
    axis.line         = element_line(color = "black"),
    panel.grid.major.y = element_line(color = "grey92", linewidth = 0.3),
    plot.margin       = margin(8, 8, 5, 8)
  )


ggsave(file.path(out_dir, "NMI_Trajectory_9_15_30min.svg"),
       plot = p, width = 6.5, height = 5.5, units = "in")

