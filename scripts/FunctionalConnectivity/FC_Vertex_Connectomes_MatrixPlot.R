library(lmerTest)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(ggplot2)

project_dir <- getwd() #added so no hard coding of
rm(list = ls())
fc_dir <- file.path(project_dir, "exports_csv")
meta   <- read_csv(file.path(project_dir, "prckids-task_beh.csv"))

# Load
fc_files <- list.files(fc_dir, pattern = "_fc_table_.*\\.csv$", full.names = TRUE) # nolint # nolint

fc <- purrr::map_dfr(fc_files, function(path) {
  df <- read_csv(path, show_col_types = FALSE)
  method <- stringr::str_extract(path, "(?<=_fc_table_)[^\\.]+")
  df$Method <- method
  return(df)
})


meta_clean <- meta %>%
  mutate(
    Subject = paste0("sub-", sub),  # should now work!
    Group = factor(ifelse(group == "C", "Child", "Adult"), levels = c("Adult", "Child")),
    FamilyID = as.character(family),
    Sex = factor(sex),
    Motion = meanFD_z
  ) %>%
  distinct(Subject, .keep_all = TRUE)


fc_data <- left_join(fc, meta_clean, by = "Subject")

stopifnot(!any(is.na(fc_data$Group)))
stopifnot(!any(is.na(fc_data$Motion)))
stopifnot(!any(is.na(fc_data$FamilyID)))


# Valid networks (upper triangle only)
validNetworks <- c(1, 2, 3, 5, 7, 8, 9, 10, 11, 12)
network_pairs <- expand.grid(NetworkA = validNetworks, NetworkB = validNetworks) %>%
  filter(NetworkA <= NetworkB)

methods <- unique(fc_data$Method)
results_list <- list()

for (method in methods) {
  df_method <- filter(fc_data, Method == method)
  model_results <- network_pairs %>%
    mutate(
      term = paste0("Net", NetworkA, "_", NetworkB),
      beta = NA_real_,
      pval = NA_real_
    )
  for (i in 1:nrow(network_pairs)) { # nolint
    a <- network_pairs$NetworkA[i]
    b <- network_pairs$NetworkB[i]
    df_sub <- filter(df_method, NetworkA == a, NetworkB == b)
    if (nrow(df_sub) >= 6) {
      model <- tryCatch({
        lmer(FC ~ Group + Sex + Motion + (1 | FamilyID), data = df_sub)
      }, error = function(e) NULL)
      if (!is.null(model)) {
        coef_table <- summary(model)$coefficients
        model_results$beta[i] <- coef_table["GroupChild", "Estimate"]
        model_results$pval[i] <- coef_table["GroupChild", "Pr(>|t|)"]
      }
    }
  }
  # FDR correction only on valid rows
  valid_rows <- !is.na(model_results$pval)
  model_results$p_fdr <- NA_real_
  if (any(valid_rows)) {
    model_results$p_fdr[valid_rows] <- p.adjust(model_results$pval[valid_rows], method = "fdr")
  }
  model_results$method <- method
  results_list[[method]] <- model_results
}




# Combine and save
all_lme_results <- bind_rows(results_list)
write.csv(all_lme_results, "lme_results_by_network_pair.csv", row.names = FALSE)

# Optional heatmap of significant differences
plot_df <- all_lme_results %>%
  filter(p_fdr < 0.05) %>%
  mutate(pair = paste0("N", NetworkA, "-", NetworkB))

ggplot(plot_df, aes(x = method, y = pair, fill = beta)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0) +
  labs(title = "Significant FC Differences (LME β)", fill = "Beta\n(Child vs Adult)") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
