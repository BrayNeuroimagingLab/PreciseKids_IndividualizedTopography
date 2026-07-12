# Mixed model of network fragmentation (cluster count) by data length and age group

library(dplyr)
library(readxl)
library(lme4)
library(lmerTest)
library(emmeans)

out_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
df <- read.csv(paste0(out_dir, "NetworkFragmentation_9vs60min_LONG.csv"))

fam <- read_excel("/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx") %>%
  transmute(Subject = paste0("sub-", trimws(as.character(sub))), Family = factor(family))

df <- df %>%
  left_join(fam, by = "Subject") %>%
  mutate(DataLength = factor(DataLength, levels = c("60min", "9min")),  # 60min = reference
         Group = factor(Group, levels = c("Adult", "Child")),  # Adult = reference
         Network = factor(Network), Subject = factor(Subject))

mod <- lmer(n_clusters_ge15 ~ DataLength * Group + Network + (1 | Family) + (1 | Subject), data = df)

cat("===== n_clusters_ge15 ~ DataLength*Group + Network + (1|Family) + (1|Subject) =====\n")
print(summary(mod)$coefficients[c("DataLength9min", "GroupChild", "DataLength9min:GroupChild"), ])
cat("\n--- Type III ANOVA ---\n")
print(anova(mod)[c("DataLength", "Group", "DataLength:Group"), ])
cat("\n--- Estimated marginal means ---\n")
print(as.data.frame(emmeans(mod, ~ DataLength | Group)))

sink(paste0(out_dir, "Fragmentation_MixedModel_results.txt"))
print(summary(mod))
cat("\n")
print(anova(mod))
cat("\n")
print(as.data.frame(emmeans(mod, ~ DataLength | Group)))
sink()
cat("\nSaved: Fragmentation_MixedModel_results.txt\n")
