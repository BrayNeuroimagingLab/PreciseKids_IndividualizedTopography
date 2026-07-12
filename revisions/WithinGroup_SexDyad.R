# WithinGroup_SexDyad.R
# Recoding SameSex (binary) to now ->> SexDyad (MM / FF / MF)
# Redo stats for Within_LMAMC_DiceSimilarity.R (Figure 7) 

library(ciftiTools)
library(dplyr)
library(lme4)
library(lmerTest)
library(readr)
library(purrr)
library(broom.mixed)
library(emmeans)

ciftiTools.setOption("wb_path", "/Applications/workbench/bin_macosx64/wb_command")

base_path <- "/Users/shefalirai/Downloads/HCPOverlap_Sample1/"
meta_path <- "/Users/shefalirai/Downloads/FC_Vertex_Connectomes/prckids-task_beh.csv"
out_dir   <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"

task           <- "alltasks"
network_nums   <- c(1, 2, 3, 5, 7, 8, 9, 10, 11, 12, 16)
network_labels <- c("DMN","VIS","FP","DAN","VAN","SAL","CON","SMd","SMl","AUD","PON")
desired_order  <- c("DMN","FP","DAN","VAN","SAL","CON","AUD","SMd","SMl","VIS","PON")

# LMA and LMC 
adult_nums <- c(2:16, 18:21, 23:26)
child_nums <- c(2, 5, 7, 9, 15, 18, 21, 23, 25, 26)

adult_ids <- sprintf("sub-19730%02dP", adult_nums)
child_ids <- sprintf("sub-19730%02dC", child_nums)
all_ids   <- c(adult_ids, child_ids)

meta <- read_csv(meta_path, show_col_types = FALSE) %>%
  rename(Subject = sub) %>%
  distinct(Subject, sex)

load_map <- function(subj) {
  f <- file.path(base_path, paste0(subj, "_", task, "_HCPAdultChild_overlap_sample1_Dice.dscalar.nii"))
  if (!file.exists(f)) return(NULL)
  d <- read_cifti(f)$data
  c(as.numeric(d$cortex_left), as.numeric(d$cortex_right))
}

subject_maps <- list()
for (subj in all_ids) {
  m <- load_map(subj)
  if (!is.null(m)) subject_maps[[subj]] <- m
}

compute_dice <- function(subj1, subj2, group_type) {
  if (!(subj1 %in% names(subject_maps)) || !(subj2 %in% names(subject_maps))) return(NULL)
  map1 <- subject_maps[[subj1]]
  map2 <- subject_maps[[subj2]]
  lapply(network_nums, function(net) {
    b1 <- map1 == net
    b2 <- map2 == net
    dval <- if ((sum(b1) + sum(b2)) > 0) 2 * sum(b1 & b2) / (sum(b1) + sum(b2)) else NA
    data.frame(Subject1 = subj1, Subject2 = subj2, GroupType = group_type, Network = net, Dice = dval)
  }) %>% do.call(rbind, .)
}

# sibs exckude
excluded_pairs <- list(c("sub-1973005C","sub-1973006C"), c("sub-1973007C","sub-1973010C"))
is_excluded <- function(pair) {
  any(sapply(excluded_pairs, function(ex) all(sort(pair) == sort(ex))))
}

child_pairs <- Filter(function(p) !is_excluded(p), combn(child_ids, 2, simplify = FALSE))
adult_pairs <- combn(adult_ids, 2, simplify = FALSE)

full_results <- bind_rows(
  map_dfr(child_pairs, ~ compute_dice(.x[1], .x[2], "Child-Child")),
  map_dfr(adult_pairs, ~ compute_dice(.x[1], .x[2], "Adult-Adult"))
)

full_results$NetworkLabel <- factor(
  network_labels[match(full_results$Network, network_nums)],
  levels = desired_order
)
full_results$GroupType <- factor(full_results$GroupType, levels = c("Child-Child","Adult-Adult"))


full_results <- full_results %>%
  mutate(subj1_clean = sub("^sub-", "", Subject1),
         subj2_clean = sub("^sub-", "", Subject2)) %>%
  left_join(meta %>% rename(sex1 = sex), by = c("subj1_clean" = "Subject")) %>%
  left_join(meta %>% rename(sex2 = sex), by = c("subj2_clean" = "Subject")) %>%
  mutate(
    SameSex = ifelse(sex1 == sex2, "Same", "Different"),
    SexDyad = case_when(
      sex1 == "M" & sex2 == "M" ~ "MM",
      sex1 == "F" & sex2 == "F" ~ "FF",
      TRUE ~ "MF"
    ),
    SexDyad = factor(SexDyad, levels = c("MF","FF","MM"))  # MF as ref...
  ) %>%
  select(-subj1_clean, -subj2_clean, -sex1, -sex2)

dat <- full_results %>% filter(!is.na(Dice))

# original binary model
model_binary <- lmer(Dice ~ GroupType + NetworkLabel + GroupType:NetworkLabel + SameSex +
                       (1|Subject1) + (1|Subject2), data = dat)

# new 3-category model
model_dyad <- lmer(Dice ~ GroupType + NetworkLabel + GroupType:NetworkLabel + SexDyad +
                     (1|Subject1) + (1|Subject2), data = dat)

# overall effects comparison
overall_binary <- broom.mixed::tidy(model_binary) %>%
  filter(term %in% c("GroupTypeAdult-Adult","SameSexSame")) %>%
  select(term, estimate, std.error, statistic, p.value)


overall_dyad <- broom.mixed::tidy(model_dyad) %>%
  filter(term %in% c("GroupTypeAdult-Adult","SexDyadFF","SexDyadMM")) %>%
  select(term, estimate, std.error, statistic, p.value)


# per-network GroupType post-hoc (Child-Child vs Adult-Adult) — confirms main finding unchanged
emm_group <- emmeans(model_dyad, ~ GroupType | NetworkLabel)
ph_group  <- contrast(emm_group, method = "pairwise", adjust = "fdr") %>%
  as.data.frame() %>%
  mutate(
    NetworkLabel = as.character(NetworkLabel),
    sig = case_when(p.value < 0.001 ~ "***", p.value < 0.01 ~ "**",
                    p.value < 0.05  ~ "*",  TRUE ~ "ns")
  ) %>%
  select(NetworkLabel, contrast, estimate, SE, z.ratio, p.value, sig) %>%
  mutate(NetworkLabel = factor(NetworkLabel, levels = desired_order)) %>%
  arrange(NetworkLabel)


# per-network SexDyad post-hoc (MM vs MF, FF vs MF) 
emm_sex <- emmeans(model_dyad, ~ SexDyad | NetworkLabel)
ph_sex  <- contrast(emm_sex, method = "pairwise", adjust = "fdr") %>%
  as.data.frame() %>%
  mutate(
    NetworkLabel = as.character(NetworkLabel),
    sig = case_when(p.value < 0.001 ~ "***", p.value < 0.01 ~ "**",
                    p.value < 0.05  ~ "*",  TRUE ~ "ns")
  ) %>%
  select(NetworkLabel, contrast, estimate, SE, z.ratio, p.value, sig) %>%
  mutate(NetworkLabel = factor(NetworkLabel, levels = desired_order)) %>%
  arrange(NetworkLabel, contrast)


# SexDyad anova
library(car)
anova_dyad <- car::Anova(model_dyad, type = 3)
print(anova_dyad)

summary(model_dyad)

write.csv(ph_group, file.path(out_dir, "WithinGroup_GroupType_DyadModel.csv"), row.names = FALSE)
write.csv(ph_sex,   file.path(out_dir, "WithinGroup_SexDyad_PerNetwork.csv"),  row.names = FALSE)
