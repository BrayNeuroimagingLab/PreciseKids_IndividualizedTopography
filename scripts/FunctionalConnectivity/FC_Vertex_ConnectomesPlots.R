library(ggplot2)
library(dplyr)
library(tidyr)

rm(list = ls())

# FC table data
df <- read.csv("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/fc_long_table.csv") %>%
  filter(grepl("^N\\d+_N\\d+$", Pair)) %>%
  mutate(
    NetA = as.integer(sub("N(\\d+)_N(\\d+)", "\\1", Pair)),
    NetB = as.integer(sub("N(\\d+)_N(\\d+)", "\\2", Pair)),
    NetType = ifelse(NetA == NetB, "Within", "Between")
  )

# Get all between and within mutated 
df_between <- df %>%
  filter(NetType == "Between") %>%
  pivot_longer(cols = c(NetA, NetB), names_to = NULL, values_to = "NetInvolved") %>%
  mutate(
    NetInvolved = factor(NetInvolved, levels = 1:12),
    NetType = "Between"
  )


df_within <- df %>%
  filter(NetType == "Within") %>%
  mutate(NetInvolved = factor(NetA, levels = 1:12))

#Combine
df_all <- bind_rows(df_within, df_between)

# Plot
network_labels <- c(
  "1" = "DMN", "2" = "VIS", "3" = "FP", 
  "5" = "DAN", "7" = "VAN", "8" = "SAL", 
  "9" = "CON", "10" = "SMd", "11" = "SML", "12" = "AUD"
)

df_all_filtered <- df_all %>%
  filter(!NetInvolved %in% c("4", "6")) %>%
  mutate(NetLabel = factor(network_labels[as.character(NetInvolved)],
                           levels = network_labels))

ggplot(df_all_filtered, aes(x = NetLabel, y = FCValue, fill = NetType)) +
  geom_boxplot(outlier.shape = NA, alpha = 0.6,
               position = position_dodge(width = 0.8)) +
  scale_x_discrete(drop = FALSE) +
  facet_wrap(~ Method, ncol = 1) +
  scale_fill_manual(values = c("Within" = "#7570b3", "Between" = "#e6ab23")) +
  labs(x = "Network", y = "FC", fill = "Type") +
  theme_minimal() +
  theme(
    text = element_text(family = "Arial", size = 30, color = "black"),
    legend.position = "bottom",
    legend.box = "vertical",
    legend.margin = margin(t = 0, b = 0),
    legend.box.margin = margin(0, 0, 10, 0),
    legend.spacing.y = unit(0.2, "cm"),
    legend.title = element_text(size = 28),
    legend.text = element_text(size = 28),
    axis.text.x = element_text(size = 28, angle = 45, hjust = 1, color = "black"),
    axis.text.y = element_text(size = 28, color = "black"),
    axis.title = element_text(size = 32),
    plot.title = element_text(hjust = 0.5, face = "bold"),
    panel.grid = element_blank(),
    axis.line = element_line(color = "black"),
    plot.margin = margin(t = 30, r = 30, b = 40, l = 30, unit = "pt")
  )



# Save
ggsave("/Users/shefalirai/Downloads/FC_Vertex_Connectomes/FC_vertexwise_betweenwithin.png", width = 20, height = 12, dpi = 1000)


