# Surface-area figures using area-weighted values (9-min and 60-min on the same scale).
#   Figure 1: LMA / LMC / HMC, 9 vs 60 min, paired-t stars (FDR within group)
#   Figure 2: Child vs Adult at 9 min (Figure 6 style)

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)

res_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
sa <- read_csv(file.path(res_dir, "TrueSurfaceArea_9vs60min_persubject.csv"), show_col_types = FALSE)

desired_order <- c("DMN", "FP", "DAN", "VAN", "SAL", "CON", "AUD", "SMd", "SMl", "VIS", "PON")

# motion-group labels (subsets of the 48 subjects)
lma <- paste0("sub-1973", sprintf("%03d", c(2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 24, 25, 26)), "P")
lmc <- paste0("sub-1973", sprintf("%03d", c(2, 5, 7, 9, 15, 18, 21, 23, 25, 26)), "C")
hmc <- paste0("sub-1973", sprintf("%03d", c(4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 20, 22, 24)), "C")

mg <- sa %>%
  mutate(MG = case_when(Subject %in% lma ~ "LMA",
                        Subject %in% lmc ~ "LMC",
                        Subject %in% hmc ~ "HMC",
                        TRUE ~ NA_character_)) %>%
  filter(!is.na(MG)) %>%
  mutate(MG = factor(MG, levels = c("LMA", "LMC", "HMC")))

group_labels <- c("LMA" = "Low-Motion Adults (LMA)",
                  "LMC" = "Low-Motion Children (LMC)",
                  "HMC" = "High-Motion Children (HMC)")

# Figure 1: LMA/LMC/HMC, 9 vs 60 min
long <- mg %>%
  pivot_longer(c(Pct_9min, Pct_60min), names_to = "DataLength", values_to = "Pct") %>%
  mutate(DataLength = ifelse(DataLength == "Pct_60min", "60 min", "9 min"),
         DataLength = factor(DataLength, levels = c("9 min", "60 min")),
         NetworkLabel = factor(NetworkLabel, levels = rev(desired_order)))

# paired t-test per network x group, FDR within group
stats1 <- mg %>%
  group_by(MG, NetworkLabel) %>%
  summarise(p_raw = t.test(Pct_9min, Pct_60min, paired = TRUE)$p.value, .groups = "drop") %>%
  group_by(MG) %>%
  mutate(p_fdr = p.adjust(p_raw, method = "BH"),
         Stars = cut(p_fdr, c(-Inf, .001, .01, .05, Inf), c("***", "**", "*", ""))) %>%
  ungroup()

means1 <- long %>%
  group_by(MG, NetworkLabel, DataLength) %>%
  summarise(mean_pct = mean(Pct), .groups = "drop") %>%
  mutate(ColorKey = paste0(MG, "_", gsub(" min", "", DataLength)))
long <- long %>% mutate(ColorKey = paste0(MG, "_", gsub(" min", "", DataLength)))

star_pos <- long %>%
  group_by(MG, NetworkLabel) %>%
  summarise(x_pos = max(Pct) + 0.5, .groups = "drop") %>%
  left_join(stats1 %>% mutate(NetworkLabel = factor(NetworkLabel, levels = rev(desired_order))),
            by = c("MG", "NetworkLabel")) %>%
  filter(p_fdr < 0.05)

custom_colors <- c("LMA_9" = "#9ECAE1", "LMA_60" = "#0072B2", "LMC_9" = "#FDBE85",
                   "LMC_60" = "#E69F00", "HMC_9" = "#F4A6C8", "HMC_60" = "#8B1A4A")

p1 <- ggplot(long, aes(x = Pct, y = NetworkLabel, color = ColorKey)) +
  geom_jitter(height = 0.15, size = 1.8, alpha = 0.70) +
  geom_crossbar(data = means1, aes(x = mean_pct, xmin = mean_pct, xmax = mean_pct,
                                   y = NetworkLabel, color = ColorKey), width = 0.5, linewidth = 1.1) +
  geom_text(data = star_pos, aes(x = x_pos, y = NetworkLabel, label = Stars),
            inherit.aes = FALSE, size = 3.5, hjust = 0, color = "black") +
  scale_color_manual(values = custom_colors,
    breaks = c("LMA_9", "LMA_60", "LMC_9", "LMC_60", "HMC_9", "HMC_60"),
    labels = c("LMA 9 min", "LMA 60 min", "LMC 9 min", "LMC 60 min", "HMC 9 min", "HMC 60 min"),
    name = NULL) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0.02, 0.10))) +
  facet_wrap(~ MG, ncol = 3, labeller = labeller(MG = group_labels)) +
  labs(x = "Surface Area (% of total cortical surface area)", y = "Network") +
  theme_classic(base_size = 10) +
  theme(strip.background = element_blank(),
        strip.text = element_text(size = 11, face = "bold", color = "black"),
        axis.text = element_text(size = 10, color = "black"),
        axis.title = element_text(size = 11, color = "black"),
        legend.position = "bottom", legend.text = element_text(size = 9),
        panel.spacing = unit(1.2, "lines"))

ggsave(file.path(res_dir, "AllGroups_SurfaceArea_9vs60min_TRUEarea.pdf"), p1, width = 14, height = 7, dpi = 300)
write_csv(stats1, file.path(res_dir, "AllGroups_SurfaceArea_9vs60min_TRUEarea_pairedt.csv"))

# Figure 2: Child vs Adult at 9 min (Figure 6 style)
sensory <- c("PON", "VIS", "SMl", "SMd", "AUD")
assoc <- c("CON", "SAL", "VAN", "DAN", "FP", "DMN")
fig6_order <- c(sensory, assoc)

d2 <- sa %>%
  mutate(Group = factor(Group, levels = c("Child", "Adult")),
         NetworkLabel = factor(NetworkLabel, levels = fig6_order))
means2 <- d2 %>%
  group_by(Group, NetworkLabel) %>%
  summarise(m = mean(Pct_9min), .groups = "drop")

p2 <- ggplot() +
  geom_point(data = d2, aes(x = Pct_9min, y = NetworkLabel, color = Group),
             alpha = 0.6, size = 2.5, position = position_jitter(height = 0.2)) +
  geom_segment(data = means2, aes(x = m, xend = m,
               y = as.numeric(NetworkLabel) - 0.4, yend = as.numeric(NetworkLabel) + 0.4, color = Group),
               linewidth = 2, alpha = 0.9) +
  scale_color_manual(values = c("Child" = "#E68300", "Adult" = "#0072B2"),
                     labels = c("Child" = "Children", "Adult" = "Adults")) +
  scale_y_discrete(limits = fig6_order) +
  scale_x_continuous(limits = c(0, 25)) +
  labs(x = "Surface Area (%)", y = "Network") +
  theme_classic(base_size = 18) +
  theme(axis.line = element_line(color = "black", linewidth = 0.8),
        panel.grid = element_blank(),
        axis.title = element_text(size = 18, color = "black"),
        axis.text = element_text(size = 16, color = "black"),
        legend.position = "bottom", legend.title = element_blank(),
        legend.text = element_text(size = 16))

ggsave(file.path(res_dir, "Figure6_SurfaceArea_ChildAdult_9min_TRUEarea.pdf"), p2, width = 10, height = 6.5, dpi = 300)
