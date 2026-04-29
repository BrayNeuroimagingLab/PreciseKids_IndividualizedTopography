# ----------------------------
# LMA vs LMC Connectome Similarity
# ----------------------------

library(tidyverse)
library(lme4)
library(broom.mixed)
library(emmeans)
library(ggpubr)
library(ggplot2)

rm(list = ls())

# ----------------------------
# Load FC data
# ----------------------------
fc <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/fc_long_table.csv") %>%
  filter(grepl("^N\\d+_N\\d+$", Pair)) %>%
  mutate(
    NetA = as.integer(sub("N(\\d+)_N\\d+", "\\1", Pair)),
    NetB = as.integer(sub("N\\d+_N(\\d+)", "\\1", Pair)),
  ) %>%
  pivot_longer(cols = c(NetA, NetB), names_to = "WhichNet", values_to = "NetInvolved") %>%
  distinct(Subject, Method, NetInvolved, Pair, .keep_all = TRUE)

# ----------------------------
# Load metadata
# ----------------------------
meta <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv") %>%
  rename(Subject = sub) %>%
  distinct(Subject, motion_group, sex)

# Join metadata
fc <- left_join(fc, meta, by = "Subject")

# ----------------------------
# Collapse to wide format
# ----------------------------
fc_wide <- fc %>%
  group_by(Subject, Method, Pair) %>%
  summarise(FCValue = mean(FCValue, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Pair, values_from = FCValue)

# Split by method
fc_by_method <- split(fc_wide, fc_wide$Method)

# ----------------------------
# Helper: compute pairwise similarity
# ----------------------------
compute_pairwise_similarity <- function(method_data, subjects, group_label, meta, skip_pairs = list()) {
  results <- list()
  sex_lookup <- meta %>% select(Subject, sex)
  pairs <- combn(subjects, 2, simplify = FALSE)
  
  for (p in pairs) {
    s1 <- p[1]; s2 <- p[2]
    # skip sibling pairs
    if (any(sapply(skip_pairs, function(x) all(c(s1, s2) %in% x)))) next
    
    subj1_data <- method_data %>% filter(Subject == s1) %>% select(-Subject, -Method)
    subj2_data <- method_data %>% filter(Subject == s2) %>% select(-Subject, -Method)
    
    if (nrow(subj1_data) == 1 && nrow(subj2_data) == 1) {
      common_cols <- intersect(names(subj1_data), names(subj2_data))
      
      cor_val <- NA_real_
      if (length(common_cols) >= 2) {
        v1 <- as.numeric(subj1_data[, common_cols])
        v2 <- as.numeric(subj2_data[, common_cols])
        complete_idx <- complete.cases(v1, v2)
        if (sum(complete_idx) >= 2) {
          cor_val <- cor(v1[complete_idx], v2[complete_idx])
        }
      }
      
      sex1 <- sex_lookup$sex[sex_lookup$Subject == s1]
      sex2 <- sex_lookup$sex[sex_lookup$Subject == s2]
      same_sex <- ifelse(sex1 == sex2, "Same", "Different")
      
      results[[length(results) + 1]] <- tibble(
        subj1 = s1, subj2 = s2,
        Similarity = cor_val,
        Method = unique(method_data$Method),
        GroupComparison = group_label,
        SameSex = same_sex
      )
    }
  }
  
  bind_rows(results)
}

# ----------------------------
# Subjects by motion group
# ----------------------------
lma_subs <- meta %>% filter(motion_group == "LMA") %>% pull(Subject)
lmc_subs <- meta %>% filter(motion_group == "LMC") %>% pull(Subject)
hmc_subs <- meta %>% filter(motion_group == "HMC") %>% pull(Subject)

# Sibling pairs to exclude
sibling_pairs <- list(c("1973005C", "1973006C"), 
                      c("1973007C", "1973010C"))

# ----------------------------
# Compute group similarities
# ----------------------------
group_similarity <- list()

for (method_name in names(fc_by_method)) {
  message("Processing method: ", method_name)
  method_data <- fc_by_method[[method_name]]
  
  lma_result <- compute_pairwise_similarity(method_data, lma_subs, "LMA–LMA", meta)
  lmc_result <- compute_pairwise_similarity(method_data, lmc_subs, "LMC–LMC", meta, skip_pairs = sibling_pairs)
  hmc_result <- compute_pairwise_similarity(method_data, hmc_subs, "HMC–HMC", meta, skip_pairs = sibling_pairs)
  
  group_similarity[[method_name]] <- bind_rows(lma_result, lmc_result, hmc_result)
}

similarity_df <- bind_rows(group_similarity) %>%
  mutate(across(c(GroupComparison, Method, SameSex), as.factor),
         pair_id = paste0(pmin(subj1, subj2), "_", pmax(subj1, subj2)))

# ----------------------------
# Stats across methods
# ----------------------------
model_combined <- lmer(
  Similarity ~ GroupComparison * SameSex * Method + (1 | pair_id),
  data = similarity_df
)

summary(model_combined)
# 
# emm <- emmeans(model_combined, ~ GroupComparison | Method)
# pairwise_contrasts <- contrast(emm, method = "pairwise") %>% summary(infer = TRUE)
# print(pairwise_contrasts)

# ----------------------------
# Descriptive stats
# ----------------------------
sd_summary <- similarity_df %>%
  group_by(Method, GroupComparison) %>%
  summarise(
    Mean = mean(Similarity, na.rm = TRUE),
    SD = sd(Similarity, na.rm = TRUE),
    N = n(),
    .groups = "drop"
  )
print(sd_summary)



# ----------------------------
# Plotting
# ----------------------------
method_order <- c("grouptemplate", "individualmaps", "highconfidence")
method_labels <- c(
  "grouptemplate" = "Group Template",
  "individualmaps" = "Individual Maps",
  "highconfidence" = "High Confidence"
)

# Factor levels & colors
similarity_df$Method <- factor(similarity_df$Method, levels = method_order)
group_order <- c("LMA–LMA", "LMC–LMC", "HMC–HMC")
similarity_df$GroupComparison <- factor(similarity_df$GroupComparison, levels = group_order)
custom_colors <- c("LMA–LMA" = "#0072B2", "LMC–LMC" = "#E68300", "HMC–HMC" = "#B22222")


# Plot
p <- ggplot(similarity_df, aes(x = GroupComparison, y = Similarity, fill = GroupComparison)) +
  geom_violin(
    position = position_dodge(width = 0.8),
    width = 0.6,
    alpha = 0.8,
    color = "black",
    trim = FALSE
  ) +
  stat_summary(
    fun = "mean",
    geom = "crossbar",
    width = 0.25,
    color = "black",
    position = position_dodge(width = 0.8)
  ) +
  facet_wrap(~Method, labeller = labeller(Method = method_labels)) +
  scale_fill_manual(values = custom_colors) +
  labs(
    x = NULL,
    y = "Dense-Connectome Similarity",
    fill = "Motion Group"
  ) +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    axis.title = element_text(size = 18, face = "bold"),
    axis.text = element_text(size = 14, color = "black"),
    strip.text = element_text(size = 16, face = "bold"),
    legend.position = "none"
  )

print(p)

ggsave("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/FC_GroupSimilarity_3groups.svg",
       width = 10, height = 6.5, dpi = 300)
