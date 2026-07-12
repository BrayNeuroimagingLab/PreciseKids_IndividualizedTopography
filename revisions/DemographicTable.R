# DemographicTable.R
# Table 1: charactieristics for children & parents
# uses prckids-motion_beh.xlsx for age and motion group
# .tsv demographic files for characteristics

library(dplyr)
library(tidyr)
library(readr)
library(readxl)
library(gt)
library(stringr)

data_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_Revisionsdata/"
out_dir  <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"

motion <- read_excel("/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx") %>%
  rename(participant_id = sub) %>%
  mutate(participant_id = paste0("sub-", participant_id))

dem_child  <- read_tsv(file.path(data_dir, "demographic_child.tsv"),  show_col_types = FALSE)
dem_parent <- read_tsv(file.path(data_dir, "demographic_parent.tsv"), show_col_types = FALSE)

nums       <- setdiff(2:26, 3)
child_ids  <- sprintf("sub-1973%03dC", nums)
parent_ids <- sprintf("sub-1973%03dP", nums)

find_col <- function(df, pattern) grep(pattern, names(df), ignore.case = TRUE, value = TRUE)[1]
is_yes   <- function(x) tolower(trimws(x)) == "yes"

parse_ethnicity <- function(df) {
  white_col <- find_col(df, "White.*Caucasian")
  asian_col <- find_col(df, "Asian Canadian")
  df %>%
    mutate(
      is_white  = !is.na(.data[[white_col]]) & .data[[white_col]] != "n/a",
      is_asian  = !is.na(.data[[asian_col]]) & .data[[asian_col]] != "n/a",
      ethnicity = case_when(
        is_white & is_asian ~ "Mixed/Other",
        is_white             ~ "White/European",
        is_asian             ~ "Asian",
        TRUE                 ~ "Mixed/Other"
      )
    ) %>%
    select(participant_id, ethnicity)
}

parse_education <- function(df) {
  df %>%
    rename(edu_raw = `You::What is the highest level of school you/your partner have obtained?`) %>%
    mutate(
      education_group = case_when(
        str_detect(edu_raw, "High school")                        ~ "High school",
        str_detect(edu_raw, "Bachelor")                           ~ "Bachelor's degree",
        str_detect(edu_raw, "Master|Professional|Doctoral|PhD")  ~ "Graduate degree (Master's/Doctoral)",
        TRUE                                                       ~ "Other/Not reported"
      )
    ) %>%
    select(participant_id, education_group)
}

parse_clinical <- function(df) {
  dx_col      <- find_col(df, "psychiatric.*diagnosis|diagnosis.*psychiatric")
  trauma_col  <- find_col(df, "head trauma")
  health_col  <- find_col(df, "significant.*health")
  meds_col    <- find_col(df, "regularly take any")
  support_col <- find_col(df, "supportive services")
  df %>%
    mutate(
      has_dx      = is_yes(.data[[dx_col]]),
      has_trauma  = is_yes(.data[[trauma_col]]),
      has_health  = is_yes(.data[[health_col]]),
      on_meds     = is_yes(.data[[meds_col]]),
      has_support = is_yes(.data[[support_col]])
    ) %>%
    select(participant_id, has_dx, has_trauma, has_health, on_meds, has_support)
}

eth_child   <- parse_ethnicity(dem_child)
eth_parent  <- parse_ethnicity(dem_parent)
edu_parent  <- parse_education(dem_parent)
clin_child  <- parse_clinical(dem_child)
clin_parent <- parse_clinical(dem_parent)

child_data <- motion %>%
  filter(participant_id %in% child_ids) %>%
  left_join(eth_child,  by = "participant_id") %>%
  left_join(clin_child, by = "participant_id") %>%
  mutate(sex_label = ifelse(sex == "F", "Female", "Male"))

parent_data <- motion %>%
  filter(participant_id %in% parent_ids) %>%
  left_join(eth_parent,  by = "participant_id") %>%
  left_join(edu_parent,  by = "participant_id") %>%
  left_join(clin_parent, by = "participant_id") %>%
  mutate(sex_label = ifelse(sex == "F", "Female", "Male"))

fmt_np <- function(n_val, total) sprintf("%d (%.1f%%)", as.integer(n_val), 100 * n_val / total)

n_c <- nrow(child_data)
n_p <- nrow(parent_data)

age_c   <- sprintf("%.2f (%.2f)", mean(child_data$age),  sd(child_data$age))
age_p   <- sprintf("%.2f (%.2f)", mean(parent_data$age), sd(parent_data$age))

sex_f_c <- fmt_np(sum(child_data$sex_label  == "Female"), n_c)
sex_m_c <- fmt_np(sum(child_data$sex_label  == "Male"),   n_c)
sex_f_p <- fmt_np(sum(parent_data$sex_label == "Female"), n_p)
sex_m_p <- fmt_np(sum(parent_data$sex_label == "Male"),   n_p)

eth_levels <- c("White/European", "Asian", "Mixed/Other")
eth_c <- sapply(eth_levels, function(e) fmt_np(sum(child_data$ethnicity  == e), n_c))
eth_p <- sapply(eth_levels, function(e) fmt_np(sum(parent_data$ethnicity == e), n_p))

lmc_c <- fmt_np(sum(child_data$motion_group  == "LMC", na.rm = TRUE), n_c)
hmc_c <- fmt_np(sum(child_data$motion_group  == "HMC", na.rm = TRUE), n_c)
lma_p <- fmt_np(sum(parent_data$motion_group == "LMA", na.rm = TRUE), n_p)
hma_p <- fmt_np(sum(is.na(parent_data$motion_group) | parent_data$motion_group %in% c("NaN","N/A")), n_p)

edu_levels <- c("High school", "Bachelor's degree", "Graduate degree (Master's/Doctoral)")
edu_p <- sapply(edu_levels, function(e) fmt_np(sum(parent_data$education_group == e, na.rm = TRUE), n_p))
edu_c <- rep("N/A", length(edu_levels))

dx_c      <- fmt_np(sum(child_data$has_dx,      na.rm = TRUE), n_c)
dx_p      <- fmt_np(sum(parent_data$has_dx,      na.rm = TRUE), n_p)
trauma_c  <- fmt_np(sum(child_data$has_trauma,   na.rm = TRUE), n_c)
trauma_p  <- fmt_np(sum(parent_data$has_trauma,  na.rm = TRUE), n_p)
health_c  <- fmt_np(sum(child_data$has_health,   na.rm = TRUE), n_c)
health_p  <- fmt_np(sum(parent_data$has_health,  na.rm = TRUE), n_p)
meds_c    <- fmt_np(sum(child_data$on_meds,      na.rm = TRUE), n_c)
meds_p    <- fmt_np(sum(parent_data$on_meds,     na.rm = TRUE), n_p)
support_c <- fmt_np(sum(child_data$has_support,  na.rm = TRUE), n_c)
support_p <- fmt_np(sum(parent_data$has_support, na.rm = TRUE), n_p)

tbl <- tibble(
  Characteristic = c(
    "Age, mean (SD), y",
    "Sex, n (%)",
      "  Female",
      "  Male",
    "Race/Ethnicity, n (%)",
      "  White/European",
      "  Asian",
      "  Mixed/Other",
    "Motion group, n (%)",
      "  Low-motion",
      "  High-motion",
    "Parental education, n (%)",
      "  High school",
      "  Bachelor's degree",
      "  Graduate degree (Master's/Doctoral)",
    "Clinical history, n (%)",
      "  Psychiatric/neurodevelopmental diagnosis",
      "  History of head trauma",
      "  Significant health concerns",
      "  Currently taking medications",
      "  Receiving supportive services"
  ),
  Children_col = c(
    age_c,
    "", sex_f_c, sex_m_c,
    "", eth_c[["White/European"]], eth_c[["Asian"]], eth_c[["Mixed/Other"]],
    "", lmc_c, hmc_c,
    "", edu_c[1], edu_c[2], edu_c[3],
    "", dx_c, trauma_c, health_c, meds_c, support_c
  ),
  Parents_col = c(
    age_p,
    "", sex_f_p, sex_m_p,
    "", eth_p[["White/European"]], eth_p[["Asian"]], eth_p[["Mixed/Other"]],
    "", lma_p, hma_p,
    "", edu_p[1], edu_p[2], edu_p[3],
    "", dx_p, trauma_p, health_p, meds_p, support_p
  )
)

header_rows <- which(tbl$Children_col == "")
data_rows   <- which(tbl$Children_col != "" & tbl$Characteristic != "Age, mean (SD), y")

gt_tbl <- tbl %>%
  gt() %>%
  cols_label(
    Characteristic = "Characteristic",
    Children_col   = paste0("Children\n(n = ", n_c, ")"),
    Parents_col    = paste0("Parents\n(n = ", n_p, ")")
  ) %>%
  tab_header(title = "Table 1. Group Characteristics") %>%
  tab_style(style = cell_text(weight = "bold"),
            locations = cells_body(rows = header_rows)) %>%
  tab_style(style = cell_text(indent = px(18)),
            locations = cells_body(rows = data_rows)) %>%
  tab_style(style = cell_fill(color = "#F5F5F5"),
            locations = cells_body(rows = c(2:4))) %>%
  tab_style(style = cell_fill(color = "#F5F5F5"),
            locations = cells_body(rows = c(9:11))) %>%
  tab_style(style = cell_fill(color = "#F5F5F5"),
            locations = cells_body(rows = c(16:21))) %>%
  cols_align(align = "left",   columns = Characteristic) %>%
  cols_align(align = "center", columns = c(Children_col, Parents_col)) %>%
  cols_width(Characteristic ~ px(340), Children_col ~ px(175), Parents_col ~ px(175)) %>%
  tab_footnote(
    footnote  = "LMC = low-motion children (n=10); HMC = high-motion children (n=14); LMA = low-motion adults. Motion groups defined by framewise displacement censoring (FD > 0.15 mm).",
    locations = cells_body(columns = Characteristic, rows = 9)
  ) %>%
  tab_footnote(
    footnote  = "Counts reflect adult-reported responses. Specific diagnoses are not reported.",
    locations = cells_body(columns = Characteristic, rows = 17)
  ) %>%
  tab_options(
    table.font.size              = 13,
    heading.title.font.size      = 15,
    column_labels.font.weight    = "bold",
    table.border.top.color       = "black",
    table.border.bottom.color    = "black",
    column_labels.border.bottom.color = "black",
    footnotes.font.size          = 11
  )

gt::gtsave(gt_tbl, filename = file.path(out_dir, "Table1_Demographics.docx"))
