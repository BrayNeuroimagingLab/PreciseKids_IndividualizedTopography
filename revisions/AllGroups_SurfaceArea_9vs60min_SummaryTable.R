# LMA vs LMC vs HMC supp table 1
# in network surface area, at 9 min and 60 min, from the LME results



library(dplyr)
library(tidyr)
library(readr)
library(gt)

data_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
out_dir  <- data_dir

lme_csv <- file.path(data_dir, "AllGroups_SurfaceArea_9vs60min_groupLME.csv")
res     <- read_csv(lme_csv, show_col_types = FALSE)

desired_order <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

stars_from_p <- function(p) {
  case_when(
    is.na(p)   ~ "",
    p < 0.001  ~ "***",
    p < 0.01   ~ "**",
    p < 0.05   ~ "*",
    TRUE       ~ "ns"
  )
}

# reshape: one row per Network x DataLength x pairwise comparison
long_tbl <- res %>%
  transmute(
    DataLength,
    NetworkLabel = factor(NetworkLabel, levels = desired_order),
    `LMA vs LMC` = p_LMA_LMC_FDR,
    `LMA vs HMC` = p_LMA_HMC_FDR,
    `LMC vs HMC` = p_LMC_HMC_FDR,
    b_LMC, b_HMC
  ) %>%
  pivot_longer(
    cols      = c(`LMA vs LMC`, `LMA vs HMC`, `LMC vs HMC`),
    names_to  = "Comparison",
    values_to = "p_FDR"
  ) %>%
  mutate(
    # sign/direction of the difference, derived from the relevant beta
    # (betas are relative to LMA reference: b_LMC = LMC-LMA, b_HMC = HMC-LMA)
    Beta = case_when(
      Comparison == "LMA vs LMC" ~  b_LMC,
      Comparison == "LMA vs HMC" ~  b_HMC,
      Comparison == "LMC vs HMC" ~ (b_HMC - b_LMC)
    ),
    Direction = case_when(
      is.na(Beta)        ~ "",
      Beta > 0 & Comparison == "LMA vs LMC" ~ "LMC > LMA",
      Beta < 0 & Comparison == "LMA vs LMC" ~ "LMC < LMA",
      Beta > 0 & Comparison == "LMA vs HMC" ~ "HMC > LMA",
      Beta < 0 & Comparison == "LMA vs HMC" ~ "HMC < LMA",
      Beta > 0 & Comparison == "LMC vs HMC" ~ "HMC > LMC",
      Beta < 0 & Comparison == "LMC vs HMC" ~ "HMC < LMC"
    ),
    Sig    = stars_from_p(p_FDR),
    p_FDR  = round(p_FDR, 4)
  ) %>%
  select(DataLength, NetworkLabel, Comparison, Direction, Beta, p_FDR, Sig) %>%
  arrange(DataLength, NetworkLabel, Comparison)

write_csv(long_tbl, file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_SummaryTable.csv"))
cat("Saved flat summary table -> AllGroups_SurfaceArea_9vs60min_SummaryTable.csv\n")

# ---- focused table: LMA vs LMC only, both data lengths, all networks ----
lma_lmc_tbl <- long_tbl %>%
  filter(Comparison == "LMA vs LMC") %>%
  select(DataLength, NetworkLabel, Direction, Beta, p_FDR, Sig) %>%
  arrange(DataLength, NetworkLabel)

write_csv(lma_lmc_tbl, file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_LMAvsLMC_table.csv"))
cat("Saved LMA-vs-LMC table -> AllGroups_SurfaceArea_9vs60min_LMAvsLMC_table.csv\n")

# ---- formatted gt table: significant results only, both comparisons & lengths ----
sig_tbl <- long_tbl %>%
  filter(p_FDR < 0.05) %>%
  arrange(DataLength, p_FDR) %>%
  select(DataLength, NetworkLabel, Comparison, Direction, Beta, p_FDR, Sig)

gt_sig <- sig_tbl %>%
  gt(groupname_col = "DataLength") %>%
  tab_header(
    title    = "Significant pairwise group differences in network surface area",
    subtitle = "LME: Surface Area ~ Motion Group + (1 | Family ID), FDR-corrected across networks"
  ) %>%
  cols_label(
    NetworkLabel = "Network",
    Comparison   = "Comparison",
    Direction    = "Direction",
    Beta         = "β (diff.)",
    p_FDR        = "p (FDR)",
    Sig          = "Sig."
  ) %>%
  fmt_number(columns = Beta,  decimals = 2) %>%
  fmt_number(columns = p_FDR, decimals = 4) %>%
  tab_options(table.font.size = 12) %>%
  tab_style(
    style     = cell_text(weight = "bold"),
    locations = cells_row_groups()
  )

gtsave(gt_sig, file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_SummaryTable.html"))
gtsave(gt_sig, file.path(out_dir, "AllGroups_SurfaceArea_9vs60min_SummaryTable.docx"))
cat("Saved formatted significant-results table -> .html and .docx\n")

print(sig_tbl, n = Inf)
