# SurfaceArea ~ Sex + Age_wc * NetworkLabel + (1|Family) + (1|Subject)
# Run separately within each motion group (LMA, LMC, HMC)
# Age mean-centered within each grop

library(readr)
library(dplyr)
library(readxl)
library(lme4)
library(lmerTest)
library(emmeans)
library(broom.mixed)
library(car)

base_path   <- "/Users/shefalirai/Desktop/Paper3/PK_networkassignment/HCPOverlap_MaxDice_Entropy/"
long_csv    <- file.path(base_path, "per_subject_surface_area_by_network_LONG.csv")
motion_xlsx <- "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"
out_dir     <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"

desired_order <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

lma_nums <- c(2,4,5,6,7,8,9,10,11,12,13,14,15,16,18,19,20,21,23,24,25,26)
lmc_nums <- c(2,5,7,9,15,18,21,23,25,26)
hmc_nums <- c(4,6,8,10,11,12,13,14,16,17,19,20,22,24)

lma_subs <- paste0("sub-1973", sprintf("%03d", lma_nums), "P")
lmc_subs <- paste0("sub-1973", sprintf("%03d", lmc_nums), "C")
hmc_subs <- paste0("sub-1973", sprintf("%03d", hmc_nums), "C")

motion_group_lookup <- bind_rows(
  tibble(Subject = lma_subs, MotionGroup = "LMA"),
  tibble(Subject = lmc_subs, MotionGroup = "LMC"),
  tibble(Subject = hmc_subs, MotionGroup = "HMC")
)

# data frame
df <- read_csv(long_csv, show_col_types = FALSE)

meta <- read_excel(motion_xlsx) %>%
  mutate(
    Subject = paste0("sub-", trimws(as.character(sub))),
    Family  = factor(family),
    Sex     = factor(sex),
    Age     = as.numeric(age)
  ) %>%
  select(Subject, Family, Sex, Age)

df <- df %>%
  left_join(meta, by = "Subject") %>%
  left_join(motion_group_lookup, by = "Subject") %>%
  filter(!is.na(MotionGroup)) %>%
  mutate(
    MotionGroup  = factor(MotionGroup, levels = c("LMA", "LMC", "HMC")),
    NetworkLabel = factor(NetworkLabel, levels = desired_order)
  ) %>%
  # mean-center age within each motion group independently
  group_by(MotionGroup) %>%
  mutate(Age_wc = Age - mean(Age, na.rm = TRUE)) %>%
  ungroup()

# print age means per group for reporting
age_means <- df %>%
  distinct(Subject, MotionGroup, Age) %>%
  group_by(MotionGroup) %>%
  summarise(mean_age = mean(Age), sd_age = sd(Age),
            min_age = min(Age), max_age = max(Age), .groups = "drop")
print(age_means)

# One model per group
run_age_model <- function(group_label, data) {

  d <- data %>% filter(MotionGroup == group_label)
  cat(sprintf("Group: %s  (N subjects = %d)\n",
              group_label, n_distinct(d$Subject)))
  cat(sprintf("Age range: %.1f – %.1f yrs  (mean %.1f, centered at 0)\n",
              min(d$Age, na.rm=TRUE), max(d$Age, na.rm=TRUE),
              mean(d$Age, na.rm=TRUE)))

  m <- lmer(
    SurfaceArea ~ Sex + Age_wc * NetworkLabel + (1|Family) + (1|Subject),
    data = d, REML = TRUE
  )

  cat("--- Model summary ---\n"); print(summary(m))
  cat("\n--- Type III ANOVA (Satterthwaite) ---\n")
  print(car::Anova(m, type = 3))

  # per-network age slopes with FDR
  age_trends <- emtrends(m, ~ NetworkLabel, var = "Age_wc") %>%
    summary(infer = TRUE) %>%
    as.data.frame() %>%
    mutate(
      NetworkLabel = factor(as.character(NetworkLabel), levels = desired_order),
      p_adj = p.adjust(p.value, method = "BH"),
      sig   = case_when(
        p_adj < 0.001 ~ "***", p_adj < 0.01 ~ "**",
        p_adj < 0.05  ~ "*",   TRUE          ~ "ns"
      )
    ) %>%
    arrange(NetworkLabel)

  cat(sprintf("\n--- Per-network Age_wc slopes: %s (FDR-corrected) ---\n", group_label))
  print(age_trends[, c("NetworkLabel","Age_wc.trend","SE","t.ratio","p.value","p_adj","sig")],
        digits = 4, row.names = FALSE)

  return(list(model = m, age_trends = age_trends))
}

#Each group run
sink(file.path(out_dir, "lmer_SurfaceArea_AgeByNetwork_perGroup.txt"))

results <- list()
for (grp in c("LMA", "LMC", "HMC")) {
  results[[grp]] <- run_age_model(grp, df)
}

sink()

#table
all_trends <- bind_rows(
  lapply(c("LMA","LMC","HMC"), function(g) {
    results[[g]]$age_trends %>%
      mutate(MotionGroup = g) %>%
      select(MotionGroup, NetworkLabel, Age_wc.trend, SE, t.ratio,
             p.value, p_adj, sig)
  })
)

write_csv(all_trends,
          file.path(out_dir, "SurfaceArea_AgeByNetwork_perGroup_slopes.csv"))
print(as.data.frame(all_trends), row.names = FALSE)

