# Mean entropy with and without a reliability covariate (connectome reliability), by data length

library(dplyr)
library(lme4)
library(lmerTest)
library(car)

out_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
df <- read.csv(paste0(out_dir, "Entropy_Reliability_covariate_table.csv")) %>%
  mutate(group = factor(ifelse(group == "C", "Child", "Adult"), levels = c("Adult", "Child")),
         sex = factor(sex), family = factor(family),
         motion_z = as.numeric(scale(censored_volumes)),
         reliab_z = as.numeric(scale(reliability_30min)))

run <- function(ycol, label) {
  df$y <- df[[ycol]]
  m0 <- lmer(y ~ group + sex + motion_z + (1 | family), data = df)
  m1 <- lmer(y ~ group + sex + motion_z + reliab_z + (1 | family), data = df)
  cat(sprintf("\n===== %s =====\n", label))
  cat("-- without reliability --\n")
  print(round(summary(m0)$coefficients["groupChild", ], 5))
  cat("-- with reliability --\n")
  print(round(summary(m1)$coefficients[c("groupChild", "reliab_z"), ], 5))
  cat("VIF (with-reliability model):\n")
  print(round(vif(m1), 2))
}

run("mean_entropy_60min", "60-min entropy: group effect with/without reliability")
run("mean_entropy_9min", "9-min entropy: group effect with/without reliability")
