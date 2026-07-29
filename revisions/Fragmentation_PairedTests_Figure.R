# Fragmentation_PairedTests_Figure.R
# Number of network fragments (>= 15 mm2) at 9 vs 60 minutes, per network.
# Linear mixed model per network with FDR correction across the 11 networks:
#   fragments ~ data length + sex + head motion + (1 | family) + (1 | subject)

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)
library(readxl)
library(lme4)
library(lmerTest)
library(broom.mixed)

res_dir <- "/Users/shefalirai/Desktop/Paper3/JNeuroSci_Revisions/JNeuroSci_RevisionsResults/"
motion_path <- "/Users/shefalirai/Desktop/Paper3/prckids-motion_beh.xlsx"
frag <- read_csv(file.path(res_dir, "NetworkFragmentation_9vs60min_LONG.csv"), show_col_types = FALSE)

desired_order <- c("DMN", "FP", "DAN", "VAN", "SAL", "CON", "AUD", "SMd", "SMl", "VIS", "PON")

# head motion = number of censored volumes as usual
motion <- read_excel(motion_path) %>%
  transmute(Subject = paste0("sub-", trimws(as.character(sub))),
            Motion = as.numeric(censored_volumes),
            Sex = factor(sex),
            Family = factor(family))

dat <- frag %>%
  left_join(motion, by = "Subject") %>%
  filter(Network %in% desired_order) %>%
  mutate(DataLength = factor(DataLength, levels = c("9min", "60min")))

# one row per subject x network, used for the means and the rank correlation
wide <- frag %>%
  select(Subject, Group, Network, DataLength, n_clusters_ge15) %>%
  pivot_wider(names_from = DataLength, values_from = n_clusters_ge15) %>%
  filter(Network %in% desired_order)

# mixed model per network, then FDR across the 11 networks
fit_network <- function(net) {
  m <- lmer(n_clusters_ge15 ~ DataLength + Sex + Motion + (1 | Family) + (1 | Subject),
            data = filter(dat, Network == net))
  tidy(m) %>%
    filter(term == "DataLength60min") %>%
    transmute(Network = net, est = estimate, t = statistic, p_raw = p.value)
}

descriptives <- wide %>%
  group_by(Network) %>%
  summarise(mean_9 = mean(`9min`),
            mean_60 = mean(`60min`),
            delta = mean(`9min` - `60min`),
            dz = mean(`9min` - `60min`) / sd(`9min` - `60min`),
            rho = cor(`9min`, `60min`, method = "spearman"),
            .groups = "drop")

stats_net <- lapply(desired_order, fit_network) %>%
  bind_rows() %>%
  left_join(descriptives, by = "Network") %>%
  mutate(p_fdr = p.adjust(p_raw, method = "BH"),
         Stars = cut(p_fdr, c(-Inf, .001, .01, .05, Inf), c("***", "**", "*", "")),
         Network = factor(Network, levels = desired_order)) %>%
  select(Network, mean_9, mean_60, delta, t, p_raw, p_fdr, Stars, dz, rho)

print(as.data.frame(stats_net), digits = 3, row.names = FALSE)
cat(sprintf("\nAll networks significant after FDR: %s\n", all(stats_net$p_fdr < 0.05)))
cat(sprintf("Rank stability across subjects: mean rho = %.2f (range %.2f - %.2f)\n",
            mean(stats_net$rho), min(stats_net$rho), max(stats_net$rho)))
write_csv(stats_net, file.path(res_dir, "Fragmentation_PairedTests_byNetwork.csv"))

# child vs adult at each data length, averaged across networks
per_sub <- wide %>%
  group_by(Subject, Group) %>%
  summarise(across(c(`9min`, `60min`), mean), .groups = "drop") %>%
  mutate(reduction = `9min` - `60min`)

for (len in c("9min", "60min")) {
  tt <- t.test(per_sub[[len]] ~ per_sub$Group)
  cat(sprintf("%s: child = %.1f, adult = %.1f, t = %.2f, p = %.3f\n", len,
              mean(per_sub[[len]][per_sub$Group == "Child"]),
              mean(per_sub[[len]][per_sub$Group == "Adult"]),
              tt$statistic, tt$p.value))
}
tt_int <- t.test(reduction ~ Group, data = per_sub)
cat(sprintf("reduction 9->60: child = %.1f, adult = %.1f, t = %.2f, p = %.3f\n",
            mean(per_sub$reduction[per_sub$Group == "Child"]),
            mean(per_sub$reduction[per_sub$Group == "Adult"]),
            tt_int$statistic, tt_int$p.value))

# DUMBBELL PLOTTING part
plot_dat <- stats_net %>%
  select(Network, mean_9, mean_60, Stars) %>%
  mutate(Network = factor(Network, levels = rev(desired_order)))
long_dat <- plot_dat %>%
  pivot_longer(c(mean_9, mean_60), names_to = "DataLength", values_to = "Fragments") %>%
  mutate(DataLength = factor(ifelse(DataLength == "mean_9", "9 min", "60 min"),
                             levels = c("9 min", "60 min")))

custom_colors <- c("9 min" = "#9d5737", "60 min" = "#503e6b")

# numeric y positions so individual participants can be jittered within each network band
y_levels <- rev(desired_order)
ypos <- setNames(seq_along(y_levels), y_levels)

set.seed(42)
indiv <- wide %>%
  mutate(y_jit = ypos[Network] + runif(n(), -0.26, 0.26))
plot_dat <- plot_dat %>% mutate(y = ypos[as.character(Network)])
long_dat <- long_dat %>% mutate(y = ypos[as.character(Network)])

ggplot() +
  geom_segment(data = indiv, aes(x = `9min`, xend = `60min`, y = y_jit, yend = y_jit),
               color = "grey60", linewidth = 0.25, alpha = 0.4) +
  geom_point(data = indiv, aes(x = `9min`, y = y_jit), color = "#8F2E07",
             size = 0.6, alpha = 0.45) +
  geom_point(data = indiv, aes(x = `60min`, y = y_jit), color = "#351A57",
             size = 0.6, alpha = 0.45) +
  geom_segment(data = plot_dat, aes(x = mean_60, xend = mean_9, y = y, yend = y),
               color = "black", linewidth = 1.1) +
  geom_point(data = long_dat, aes(x = Fragments, y = y, fill = DataLength),
             size = 3.2, shape = 21, color = "black", stroke = 0.6) +
  geom_text(data = plot_dat, aes(x = mean_9 + 4, y = y, label = Stars),
            size = 3, hjust = 0, color = "black") +
  scale_fill_manual(values = custom_colors) +
  scale_y_continuous(breaks = seq_along(y_levels), labels = y_levels,
                     expand = expansion(add = 0.6)) +
  scale_x_continuous(limits = c(0, NA), expand = expansion(mult = c(0.02, 0.12))) +
  labs(x = "Number of network fragments", y = "Network") +
  theme_classic(base_size = 9) +
  theme(
    axis.line          = element_line(color = "black", linewidth = 0.4),
    panel.grid         = element_blank(),
    panel.grid.major.x = element_line(color = "grey92", linewidth = 0.3),
    axis.title         = element_text(size = 9, color = "black"),
    axis.text          = element_text(size = 8, color = "black"),
    legend.position    = "bottom",
    legend.title       = element_blank(),
    legend.text        = element_text(size = 7.5, color = "black"),
    legend.key.size    = unit(0.9, "lines"),
    legend.key         = element_blank(),
    legend.background  = element_blank()
  )

ggsave(file.path(res_dir, "Fragmentation_9vs60_byNetwork.svg"), width = 6.5, height = 5.5, units = "in")
