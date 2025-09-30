# scripts/plot_revolutions.R
rm(list = ls())

library(ggplot2)
library(dplyr)
library(readr)

# Leer datos procesados
data <- read_csv("output/processed/revolutions_hourly.csv")

# Calcular estadísticos
stats_data <- data %>%
  group_by(Datetime, Period) %>%
  summarise(
    mean_rev = mean(Revolutions, na.rm = TRUE),
    sd_rev   = sd(Revolutions, na.rm = TRUE),
    n_rev    = sum(!is.na(Revolutions)),
    sem_rev  = sd_rev / sqrt(n_rev),
    .groups = "drop"
  )

# Graficar
p <- ggplot(stats_data, aes(x = Datetime, y = mean_rev, color = Period, fill = Period)) +
  geom_line(linewidth = 1) +
  geom_ribbon(aes(ymin = mean_rev - sem_rev, ymax = mean_rev + sem_rev), alpha = 0.2, color = NA) +
  labs(
    title = "Voluntary activity",
    x = "Time (hours)",
    y = "Revoluciones"
  ) +
  theme_bw() +
  theme(
    legend.position = "inside",
    legend.position.inside = c(0.20, 0.75),
    legend.background = element_rect(fill = "transparent", color = NA),
    legend.key = element_rect(fill = "transparent", color = NA),
    panel.grid.minor = element_blank(),
    axis.title = element_text(face = "bold"),
    plot.title = element_text(hjust = 0.5, face = "bold"), 
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10)), 
    axis.line = element_line(color = "black"),
    panel.border = element_blank(),
    panel.background = element_blank()
  )

# Guardar
ggsave("output/plots/revolutions_plot.png", p, width = 10, height = 6)
