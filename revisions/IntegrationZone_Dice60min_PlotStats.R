# Low-confidence regions (Dice < 0.3) — motion_group-only model 
#
# LMM: iz_pct_cortex_area ~ motion_group + (1 | family_id)
# Only one obs per sub → no sub-level random eff

library(lme4)
library(lmerTest)
library(emmeans)
library(ggplot2)
library(dplyr)
library(readxl)

results_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
motion_xlsx <- "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"

iz_csv  <- file.path(results_dir, "integration_zone_dice60min.csv")
out_pdf <- file.path(results_dir, "integrationzone_dice60min.pdf")
out_txt <- file.path(results_dir, "lmer_integrationzone_dice60min_results.txt")

df <- read.csv(iz_csv)
df <- df |> filter(motion_group %in% c("LMA", "LMC", "HMC"))

meta <- read_excel(motion_xlsx) |>
  mutate(
    subject_id    = paste0("sub-", trimws(as.character(sub))),
    family_id     = factor(family),
    age = as.numeric(age)
  ) |>
  select(subject_id, family_id, age)

df <- df |>
  mutate(
    motion_group = factor(motion_group, levels = c("LMA", "LMC", "HMC")),
    family_id    = factor(family_id),
    subject_id   = factor(subject_id)
  ) |>
  left_join(meta, by = "subject_id", suffix = c("", ".meta")) |>
  mutate(family_id = coalesce(family_id.meta, family_id)) |>
  select(-family_id.meta)

OUTCOME <- "iz_pct_cortex_area"   # alt: "iz_area_mm2", "iz_pct_vertices"


wc <- df |> filter(network_num == 0)

cat(sprintf("N subjects = %d  (LMA=%d, LMC=%d, HMC=%d)\n",
            nrow(wc),
            sum(wc$motion_group == "LMA"),
            sum(wc$motion_group == "LMC"),
            sum(wc$motion_group == "HMC")))
cat(sprintf("Age range: %.1f – %.1f yrs  (mean %.1f)\n",
            min(wc$age, na.rm=TRUE), max(wc$age, na.rm=TRUE), mean(wc$age, na.rm=TRUE)))
m <- lmer(iz_pct_cortex_area ~ motion_group + (1 | family_id),
          data = wc, REML = TRUE)

sink(out_txt)
cat("=== Integration zone (Dice < 0.3) — WHOLE CORTEX ===\n")
cat("Model: iz_pct_cortex_area ~ motion_group + (1 | family_id)  [age dropped]\n\n")
cat(sprintf("N = %d  (LMA=%d, LMC=%d, HMC=%d)\n\n",
            nrow(wc),
            sum(wc$motion_group == "LMA"),
            sum(wc$motion_group == "LMC"),
            sum(wc$motion_group == "HMC")))

cat("\n--- Model summary ---\n");                print(summary(m))
cat("\n--- ANOVA (Satterthwaite) ---\n");        print(anova(m))

# motion_group marginal means and pairwise contrasts
emm_mg <- emmeans(m, ~ motion_group)
cat("\n--- EMM: motion_group ---\n");         print(emm_mg)
cat("\n--- Pairwise motion_group (FDR) ---\n"); print(contrast(emm_mg, "pairwise", adjust = "fdr"))

cat("\n\n=== Per-network LMMs (motion_group only, FDR across networks) ===\n")
per_net <- df |> filter(network_num > 0)

net_summary <- per_net |>
  group_by(network_num, network_name) |>
  group_modify(function(d, key) {
    fit <- try(lmer(iz_pct_cortex_area ~ motion_group + (1 | family_id),
                    data = d, REML = TRUE), silent = TRUE)
    if (inherits(fit, "try-error")) {
      return(tibble(p_motion_group = NA_real_))
    }
    av <- as.data.frame(anova(fit))
    tibble(
      p_motion_group = av["motion_group", "Pr(>F)"]
    )
  }) |>
  ungroup() |>
  mutate(
    p_motion_group_FDR = p.adjust(p_motion_group, method = "BH")
  ) |>
  arrange(p_motion_group_FDR)

cat("\nPer-network motion_group p-values (FDR-corrected):\n")
print(as.data.frame(net_summary), row.names = FALSE)

sink()
cat("Results written to", out_txt, "\n")

write.csv(net_summary,
          file.path(results_dir, "integrationzone_pernetwork_stats.csv"),
          row.names = FALSE)

# PLOT 
pal    <- c("LMA" = "#0072B2", "LMC" = "#E69F00", "HMC" = "#CC79A7")
shapes <- c("LMA" = 21,        "LMC" = 24,         "HMC" = 22)
labels <- c("LMA" = "Low-Motion Adults (LMA)",
            "LMC" = "Low-Motion Children (LMC)",
            "HMC" = "High-Motion Children (HMC)")

group_means <- wc |>
  group_by(motion_group) |>
  summarise(
    mean_iz = mean(.data[[OUTCOME]], na.rm = TRUE),
    se_iz   = sd(.data[[OUTCOME]],   na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  )

y_lab <- switch(OUTCOME,
  "iz_area_mm2"        = "Integration zone area (mm²)",
  "iz_pct_cortex_area" = "Integration zone (% SA)",
  "iz_pct_vertices"    = "Integration zone (% vertices)",
  OUTCOME)

p <- ggplot() +
  geom_jitter(
    data = wc,
    aes(x = motion_group, y = .data[[OUTCOME]],
        fill = motion_group, colour = motion_group, shape = motion_group),
    width = 0.15, alpha = 0.55, size = 1.6, stroke = 0.3
  ) +
  geom_point(
    data = group_means,
    aes(x = motion_group, y = mean_iz,
        fill = motion_group, shape = motion_group),
    colour = "black", size = 4, stroke = 0.6
  ) +
  scale_colour_manual(values = pal, name = NULL, labels = labels) +
  scale_fill_manual(  values = pal, name = NULL, labels = labels) +
  scale_shape_manual( values = shapes, name = NULL, labels = labels) +
  labs(x = NULL, y = y_lab) +
  theme_classic(base_size = 9) +
  theme(
    legend.position    = "bottom",
    legend.direction   = "vertical",
    plot.title         = element_text(size = 9, face = "plain"),
    axis.text          = element_text(colour = "black"),
    axis.title         = element_text(colour = "black"),
    axis.line          = element_line(colour = "black"),
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.4)
  )

pdf(out_pdf, width = 4.2, height = 4.5)
print(p)
dev.off()
cat("Plot saved to", out_pdf, "\n")