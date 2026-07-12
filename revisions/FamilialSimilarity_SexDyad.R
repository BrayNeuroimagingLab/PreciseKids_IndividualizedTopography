# FamilialSimilarity_SexDyad.R
# Recoding SameSex (binary) to SexDyad (MM / FF / MF)
# Based on RelatedvsUnrelated_Similarity.R
# Related (child-parent) vs Unrelated child-adult pairs, per network Dice similarity

library(ciftiTools)
library(dplyr)
library(ggplot2)
library(lme4)
library(lmerTest)
library(readr)
library(purrr)
library(broom.mixed)
library(emmeans)
library(car)

ciftiTools.setOption("wb_path", "/Applications/workbench/bin_macosx64/wb_command")

base_path <- "/Users/shefalirai/Downloads/HCPOverlap_Sample1/"
meta_path <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv"
out_dir   <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"

task           <- "alltasks"
network_nums   <- c(1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16)
network_labels <- c("DMN","VIS","FP","DAN","VAN","SAL","CON","SMd","SMl","AUD","PON")
desired_order  <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

subject_nums <- c(2:26)[c(1:1, 3:25)]
child_ids  <- sprintf("sub-19730%02dC", subject_nums)
parent_ids <- sprintf("sub-19730%02dP", subject_nums)
all_ids    <- c(child_ids, parent_ids)

meta <- read_csv(meta_path, show_col_types = FALSE) %>%
  rename(Subject = sub) %>%
  mutate(group = ifelse(group == "C", "Child", "Adult")) %>%
  distinct(Subject, sex)

load_map <- function(subj) {
  f <- file.path(base_path, paste0(subj, "_", task, "_HCPAdultChild_overlap_sample1_Dice.dscalar.nii"))
  if (!file.exists(f)) return(NULL)
  d <- read_cifti(f)$data
  c(as.numeric(d$cortex_left), as.numeric(d$cortex_right))
}

subject_maps <- list()
for (subj in all_ids) {
  m <- load_map(subj)
  if (!is.null(m)) subject_maps[[subj]] <- m
}

# Related pairs (child-parent, including siblings sharing parents)
related_pairs <- list(
  c("sub-1973002C", "sub-1973002P"),
  c("sub-1973004C", "sub-1973004P"),
  c("sub-1973005C", "sub-1973005P"),
  c("sub-1973005C", "sub-1973006P"),
  c("sub-1973006C", "sub-1973005P"),
  c("sub-1973006C", "sub-1973006P"),
  c("sub-1973007C", "sub-1973007P"),
  c("sub-1973007C", "sub-1973010P"),
  c("sub-1973010C", "sub-1973007P"),
  c("sub-1973010C", "sub-1973010P"),
  c("sub-1973008C", "sub-1973008P"),
  c("sub-1973009C", "sub-1973009P"),
  c("sub-1973011C", "sub-1973011P"),
  c("sub-1973012C", "sub-1973012P"),
  c("sub-1973013C", "sub-1973013P"),
  c("sub-1973014C", "sub-1973014P"),
  c("sub-1973015C", "sub-1973015P"),
  c("sub-1973016C", "sub-1973016P"),
  c("sub-1973017C", "sub-1973017P"),
  c("sub-1973018C", "sub-1973018P"),
  c("sub-1973019C", "sub-1973019P"),
  c("sub-1973020C", "sub-1973020P"),
  c("sub-1973021C", "sub-1973021P"),
  c("sub-1973022C", "sub-1973022P"),
  c("sub-1973023C", "sub-1973023P"),
  c("sub-1973024C", "sub-1973024P"),
  c("sub-1973025C", "sub-1973025P"),
  c("sub-1973026C", "sub-1973026P")
)

is_related_pair <- function(a, b) {
  any(sapply(related_pairs, function(pair) all(c(a, b) %in% pair)))
}

# Compute Dice for all child-parent combinations
dice_data <- data.frame()
for (child in child_ids) {
  if (!(child %in% names(subject_maps))) next
  map_c <- subject_maps[[child]]
  for (adult in parent_ids) {
    if (!(adult %in% names(subject_maps))) next
    map_p <- subject_maps[[adult]]
    for (net in network_nums) {
      bin_c <- map_c == net
      bin_p <- map_p == net
      dice_val <- if ((sum(bin_c) + sum(bin_p)) > 0) {
        2 * sum(bin_c & bin_p) / (sum(bin_c) + sum(bin_p))
      } else NA
      dice_data <- rbind(dice_data, data.frame(
        subj1           = child,
        subj2           = adult,
        Network         = net,
        Dice            = dice_val,
        GroupComparison = ifelse(is_related_pair(child, adult), "Related", "Unrelated")
      ))
    }
  }
}

dice_data$NetworkLabel <- factor(
  network_labels[match(dice_data$Network, network_nums)],
  levels = desired_order
)
dice_data$GroupComparison <- factor(dice_data$GroupComparison,
                                    levels = c("Related", "Unrelated"))

# Add sex dyad (MM / FF / MF), MF as reference
dice_data <- dice_data %>%
  mutate(
    subj1_clean = sub("^sub-", "", subj1),
    subj2_clean = sub("^sub-", "", subj2)
  ) %>%
  left_join(meta %>% rename(sex1 = sex), by = c("subj1_clean" = "Subject")) %>%
  left_join(meta %>% rename(sex2 = sex), by = c("subj2_clean" = "Subject")) %>%
  mutate(
    SexDyad = case_when(
      sex1 == "M" & sex2 == "M" ~ "MM",
      sex1 == "F" & sex2 == "F" ~ "FF",
      TRUE                       ~ "MF"
    ),
    SexDyad = factor(SexDyad, levels = c("MF", "FF", "MM"))  # MF as reference
  ) %>%
  select(-subj1_clean, -subj2_clean, -sex1, -sex2)

dat <- dice_data %>% filter(!is.na(Dice))

# Overall model with SexDyad
model_dyad <- lmer(Dice ~ GroupComparison * NetworkLabel + SexDyad +
                     (1 | subj1) + (1 | subj2), data = dat)

cat("\n=== Overall model summary ===\n")
print(summary(model_dyad))

cat("\n=== ANOVA (Type III) ===\n")
print(car::Anova(model_dyad, type = 3))

# GroupComparison post-hoc per network
emm_group <- emmeans(model_dyad, ~ GroupComparison | NetworkLabel)
ph_group  <- contrast(emm_group, method = "pairwise", adjust = "fdr") %>%
  as.data.frame() %>%
  mutate(
    NetworkLabel = factor(as.character(NetworkLabel), levels = desired_order),
    sig = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE            ~ "ns"
    )
  ) %>%
  arrange(NetworkLabel)

cat("\n=== GroupComparison post-hoc per network (FDR) ===\n")
print(ph_group, row.names = FALSE)

# SexDyad post-hoc per network
emm_sex <- emmeans(model_dyad, ~ SexDyad | NetworkLabel)
ph_sex  <- contrast(emm_sex, method = "pairwise", adjust = "fdr") %>%
  as.data.frame() %>%
  mutate(
    NetworkLabel = factor(as.character(NetworkLabel), levels = desired_order),
    sig = case_when(
      p.value < 0.001 ~ "***",
      p.value < 0.01  ~ "**",
      p.value < 0.05  ~ "*",
      TRUE            ~ "ns"
    )
  ) %>%
  arrange(NetworkLabel, contrast)

cat("\n=== SexDyad post-hoc per network (FDR) ===\n")
print(ph_sex, row.names = FALSE)

# Per-network GroupComparison model (with SexDyad)
per_net_models <- dat %>%
  group_split(NetworkLabel) %>%
  set_names(levels(dat$NetworkLabel)) %>%
  map(~ lmer(Dice ~ GroupComparison * SexDyad + (1 | subj1) + (1 | subj2), data = .x))

per_net_stats <- map_dfr(per_net_models, tidy, .id = "NetworkLabel")

related_effects <- per_net_stats %>%
  filter(term == "GroupComparisonUnrelated") %>%
  mutate(
    p_adj = p.adjust(p.value, method = "BH"),
    sig = case_when(
      p_adj < 0.001 ~ "***",
      p_adj < 0.01  ~ "**",
      p_adj < 0.05  ~ "*",
      TRUE          ~ "ns"
    ),
    NetworkLabel = factor(NetworkLabel, levels = desired_order)
  ) %>%
  arrange(NetworkLabel)

cat("\n=== Per-network GroupComparison effects (FDR-corrected) ===\n")
print(related_effects %>% select(NetworkLabel, estimate, std.error, statistic, p.value, p_adj, sig),
      n = Inf)

write.csv(ph_group,       file.path(out_dir, "FamilialSimilarity_GroupComparison_DyadModel.csv"), row.names = FALSE)
write.csv(ph_sex,         file.path(out_dir, "FamilialSimilarity_SexDyad_PerNetwork.csv"),        row.names = FALSE)
write.csv(related_effects, file.path(out_dir, "FamilialSimilarity_PerNetwork_RelatedEffect.csv"), row.names = FALSE)

# Plot
custom_colors <- c("Related" = "darkgreen", "Unrelated" = "violetred")

related_effects_for_plot <- related_effects %>%
  mutate(
    y_position = 0.88,
    xstart = as.numeric(NetworkLabel) - 0.2,
    xend   = as.numeric(NetworkLabel) + 0.2
  ) %>%
  filter(sig != "ns")

ggplot(dat, aes(x = NetworkLabel, y = Dice, fill = GroupComparison)) +
  geom_violin(position = position_dodge(width = 0.9), width = 1, alpha = 0.9,
              color = "black", trim = FALSE) +
  stat_summary(fun = "mean", geom = "crossbar", width = 0.25, color = "black",
               position = position_dodge(width = 0.9)) +
  geom_text(
    data = related_effects_for_plot,
    aes(x = NetworkLabel, y = y_position + 0.02, label = sig),
    inherit.aes = FALSE, size = 8, color = "black"
  ) +
  geom_segment(
    data = related_effects_for_plot,
    aes(x = xstart - 0.05, xend = xend + 0.05,
        y = y_position + 0.01, yend = y_position + 0.01),
    inherit.aes = FALSE, linewidth = 0.6, color = "black"
  ) +
  scale_fill_manual(values = custom_colors) +
  labs(x = "Network", y = "Topography Similarity (Dice Coefficient)", fill = "Group Comparison") +
  theme_classic() +
  theme(
    axis.line          = element_line(color = "black", linewidth = 0.8),
    panel.grid         = element_blank(),
    axis.title         = element_text(size = 18, color = "black"),
    axis.text          = element_text(size = 16, color = "black"),
    legend.position    = "bottom",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 16),
    legend.key         = element_blank(),
    legend.background  = element_blank(),
    legend.box.background = element_blank()
  )

ggsave(file.path(out_dir, "FamilialSimilarity_RelatedvsUnrelated_networkwise.svg"),
       width = 10, height = 6.5, dpi = 300)
