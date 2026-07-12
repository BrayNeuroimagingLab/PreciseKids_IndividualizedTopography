# Per-network surface-area model on 9 minutes of data, with 60 min as a check.
# surface_area ~ Group + CensoredVolumes + Sex + (1|Family) per network, FDR across networks.

library(tidyverse)
library(readxl)
library(lme4)
library(lmerTest)
library(broom.mixed)

res_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
sa_csv <- file.path(res_dir, "TrueSurfaceArea_9vs60min_persubject.csv")
demo_csv <- "/Users/shefalirai/Downloads/subject-data-csv.txt"
motion_xlsx <- "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"

net_order <- c("DMN", "VIS", "FP", "DAN", "VAN", "SAL", "CON", "SMd", "SMl", "AUD", "PON")

# head motion = number of censored volumes (FD > 0.15 mm)
censored <- read_excel(motion_xlsx) %>%
  transmute(Subject = paste0("sub-", trimws(as.character(sub))),
            CensoredVolumes = as.numeric(censored_volumes))

demo <- read_csv(demo_csv, show_col_types = FALSE) %>%
  transmute(Subject = paste0("sub-", `Subject ID`),
            Family = factor(Family),
            Sex = factor(Sex),
            Group = factor(Group, levels = c("C", "P"))) %>%  # reference = child, so coef is GroupP
  left_join(censored, by = "Subject")

sa <- read_csv(sa_csv, show_col_types = FALSE) %>%
  select(Subject, NetworkLabel, Pct_9min, Pct_60min)

run_table <- function(pct_col) {
  df <- sa %>%
    mutate(surface_area = .data[[pct_col]] / 100) %>%  # proportion, matches original scale
    left_join(demo, by = "Subject") %>%
    filter(NetworkLabel %in% net_order)

  fits <- df %>%
    nest(data = -NetworkLabel) %>%
    mutate(tidy = map(data, ~ tidy(
      lmer(surface_area ~ Group + CensoredVolumes + Sex + (1 | Family), data = .x)))) %>%
    select(NetworkLabel, tidy) %>%
    unnest(tidy) %>%
    filter(effect == "fixed", term %in% c("GroupP", "CensoredVolumes", "SexM")) %>%
    transmute(Network = NetworkLabel, Term = term,
              Estimate = estimate, `SD Error` = std.error,
              Statistic = statistic, `P value` = p.value)

  fits %>%
    group_by(Term) %>%
    mutate(`P-adj. value` = p.adjust(`P value`, method = "fdr")) %>%
    ungroup() %>%
    mutate(Term = recode(Term, GroupP = "Group", CensoredVolumes = "Motion", SexM = "Sex (M)"),
           Sig = cut(`P value`, c(-Inf, .001, .01, .05, Inf), c("***", "**", "*", "")),
           `Sig (FDR)` = cut(`P-adj. value`, c(-Inf, .001, .01, .05, Inf), c("***", "**", "*", ""))) %>%
    arrange(factor(Term, levels = c("Group", "Sex (M)", "Motion")), `P-adj. value`)
}

tab_9 <- run_table("Pct_9min")
tab_60 <- run_table("Pct_60min")

write_csv(tab_9, file.path(res_dir, "SurfaceArea_9min_SupplementalTable.csv"))
write_csv(tab_60, file.path(res_dir, "SurfaceArea_60min_SupplementalTable_CHECK.csv"))

cat("=== 9-min table ===\n")
print(as.data.frame(tab_9), digits = 4, row.names = FALSE)
cat("\n=== 60-min table (check against published) ===\n")
print(as.data.frame(tab_60), digits = 4, row.names = FALSE)
