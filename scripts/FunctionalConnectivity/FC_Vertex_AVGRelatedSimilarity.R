library(tidyverse)
library(ggpubr)
library(readr)
library(lme4)
library(lmerTest)

rm(list = ls())

# FC data
fc <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/fc_long_table.csv") %>%
  filter(grepl("^N\\d+_N\\d+$", Pair))

#metadata
meta <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv") %>%
  rename(Subject = sub) %>%
  mutate(group = ifelse(group == "C", "Child", "Adult")) %>%
  distinct(Subject, group, sex)

# Merge
fc <- left_join(fc, meta, by = "Subject")

# related
related_pairs <- list(
  c("1973002C", "1973002P"), c("1973004C", "1973004P"),
  c("1973005C", "1973005P"), c("1973006C", "1973005P"),
  c("1973005C", "1973006P"), c("1973006C", "1973006P"),
  c("1973007C", "1973007P"), c("1973010C", "1973007P"),
  c("1973007C", "1973010P"), c("1973010C", "1973010P"),
  c("1973008C", "1973008P"), c("1973009C", "1973009P"),
  c("1973011C", "1973011P"), c("1973012C", "1973012P"),
  c("1973013C", "1973013P"), c("1973014C", "1973014P"),
  c("1973015C", "1973015P"), c("1973016C", "1973016P"),
  c("1973017C", "1973017P"), c("1973018C", "1973018P"),
  c("1973019C", "1973019P"), c("1973020C", "1973020P"),
  c("1973021C", "1973021P"), c("1973022C", "1973022P"),
  c("1973023C", "1973023P"), c("1973024C", "1973024P"),
  c("1973025C", "1973025P"), c("1973026C", "1973026P")
)

is_related_pair <- function(a, b, rel_list) {
  any(sapply(rel_list, function(pair) all(c(a, b) %in% pair)))
}

# one row per subject, one column per FC pair
fc_wide <- fc %>%
  select(Subject, Method, Pair, FCValue) %>%
  pivot_wider(names_from = Pair, values_from = FCValue)

# Split by method
fc_by_method <- split(fc_wide, fc_wide$Method)

avg_results <- list()

for (m in names(fc_by_method)) {
  message("Processing method: ", m)
  method_data <- fc_by_method[[m]]
  children <- meta %>% filter(group == "Child") %>% pull(Subject)
  adults <- meta %>% filter(group == "Adult") %>% pull(Subject)
  
  for (child in children) {
    subj1_data <- method_data %>% filter(Subject == child) %>% select(-Subject, -Method)
    if (nrow(subj1_data) != 1) next
    
    child_sex <- meta$sex[meta$Subject == child]
    
    related_sims <- c()
    unrelated_sims <- c()
    related_sexmatch <- c()
    unrelated_sexmatch <- c()
    
    for (adult in adults) {
      subj2_data <- method_data %>% filter(Subject == adult) %>% select(-Subject, -Method)
      if (nrow(subj2_data) != 1) next
      
      sim <- cor(as.numeric(subj1_data), as.numeric(subj2_data), use = "complete.obs")
      adult_sex <- meta$sex[meta$Subject == adult]
      same_sex <- ifelse(child_sex == adult_sex, "Same", "Different")
      
      if (is_related_pair(child, adult, related_pairs)) {
        related_sims <- c(related_sims, sim)
        related_sexmatch <- c(related_sexmatch, same_sex)
      } else {
        unrelated_sims <- c(unrelated_sims, sim)
        unrelated_sexmatch <- c(unrelated_sexmatch, same_sex)
      }
    }
    
    if (length(related_sims) > 0 && length(unrelated_sims) > 0) {
      avg_results[[length(avg_results) + 1]] <- tibble(
        Subject = child,
        Method = m,
        GroupComparison = "Related",
        Similarity = mean(related_sims, na.rm = TRUE),
        SameSex = ifelse(mean(related_sexmatch == "Same") > 0.5, "Same", "Different"),  # dominant match
        n_related = length(related_sims)
      )
      
      avg_results[[length(avg_results) + 1]] <- tibble(
        Subject = child,
        Method = m,
        GroupComparison = "Unrelated",
        Similarity = mean(unrelated_sims, na.rm = TRUE),
        SameSex = ifelse(mean(unrelated_sexmatch == "Same") > 0.5, "Same", "Different"),  # dominant match
        n_unrelated = length(unrelated_sims)
      )
    }
  }
}



# Combine all pairwise similarities
avg_similarity_df <- bind_rows(avg_results) %>%
  mutate(across(c(GroupComparison, Method, SameSex), as.factor))





## ----STATS PER METHOD-----

library(broom.mixed)

# Split by method and run separate LMMs
method_models <- avg_similarity_df %>%
  group_split(Method) %>%
  set_names(levels(avg_similarity_df$Method)) %>%
  map(~ lmer(Similarity ~ GroupComparison + (1 | Subject), data = .x))

# Summarize
model_summaries <- map(method_models, summary)

full_stats <- map_dfr(method_models, tidy, .id = "Method")

# View all rows
print(full_stats, n = Inf)



# ----- Plottingg -----

method_order <- c("grouptemplate", "individualmaps", "highconfidence")
method_labels <- c(
  "grouptemplate" = "Group Template",
  "individualmaps" = "Individual Maps",
  "highconfidence" = "High Confidence"
)

stars_df <- tibble(
  Method = factor(c("highconfidence", "individualmaps"), levels = method_order),
  xstart = 1,
  xend = 2,
  xtext = 1.5,
  y_position = c(1.009, 1.009), 
  Stars = c("*", "*")
)

avg_similarity_df$Method <- factor(avg_similarity_df$Method, levels = method_order)

avg_similarity_df <- avg_similarity_df %>%
  mutate(GroupComparison = case_when(
    GroupComparison == "Related" ~ "Related",
    GroupComparison == "Unrelated" ~ "Avg-Unrelated",
    TRUE ~ GroupComparison
  )) %>%
  mutate(GroupComparison = factor(GroupComparison, levels = c("Related", "Avg-Unrelated")))

custom_colors <- c("Related" = "darkgreen", "Avg-Unrelated" = "violetred")


ggplot(avg_similarity_df, aes(x = GroupComparison, y = Similarity, fill = GroupComparison)) +
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
  facet_wrap(~Method, labeller = labeller(Method = method_labels)) +
  scale_fill_manual(values = custom_colors) +
  scale_color_manual(values = custom_colors) +
  labs(
    x = NULL,
    y = "Whole-Connectome Similarity",
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


# Save the plot
ggsave("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/relatedvsunrelated_AVGFC_3methods.svg",
       width = 10, height = 6.5, dpi = 300)







