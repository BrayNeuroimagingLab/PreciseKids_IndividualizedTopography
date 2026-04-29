# FC Matrices between 3 approaches from Matlab code but plot in R

library(readr) 
library(dplyr)
library(tidyr)
library(ggplot2)

rm(list = ls())

dir <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes_15minleftover/exports_csv"

methods <- c("grouptemplate","highconfidence","individualmaps")


labels_order <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

normalize_label <- function(x) {
  recode(x,
         "SMI" = "SMl",
         .default = x
  )
}

read_mat_long <- function(method, type = c("beta","q")) {
  type <- match.arg(type)
  path <- file.path(dir, sprintf("%s_%s_matrix.csv", method, type))
  m <- read_csv(path, show_col_types = FALSE)
  colnames(m)[1] <- "Row"
  
  # normalize labels in rows and columns
  m$Row <- normalize_label(m$Row)
  names(m) <- c("Row", vapply(names(m)[-1], normalize_label, character(1)))
  
  rows_present <- intersect(labels_order, m$Row)
  cols_present <- intersect(labels_order, names(m))
  m <- m %>%
    filter(Row %in% rows_present) %>%
    select(Row, all_of(cols_present))
  
  # long
  val_col <- if (type == "beta") "Beta" else "q"
  long <- pivot_longer(m, -Row, names_to = "Col", values_to = val_col)
  
  if (type == "beta") long <- mutate(long, Beta = -Beta)
  

  long_sym <- long %>%
    rename(v = !!sym(val_col)) %>%
    bind_rows(
      long %>% rename(Col = Row, Row = Col) %>% rename(v = !!sym(val_col))
    ) %>%
    group_by(Row, Col) %>%
    summarize(v = dplyr::coalesce(v[!is.na(v)][1], NA_real_), .groups = "drop") %>%
    rename(!!val_col := v)
  

  long_sym %>%
    mutate(
      Method = method,
      Row = factor(Row, levels = rev(labels_order)),
      Col = factor(Col, levels = labels_order),
      r_norm = match(as.character(Row), labels_order),
      j      = match(as.character(Col), labels_order)
    ) %>%
    filter(j >= r_norm)
}



beta_all <- bind_rows(lapply(methods, read_mat_long, "beta"))
q_all    <- bind_rows(lapply(methods, read_mat_long, "q"))

df <- left_join(beta_all, q_all, by = c("Row","Col","Method"))


df$Method <- factor(df$Method,
                    levels = c("grouptemplate","individualmaps","highconfidence"))


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

# Significance + uniqueness
df <- df %>%
  group_by(Row, Col) %>%
  mutate(sig_count = sum(q < 0.05, na.rm = TRUE)) %>%
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



# Plot
p <- ggplot() +
  # dark grey lower triangle first
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
  scale_fill_gradient2(limits = c(-0.15, 0.15), name = "Beta") +
  scale_color_identity() +
  coord_fixed() +
  facet_wrap(~ Method, nrow = 1) +
  labs(x = NULL, y = NULL) +
  theme_classic() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.8),
    panel.grid = element_blank(),
    axis.title = element_text( color = "black"),
    axis.text = element_text( color = "black"),
    legend.position = "bottom",
    legend.title = element_blank(),
    legend.key = element_blank(),
    legend.background = element_blank(),
    legend.box.background = element_blank()
  )+
  geom_hline(yintercept = seq(0.5, length(labels_order) + 0.5, 1),
             color = "grey90", linewidth = 0.3) +
  geom_vline(xintercept = seq(0.5, length(labels_order) + 0.5, 1),
             color = "grey90", linewidth = 0.3)

print(p)

# Save as SVG
ggsave("/Users/shefalirai/Desktop/Paper3/Figure8_fc_matrices_leftover15min_plot.svg",
       plot = p, width = 12, height = 5.5, units = "in")



