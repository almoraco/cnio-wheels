# scripts/analysis.R
rm(list = ls())

library(ggplot2)
library(dplyr)
library(readr)

# Leer datos procesados
df <- read_csv("output/processed/revolutions_hourly.csv")

# Calcular estadísticos (ejemplo: media por hora, periodo y grupo de ratones)
summary_df <- df %>%
  group_by(Datetime, Period) %>%
  summarise(
    mean_rev = mean(Revolutions, na.rm = TRUE),
    sd_rev   = sd(Revolutions, na.rm = TRUE),
    .groups = "drop"
  )

# Graficar
p <- ggplot(summary_df, aes(x = Datetime, y = mean_rev, color = Period, fill = Period)) +
  geom_line(size = 1) +
  geom_ribbon(aes(ymin = mean_rev - sd_rev, ymax = mean_rev + sd_rev), alpha = 0.2, color = NA) +
  labs(
    title = "Actividad en rueda por intervalos horarios",
    x = "Hora",
    y = "Revoluciones (media ± SD)"
  ) +
  theme_minimal()

# Guardar
ggsave("output/revolutions_plot.png", p, width = 10, height = 6)


