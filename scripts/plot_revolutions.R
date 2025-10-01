rm(list = ls())

library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(optparse)
library(tidyr)


# Opciones de línea de comandos
option_list <- list(
  make_option(c("--start"), type = "character", default = NULL,
              help = "Initial Date/time of the graph in format dd/mm/yyyy HH:MM:SS",
              metavar = "DATETIME"),
  make_option(c("--end"), type = "character", default = NULL,
              help = "Last Date/time of the graphin format dd/mm/yyyy HH:MM:SS",
              metavar = "DATETIME"),
  make_option(c("--group1"), type = "character", default = NULL,
              help = "Columns for group 1 (mouse1, mouse2, etc.)"),
  make_option(c("--group2"), type = "character", default = NULL,
              help = "Columns for group 2 (mouse3, mouse4, etc.)")
)

opt_parser <- OptionParser(
  option_list = option_list,
  usage = "Usage: %prog [options]",
  description = "Script to plot the revolutions (hourly).
Date/time should be indicated as dd/mm/yyyy HH:MM:SS.
Use the column names to define each group."
)

opt <- parse_args(opt_parser)


# Leer datos procesados
data <- read_csv("output/processed/revolutions_hourly.csv")

# Filtrar filas con Datetime NA (por seguridad)
data <- data %>% filter(!is.na(Datetime))

# -----------------------------
# Aplicar filtros de fecha si se proporcionan
# -----------------------------
if (!is.null(opt$start)) {
  fecha_inicio <- dmy_hms(opt$start, tz = "UTC")
  if (is.na(fecha_inicio)) stop("No se pudo parsear la fecha de inicio: ", opt$start)
  cat("Filtrando desde:", fecha_inicio, "\n")
  data <- data %>% filter(Datetime >= fecha_inicio)
}

if (!is.null(opt$end)) {
  fecha_fin <- dmy_hms(opt$end, tz = "UTC")
  if (is.na(fecha_fin)) stop("No se pudo parsear la fecha de fin: ", opt$end)
  cat("Filtrando hasta:", fecha_fin, "\n")
  data <- data %>% filter(Datetime <= fecha_fin)
}

if (nrow(data) == 0) stop("No hay datos después de aplicar filtros de fecha.")


# Procesar grupos personalizados

if (!is.null(opt$group1) || !is.null(opt$group2)) {
  # Si se especifican grupos personalizados
  data_long <- data %>%
    select(Datetime, Period, Revolutions) %>%
    filter(!is.na(Revolutions))
  
  # Crear lista de grupos
  grupos <- list()
  if (!is.null(opt$group1)) {
    cols_group1 <- strsplit(opt$group1, ",")[[1]]
    cols_group1 <- trimws(cols_group1)  # Eliminar espacios
    cat("Group 1:", paste(cols_group1, collapse = ", "), "\n")
    grupos[["Group 1"]] <- cols_grupo1
  }
  
  if (!is.null(opt$group2)) {
    cols_group2 <- strsplit(opt$group2, ",")[[1]]
    cols_group2 <- trimws(cols_group2)  # Eliminar espacios
    cat("Group 2:", paste(cols_group2, collapse = ", "), "\n")
    grupos[["Group 2"]] <- cols_grupo2
  }
  
  # Verificar que las columnas existen en el CSV original
  data_raw <- read_csv("output/processed/revolutions_hourly.csv")
  todas_columnas <- names(data_raw)
  
  # Reestructurar datos con los grupos especificados
  data_list <- list()
  
  for (grupo_nombre in names(grupos)) {
    columnas <- grupos[[grupo_nombre]]
    
    # Verificar que todas las columnas existen
    columnas_faltantes <- columnas[!columnas %in% todas_columnas]
    if (length(columnas_faltantes) > 0) {
      stop("Columnas no encontradas en el CSV: ", paste(columnas_faltantes, collapse = ", "))
    }
    
    # Seleccionar y transformar datos para este grupo
    temp_data <- data_raw %>%
      filter(Datetime >= min(data$Datetime) & Datetime <= max(data$Datetime)) %>%
      select(Datetime, all_of(columnas)) %>%
      pivot_longer(cols = all_of(columnas), 
                   names_to = "Mouse", 
                   values_to = "Revolutions") %>%
      mutate(Period = grupo_nombre)
    
    data_list[[grupo_nombre]] <- temp_data
  }
  
  # Combinar todos los grupos
  data <- bind_rows(data_list)
}


# -----------------------------
# Calcular estadísticos
# -----------------------------
stats_data <- data %>%
  group_by(Datetime, Period) %>%
  summarise(
    mean_rev = mean(Revolutions, na.rm = TRUE),
    sd_rev   = sd(Revolutions, na.rm = TRUE),
    n_rev    = sum(!is.na(Revolutions)),
    sem_rev  = sd_rev / sqrt(n_rev),
    .groups = "drop"
  )

# Calcular horas desde el inicio
tiempo_inicio <- min(stats_data$Datetime)
stats_data <- stats_data %>%
  mutate(hours_from_start = as.numeric(difftime(Datetime, tiempo_inicio, 
                                                units = "hours")))


# Grafica
p <- ggplot(stats_data, aes(x = hours_from_start, y = mean_rev, color = Period, fill = Period)) +
  geom_line(linewidth = 1) +
  geom_ribbon(aes(ymin = mean_rev - sem_rev, ymax = mean_rev + sem_rev), alpha = 0.2, color = NA) +
  labs(
    title = "Voluntary activity",
    x = "Time (hours)",
    y = "Revolutions (no.)"
  ) +
  theme_bw() +
  theme(
    legend.position = "inside",
    legend.position.inside = c(0.10, 0.80),
    legend.background = element_rect(fill = "transparent", color = NA),
    legend.key = element_rect(fill = "transparent", color = NA),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.title = element_text(face = "bold"),
    plot.title = element_text(hjust = 0.5, face = "bold"), 
    axis.title.x = element_text(margin = margin(t = 10)),
    axis.title.y = element_text(margin = margin(r = 10)), 
    axis.line = element_line(color = "black"),
    panel.border = element_rect(color = "black", fill = NA, linewidth = 1),
    panel.background = element_blank()
  ) +
  scale_x_continuous(limits = c(0,48), breaks = seq(0, 48, by = 6))

p

# -----------------------------
# Guardar gráfico
# -----------------------------
ggsave("output/plots/revolutions_plot.png", p, width = 10, height = 6)
cat("Plot saved at en output/plots/revolutions_plot.png\n")
