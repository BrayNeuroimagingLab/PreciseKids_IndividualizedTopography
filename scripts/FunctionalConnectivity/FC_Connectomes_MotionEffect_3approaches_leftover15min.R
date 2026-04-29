# FC motion-effect matrices for all 3 approaches

library(readxl)
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(purrr)

rm(list = ls())

path_motion <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes_15minleftover/exports_motion/motion_all_edges.xlsx"

methods_order <- c("grouptemplate","individualmaps","highconfidence")

sheets_map <- c(
  "grouptemplate" = "grouptemplate",
  "individualmaps" = "individualmaps",
  "highconfidence" = "highconfidence"
)

# Network label order
labels_order <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

normalize_label <- function(x) {
  recode(x,
         "SMI" = "SMl", 
         .default = x
  )
}

make_long_from_sheet <- function(sheet_name, method_label, negate_beta = FALSE) {
  df_raw <- read_excel(path_motion, sheet = sheet_name)

  stopifnot(all(c("Edge","Beta_meanFD","q_meanFD") %in% names(df_raw)))
  

  split <- str_split_fixed(df_raw$Edge, "[–-]", n = 2)
  row_lab <- normalize_label(str_trim(split[,1]))
  col_lab <- normalize_label(str_trim(split[,2]))
  
  long <- tibble(
    Row  = row_lab,
    Col  = col_lab,
    Beta = as.numeric(df_raw$Beta_meanFD),
    q    = as.numeric(df_raw$q_meanFD)
  )
  

  #if (negate_beta) long <- mutate(long, Beta = -Beta)
  

  long <- long %>%
    filter(Row %in% labels_order, Col %in% labels_order)
  

  long_sym <- long %>%
    rename(vB = Beta, vq = q) %>%
    bind_rows(
      long %>% transmute(Row = Col, Col = Row, vB = Beta, vq = q)
    ) %>%
    group_by(Row, Col) %>%
    summarize(Beta = dplyr::coalesce(vB[!is.na(vB)][1], NA_real_),
              q    = dplyr::coalesce(vq[!is.na(vq)][1], NA_real_),
              .groups = "drop") %>%
    mutate(
      Method = method_label,
      Row = factor(Row, levels = rev(labels_order)),
      Col = factor(Col, levels = labels_order),
      r_norm = match(as.character(Row), labels_order),
      j      = match(as.character(Col), labels_order)
    ) %>%
    filter(j >= r_norm)
  
  long_sym
}

# Read all three sheets
motion_list <- imap(
  sheets_map,
  ~ make_long_from_sheet(sheet_name = .y, method_label = .x) 
)

motion_list <- map2(
  names(sheets_map), unname(sheets_map),
  ~ make_long_from_sheet(sheet_name = .x, method_label = .y)
)

df <- bind_rows(motion_list)
df$Method <- factor(df$Method, levels = methods_order)

# Build lower-triangle background grid (dark grey)
grid_lower <- expand_grid(
  Row    = factor(rev(labels_order), levels = rev(labels_order)),
  Col    = factor(labels_order,      levels = labels_order),
  Method = factor(levels(df$Method), levels = levels(df$Method))
) %>%
  mutate(
    r_norm = match(as.character(Row), labels_order),
    j      = match(as.character(Col), labels_order)
  ) %>%
  filter(j < r_norm)

# Significance + uniqueness across methods
df <- df %>%
  group_by(Row, Col) %>%
  mutate(sig_count = sum(!is.na(q) & q < 0.05)) %>%
  ungroup() %>%
  mutate(
    sig_star    = !is.na(q) & q < 0.05,
    unique_star = sig_star & sig_count == 1,
    mark_color  = case_when(
      unique_star ~ "red",
      sig_star    ~ "black",
      TRUE        ~ NA_character_
    )
  )


#BLIUE STAR
# --- Blue star when IND & HIGH are sig but GT is NOT (shown on GT facet only) ---

# Build per-edge significance flags by method
sig_map <- df %>%
  mutate(sig_star = !is.na(q) & q < 0.05) %>%
  select(Row, Col, Method, sig_star) %>%
  tidyr::pivot_wider(
    names_from  = Method,
    values_from = sig_star,
    values_fill = FALSE
  ) %>%
  rename(
    gt   = grouptemplate,
    ind  = individualmaps,
    high = highconfidence
  )

# ---- Plot ----
p <- ggplot() +
  geom_tile(data = grid_lower,
            aes(Col, Row),
            fill = "darkgrey", color = "white", linewidth = 0.5) +
  geom_tile(data = df,
            aes(Col, Row, fill = Beta),
            color = "white", linewidth = 0.5, na.rm = TRUE) +
  geom_text(data = subset(df, sig_star),
            aes(Col, Row, label = "*", color = mark_color),
            size = 4, na.rm = TRUE) +
  scale_x_discrete(limits = labels_order, drop = FALSE) +
  scale_y_discrete(limits = rev(labels_order), drop = FALSE) +
  scale_fill_gradient2(limits = c(-0.35, 0.35), name = "Beta (motion)") +
  scale_color_identity() +
  coord_fixed() +
  facet_wrap(~ Method, nrow = 1) +
  labs(x = NULL, y = NULL) +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    panel.grid = element_blank(),
    axis.title = element_text(color = "black"),
    axis.text = element_text(color = "black"),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.key = element_blank(),
    legend.background = element_blank(),
    legend.box.background = element_blank()
  ) +
  geom_hline(yintercept = seq(0.5, length(labels_order) + 0.5, 1),
             color = "grey90", linewidth = 0.3) +
  geom_vline(xintercept = seq(0.5, length(labels_order) + 0.5, 1),
             color = "grey90", linewidth = 0.3)

print(p)

ggsave("/Users/shefalirai/Desktop/Paper3/Figure9_FCmotionMatrices_leftover15min_plot.svg",
       plot = p, width = 12, height = 5.5, units = "in", dpi = 300)



####~~~~Motion effect for select networks~~~~####
library(readxl)
library(dplyr)
library(stringr)
library(tidyr)
library(purrr)
library(ggplot2)

rm(list = ls())

path_motion <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes_15minleftover/exports_motion/motion_all_edges.xlsx"

methods_order <- c("grouptemplate","individualmaps","highconfidence")
labels_keep  <- c("SAL","CON","DMN")

normalize_label <- function(x) recode(x, "SMI"="SMl", .default=x)

read_motion_sheet <- function(sheet_name, method_label){
  df <- read_excel(path_motion, sheet = sheet_name)
  stopifnot(all(c("Edge","Beta_meanFD","q_meanFD") %in% names(df)))
  split <- str_split_fixed(df$Edge, "[–-]", n=2)
  tibble(
    Row  = normalize_label(str_trim(split[,1])),
    Col  = normalize_label(str_trim(split[,2])),
    Beta = as.numeric(df$Beta_meanFD),
    q    = as.numeric(df$q_meanFD),
    Method = method_label
  )
}

motion_long <- imap_dfr(
  c("grouptemplate"="grouptemplate","individualmaps"="individualmaps","highconfidence"="highconfidence"),
  ~ read_motion_sheet(.y, .x)
)

# keep only SAL/CON/DMN edges (either side)
motion_scd <- motion_long %>%
  filter(Row %in% labels_keep | Col %in% labels_keep)

# wide by Method so we can compute deltas
motion_wide <- motion_scd %>%
  select(Row, Col, Method, Beta, q) %>%
  pivot_wider(names_from = Method, values_from = c(Beta, q))

# rank by biggest absolute beta change (GT vs HC)
rank_delta <- motion_wide %>%
  mutate(delta_beta_GTxHC = abs(Beta_grouptemplate - Beta_highconfidence)) %>%
  arrange(desc(delta_beta_GTxHC))

head(rank_delta %>% select(Row, Col, starts_with("Beta_"), starts_with("q_"), delta_beta_GTxHC), 12)

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(purrr)

csv_dir <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes_15minleftover/exports_csv"
paths <- c(
  grouptemplate   = file.path(csv_dir, "grouptemplate_long_fc.csv"),
  individualmaps  = file.path(csv_dir, "individualmaps_long_fc.csv"),
  highconfidence  = file.path(csv_dir, "highconfidence_long_fc.csv")
)

# ---- beh ----
beh_path <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv"

normalize_label <- function(x) recode(x, "SMI"="SMl", .default=x)

# Load behavior & pre-aggregate meanFD per Subject ("sub-#######[AC]")
beh_meanFD <- read_csv(beh_path, show_col_types = FALSE) %>%
  mutate(Subject = paste0("sub-", sub)) %>%
  group_by(Subject) %>%
  summarize(meanFD = mean(meanFD, na.rm = TRUE), .groups = "drop")


read_one <- function(path, method_label){
  df <- read_csv(path, show_col_types = FALSE)
  
  if (!"meanFD" %in% names(df)) {
    if ("mean_meanFD" %in% names(df)) df <- dplyr::rename(df, meanFD = mean_meanFD)
    else {
      beh_meanFD <- read_csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv",
                             show_col_types = FALSE) |>
        mutate(Subject = paste0("sub-", sub)) |>
        group_by(Subject) |>
        summarize(meanFD = mean(meanFD, na.rm = TRUE), .groups="drop")
      df <- df |> mutate(Subject = as.character(Subject)) |> left_join(beh_meanFD, by="Subject")
    }
  }
  
  df |>
    transmute(
      Subject = as.character(Subject),
      Method  = factor(method_label, levels = c("grouptemplate","individualmaps","highconfidence")),
      Row     = normalize_label(as.character(NetA)),
      Col     = normalize_label(as.character(NetB)),
      # vectorized canonical pair:
      Edge    = paste(pmin(Row, Col), pmax(Row, Col), sep = "–"),
      FC      = as.numeric(FC),
      meanFD  = as.numeric(meanFD)
    )
}

canon_edge <- function(a,b) paste(sort(c(a,b)), collapse="–")

subj_all <- bind_rows(
  read_one(paths["grouptemplate"],  "grouptemplate"),
  read_one(paths["individualmaps"], "individualmaps"),
  read_one(paths["highconfidence"], "highconfidence")
)


# Focus networks
focus <- c("DMN","SAL","CON","FP")
subj_focus <- subj_all %>%
  filter(Row %in% focus | Col %in% focus) %>%
  filter(is.finite(FC), is.finite(meanFD))


edges_to_show <- rank_delta |>
  filter(Row %in% c("DMN","SAL","CON","FP") | Col %in% c("DMN","SAL","CON","FP")) |>
  mutate(Edge = paste(pmin(Row, Col), pmax(Row, Col), sep = "–")) |>
  distinct(Edge, .keep_all = TRUE) |>
  arrange(desc(delta_beta_GTxHC)) |>
  slice_head(n = 8) |>
  pull(Edge)


dat_plot <- subj_focus %>%
  filter(Edge %in% edges_to_show)


