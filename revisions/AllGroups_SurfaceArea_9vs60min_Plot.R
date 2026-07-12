# Network surface area: 9 min vs 60 min all motiongroups: LMA, LMC, HMC

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(readxl)
library(lme4)
library(lmerTest)
library(emmeans)

data_dir    <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
out_dir     <- data_dir
motion_xlsx <- "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"

desired_order <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

group_labels  <- c("LMA" = "Low-Motion Adults (LMA)",
                   "LMC" = "Low-Motion Children (LMC)",
                   "HMC" = "High-Motion Children (HMC)")

family_meta <- read_excel(motion_xlsx) %>%
  mutate(
    Subject   = paste0("sub-", trimws(as.character(sub))),
    family_id = factor(family)
  ) %>%
  select(Subject, family_id)

df <- read_csv(file.path(data_dir, "AllGroups_SurfaceArea_9vs60min_persubject.csv"),
               show_col_types = FALSE) %>%
  left_join(family_meta, by = "Subject") %>%
  mutate(
    Group        = factor(Group, levels = c("LMA","LMC","HMC")),
    NetworkLabel = factor(NetworkLabel, levels = rev(desired_order))
  )


long <- df %>%
  select(Subject, Group, NetworkLabel, Pct_60min, Pct_9min) %>%
  pivot_longer(cols = c(Pct_60min, Pct_9min),
               names_to  = "DataLength",
               values_to = "Pct") %>%
  mutate(
    DataLength = ifelse(DataLength == "Pct_60min", "60 min", "9 min"),
    DataLength = factor(DataLength, levels = c("9 min", "60 min"))
  )

# paired t-test per network × group, FDR within each group
stats <- df %>%
  mutate(NetworkLabel = factor(NetworkLabel, levels = desired_order)) %>%
  group_by(Group, NetworkLabel) %>%
  summarise(
    mean_9  = mean(Pct_9min),
    mean_60 = mean(Pct_60min),
    t_stat  = t.test(Pct_9min, Pct_60min, paired = TRUE)$statistic,
    p_raw   = t.test(Pct_9min, Pct_60min, paired = TRUE)$p.value,
    .groups = "drop"
  ) %>%
  group_by(Group) %>%
  mutate(
    p_fdr = p.adjust(p_raw, method = "BH"),
    Stars = case_when(
      p_fdr < 0.001 ~ "***",
      p_fdr < 0.01  ~ "**",
      p_fdr < 0.05  ~ "*",
      TRUE          ~ ""
    )
  ) %>%
  ungroup() %>%
  mutate(NetworkLabel = factor(NetworkLabel, levels = rev(desired_order)))

print(stats[, c("Group","NetworkLabel","mean_9","mean_60","t_stat","p_raw","p_fdr","Stars")])


# Model: Pct ~ Group + (1|family_id)  run separately for each data length
run_group_lme <- function(data_length_label, df_long) {
  d <- df_long %>%
    filter(DataLength == data_length_label) %>%
    mutate(NetworkLabel = factor(as.character(NetworkLabel), levels = desired_order),
           Group        = factor(Group, levels = c("LMA","LMC","HMC")))

  d %>%
    group_by(NetworkLabel) %>%
    group_modify(function(nd, key) {
      fit <- try(lmer(Pct ~ Group + (1 | family_id), data = nd, REML = TRUE),
                 silent = TRUE)
      if (inherits(fit, "try-error"))
        return(tibble(p_group = NA_real_,
                      p_LMA_LMC = NA_real_, p_LMA_HMC = NA_real_, p_LMC_HMC = NA_real_,
                      b_LMC = NA_real_, b_HMC = NA_real_))

      av  <- as.data.frame(anova(fit))
      emm <- emmeans(fit, ~ Group)
      cm  <- as.data.frame(contrast(emm, "pairwise", adjust = "none")) #none here, BH as FDR below...
      pv  <- setNames(cm$p.value, cm$contrast)
      cf  <- as.data.frame(summary(fit)$coefficients)

      tibble(
        p_group   = av["Group", "Pr(>F)"],
        b_LMC     = cf["GroupLMC", "Estimate"],
        b_HMC     = cf["GroupHMC", "Estimate"],
        p_LMA_LMC = pv["LMA - LMC"],
        p_LMA_HMC = pv["LMA - HMC"],
        p_LMC_HMC = pv["LMC - HMC"]
      )
    }) %>%
    ungroup() %>%
    mutate(
      p_group_FDR   = p.adjust(p_group,   method = "BH"),
      p_LMA_LMC_FDR = p.adjust(p_LMA_LMC, method = "BH"),
      p_LMA_HMC_FDR = p.adjust(p_LMA_HMC, method = "BH"),
      p_LMC_HMC_FDR = p.adjust(p_LMC_HMC, method = "BH"),
      DataLength    = data_length_label
    ) %>%
    arrange(p_group_FDR)
}


long_with_fam <- long %>%
  left_join(df %>% select(Subject, family_id) %>% distinct(), by = "Subject")

grp_9min  <- run_group_lme("9 min",  long_with_fam)
grp_60min <- run_group_lme("60 min", long_with_fam)
grp_stats <- bind_rows(grp_9min, grp_60min)

sink(file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_groupLME.txt"))
cat("=== Group differences (LMA / LMC / HMC) at 9 min ===\n")
cat("Model: Pct ~ Group + (1|family_id), FDR across networks within each data length\n\n")
print(as.data.frame(grp_9min),  row.names = FALSE)
cat("\n=== Group differences at 60 min ===\n\n")
print(as.data.frame(grp_60min), row.names = FALSE)
sink()

write_csv(grp_stats, file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_groupLME.csv"))

#set up for plotting
means <- long %>%
  group_by(Group, NetworkLabel, DataLength) %>%
  summarise(mean_pct = mean(Pct), .groups = "drop")

#SIG labels
star_pos <- long %>%
  group_by(Group, NetworkLabel) %>%
  summarise(x_pos = max(Pct) + 0.5, .groups = "drop") %>%
  left_join(stats %>% select(Group, NetworkLabel, Stars, p_fdr, p_raw),
            by = c("Group","NetworkLabel")) %>%
  filter(p_fdr < 0.05)

#color scheme for now....
custom_colors <- c(
  "LMA_9"  = "#9ECAE1",   # light blue
  "LMA_60" = "#0072B2",   # dark blue
  "LMC_9"  = "#FDBE85",   # light orange
  "LMC_60" = "#E69F00",   # dark orange
  "HMC_9"  = "#F4A6C8",   # light pink
  "HMC_60" = "#8B1A4A"    # dark maroon
)


long <- long %>%
  mutate(ColorKey = paste0(Group, "_", gsub(" min", "", DataLength)))

means <- means %>%
  mutate(ColorKey = paste0(Group, "_", gsub(" min", "", DataLength)))

#PLOT
p <- ggplot(long, aes(x = Pct, y = NetworkLabel, color = ColorKey)) +
  geom_jitter(height = 0.15, size = 1.8, alpha = 0.70) +
  geom_crossbar(
    data      = means,
    aes(x = mean_pct, xmin = mean_pct, xmax = mean_pct,
        y = NetworkLabel, color = ColorKey),
    width     = 0.5,
    linewidth = 1.1
  ) +
  geom_text(
    data        = star_pos,
    aes(x = x_pos, y = NetworkLabel, label = Stars),
    inherit.aes = FALSE,
    size        = 3.5,
    hjust       = 0,
    color       = "black"
  ) +
  scale_color_manual(
    values = custom_colors,
    breaks = c("LMA_9","LMA_60","LMC_9","LMC_60","HMC_9","HMC_60"),
    labels = c("LMA 9 min","LMA 60 min",
               "LMC 9 min","LMC 60 min",
               "HMC 9 min","HMC 60 min"),
    name   = NULL
  ) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0.02, 0.10))) +
  facet_wrap(~ Group, ncol = 3,
             labeller = labeller(Group = group_labels)) +
  labs(
    x = "Surface Area (% of total cortical surface area)",
    y = "Network"
  ) +
  theme_classic(base_size = 10) +
  theme(
    strip.background = element_blank(),
    strip.text       = element_text(size = 11, face = "bold", color = "black"),
    axis.text        = element_text(size = 10, color = "black"),
    axis.title       = element_text(size = 11, color = "black"),
    legend.position  = "bottom",
    legend.text      = element_text(size = 9),
    panel.spacing    = unit(1.2, "lines")
  )

ggsave(file.path(out_dir, "AllGroups_SurfaceArea_9vs60min.pdf"),
       plot = p, width = 14, height = 7, dpi = 300)

write_csv(stats, file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_stats.csv"))
