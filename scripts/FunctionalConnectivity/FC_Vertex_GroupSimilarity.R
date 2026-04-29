library(tidyverse)
library(ggpubr)
rm(list=ls())

fc <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/fc_long_table.csv") %>%
  filter(grepl("^N\\d+_N\\d+$", Pair)) %>%
  mutate(
    NetA = as.integer(sub("N(\\d+)_N\\d+", "\\1", Pair)),
    NetB = as.integer(sub("N\\d+_N(\\d+)", "\\1", Pair)),
  )

fc <- fc %>%
  pivot_longer(cols = c(NetA, NetB), names_to = "WhichNet", values_to = "NetInvolved") %>%
  distinct(Subject, Method, NetInvolved, Pair, .keep_all = TRUE)


# Load metadata
meta <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv") %>%
  rename(Subject = sub) %>%
  mutate(group = ifelse(group == "C", "Child", "Adult")) %>%
  distinct(Subject, group, sex)


# Join metadata
fc <- left_join(fc, meta, by = "Subject")

# Sibling pairs
sibling_pairs <- list(
  c("1973005C", "1973006C"),
  c("1973007C", "1973010C")
)

# check sibling pair
is_sibling_pair <- function(a, b, sib_list) {
  any(sapply(sib_list, function(pair) all(c(a, b) %in% pair)))
}

fc_collapsed <- fc %>%
  group_by(Subject, Method, Pair) %>%
  summarise(FCValue = mean(FCValue, na.rm = TRUE), .groups = "drop")

fc_wide <- fc_collapsed %>%
  pivot_wider(names_from = Pair, values_from = FCValue)

fc_wide <- fc %>%
  group_by(Subject, Method, Pair) %>%
  summarise(FCValue = mean(FCValue, na.rm = TRUE), .groups = "drop") %>%
  pivot_wider(names_from = Pair, values_from = FCValue)


# Split by method
fc_by_method <- split(fc_wide, fc_wide$Method)

# Function to compute pairwise similarities
compute_pairwise_similarity <- function(method_data, subjects, group_label, meta, skip_pairs = list()) {
  results <- list()
  sex_lookup <- meta %>% select(Subject, sex)
  pairs <- combn(subjects, 2, simplify = FALSE)
  
  for (p in pairs) {
    s1 <- p[1]; s2 <- p[2]
    
    # Skip if in excluded pair list
    if (any(sapply(skip_pairs, function(x) all(c(s1, s2) %in% x)))) next
    
    subj1_data <- method_data %>% filter(Subject == s1) %>% select(-Subject, -Method)
    subj2_data <- method_data %>% filter(Subject == s2) %>% select(-Subject, -Method)
    
    if (nrow(subj1_data) == 1 && nrow(subj2_data) == 1) {

      common_cols <- intersect(names(subj1_data), names(subj2_data))
      
      if (length(common_cols) >= 2) {
        v1 <- as.numeric(subj1_data[, common_cols])
        v2 <- as.numeric(subj2_data[, common_cols])
        
        complete_idx <- complete.cases(v1, v2)
        cor_val <- if (sum(complete_idx) >= 2) {
          cor(v1[complete_idx], v2[complete_idx])
        } else {
          NA_real_
        }
      } else {
        cor_val <- NA_real_
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

# Child and Adult group data
child_subs <- meta %>% filter(group == "Child") %>% pull(Subject)
adult_subs <- meta %>% filter(group == "Adult") %>% pull(Subject)

# Sibling child-child pairs to exclude
sibling_pairs <- list(c("1973005C", "1973006C"), c("1973007C", "1973010C"))


group_similarity <- list()

for (method_name in names(fc_by_method)) {
  message("Processing method: ", method_name)
  method_data <- fc_by_method[[method_name]]
  
  child_result <- compute_pairwise_similarity(method_data, child_subs, "Child–Child", meta, skip_pairs = sibling_pairs)
  adult_result <- compute_pairwise_similarity(method_data, adult_subs, "Adult–Adult", meta)
  
  group_similarity[[method_name]] <- bind_rows(child_result, adult_result)
}

# Combine
similarity_df <- bind_rows(group_similarity)


similarity_df <- similarity_df %>%
  mutate(across(c(GroupComparison, Method, SameSex), as.factor))


# 
# #------STATS PER METHOD-----
# 
# library(lme4)
# library(broom.mixed)
# 
# # Run LMM separately for each method
# method_models <- similarity_df %>%
#   group_split(Method) %>%
#   set_names(levels(similarity_df$Method)) %>%
#   map(~ lmer(Similarity ~ GroupComparison * SameSex + (1 | subj1) + (1 | subj2), data = .x))
# 
# # Summarize results
# model_summaries <- map(method_models, summary)
# 
# map_dfr(method_models, tidy, .id = "Method")
# 
# # Print full fixed and random effects from all models
# full_stats <- map_dfr(method_models, tidy, .id = "Method")
# 
# # Show all rows
# print(full_stats, n = Inf)



##### STATS ACROSS ALL 3 methods #######


library(lme4)
library(broom.mixed)

similarity_df <- similarity_df %>%
  mutate(pair_id = paste0(pmin(subj1, subj2), "_", pmax(subj1, subj2)))

model_combined <- lmer(
  Similarity ~ GroupComparison * SameSex * Method + (1 | pair_id),
  data = similarity_df
)

summary(model_combined)
tidy(model_combined)

library(emmeans)

emm <- emmeans(model_combined, ~ GroupComparison | Method)
pairwise_contrasts <- contrast(emm, method = "revpairwise") %>%
  summary(infer = TRUE)

print(pairwise_contrasts)



### SD numnbers


sd_summary <- similarity_df %>%
  group_by(Method, GroupComparison) %>%
  summarise(
    Mean = mean(Similarity, na.rm = TRUE),
    SD = sd(Similarity, na.rm = TRUE),
    N = n(),
    .groups = "drop"
  )

# Print
print(sd_summary)




## -----PLOTTING-----##

method_order <- c("grouptemplate", "individualmaps", "highconfidence")
method_labels <- c(
  "grouptemplate" = "Group Template",
  "individualmaps" = "Individual Maps",
  "highconfidence" = "High Confidence"
)

group_order <- c("Child–Child", "Adult–Adult")
similarity_df$GroupComparison <- factor(similarity_df$GroupComparison, levels = group_order)

stars_df <- tibble(
  Method = factor("grouptemplate", levels = method_order),
  xstart = 1,
  xend = 2,
  xtext = 1.5,
  y_position = 1.009, 
  Stars =  "*"
)

custom_colors <- c("Child–Child" = "#E68300", "Adult–Adult" = "#0072B2")
similarity_df$Method <- factor(similarity_df$Method, levels = method_order)



library(ggplot2)

ggplot(similarity_df, aes(x = GroupComparison, y = Similarity, fill = GroupComparison)) +
  geom_violin(
    position = position_dodge(width = 0.9),
    width = 1,
    alpha = 0.9,
    color = "black",
    trim = FALSE
  ) +
  stat_summary(
    fun = "mean",
    geom = "crossbar",
    width = 0.25,
    color = "black",
    position = position_dodge(width = 0.9)
  ) +
  # geom_jitter(
  #   aes(color = GroupComparison),
  #   size = 1.5,
  #   alpha = 0.6,
  #   position = position_jitterdodge(jitter.width = 0.2, dodge.width = 0.75),
  #   show.legend = FALSE
  # ) +
  facet_wrap(~Method, labeller = labeller(Method = method_labels)) +
  scale_fill_manual(values = custom_colors) +
  scale_color_manual(values = custom_colors) +
  labs(
    x = NULL,
    y = "Dense-Connectome Similarity",
    fill = "Group Comparison"
  ) +
  geom_text(
    data = stars_df,
    aes(x = xtext, y = y_position, label = Stars),
    inherit.aes = FALSE,
    size = 8,
    color = "black"
  ) +
  geom_segment(
    data = stars_df,
    aes(x = xstart, xend = xend, y = y_position - 0.01, yend = y_position - 0.01),
    inherit.aes = FALSE,
    linewidth = 0.6,
    color = "black"
  ) +
  coord_cartesian(ylim = c(0.75, 1.01)) +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title = element_text(size = 18, color = "black"),
    axis.text = element_text(size = 16, color = "black"),
    strip.text = element_text(size = 16, color = "black"),
    legend.position = "none"
  )


ggsave("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/FC_GroupSimilarity_3methods.svg",
       width = 10, height = 6.5, dpi = 300)







