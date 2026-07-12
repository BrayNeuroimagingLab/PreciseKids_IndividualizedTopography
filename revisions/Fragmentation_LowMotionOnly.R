# Network fragmentation (cluster count) in low-motion subjects only: LMC vs LMA

library(dplyr)
library(readxl)
library(lme4)
library(lmerTest)
library(emmeans)

out_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
df <- read.csv(paste0(out_dir, "NetworkFragmentation_9vs60min_LONG.csv"))

lmc <- paste0("sub-1973", sprintf("%03d", c(2, 5, 7, 9, 15, 18, 21, 23, 25, 26)), "C")
lma <- paste0("sub-1973", sprintf("%03d", c(2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 24, 25, 26)), "P")

fam <- read_excel("/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx") %>%
  transmute(Subject = paste0("sub-", trimws(as.character(sub))), Family = factor(family))

df <- df %>%
  filter(Subject %in% c(lmc, lma)) %>%
  left_join(fam, by = "Subject") %>%
  mutate(MG = ifelse(Subject %in% lmc, "LMC", "LMA"),
         DataLength = factor(DataLength, levels = c("60min", "9min")),
         Group = factor(MG, levels = c("LMA", "LMC")),
         Network = factor(Network), Subject = factor(Subject))

cat("N: LMC =", length(unique(df$Subject[df$MG == "LMC"])), " LMA =", length(unique(df$Subject[df$MG == "LMA"])), "\n\n")

mod <- lmer(n_clusters_ge15 ~ DataLength * Group + Network + (1 | Family) + (1 | Subject), data = df)

cat("===== low-motion only: n_clusters_ge15 ~ DataLength*Group + Network + (1|Family) + (1|Subject) =====\n")
print(round(summary(mod)$coefficients[c("DataLength9min", "GroupLMC", "DataLength9min:GroupLMC"), ], 5))
cat("\n--- ANOVA ---\n")
print(anova(mod)[c("DataLength", "Group", "DataLength:Group"), ])
cat("\n--- Estimated marginal means ---\n")
print(as.data.frame(emmeans(mod, ~ DataLength | Group)))

sink(paste0(out_dir, "Fragmentation_LowMotionOnly_results.txt"))
print(summary(mod))
cat("\n")
print(anova(mod))
cat("\n")
print(as.data.frame(emmeans(mod, ~ DataLength | Group)))
sink()
