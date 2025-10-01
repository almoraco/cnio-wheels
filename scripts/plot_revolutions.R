rm(list = ls())

library(ggplot2)
library(dplyr)
library(readr)
library(lubridate)
library(optparse)
library(tidyr)
library(grid) # para poner dos colores en el fondo del gráfico


# Opciones de línea de comandos
option_list <- list(
  make_option(c("--start"), type = "character", default = NULL,
              help = "Initial Date/time of the graph in format dd/mm/yyyy HH:MM:SS",
              metavar = "DATETIME"),
  make_option(c("--end"), type = "character", default = NULL,
              help = "Last Date/time of the graph in format dd/mm/yyyy HH:MM:SS",
              metavar = "DATETIME"),
  make_option(c("--group1"), type = "character", default = NULL,
              help = "Mice for group 1 (mouse1,mouse2,etc.)"),
  make_option(c("--group2"), type = "character", default = NULL,
              help = "Mice for group 2 (mouse3,mouse4,etc.)")
)

opt_parser <- OptionParser(
  option_list = option_list,
  usage = "Usage: %prog [options]",
  description = "Script to plot the revolutions (hourly).
Date/time should be indicated as dd/mm/yyyy HH:MM:SS.
Mice names should be separated by commas WITHOUT spaces."
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
  
  # Crear lista de grupos con los IDs de ratones
  grupos <- list()
  if (!is.null(opt$group1)) {
    mice_group1 <- strsplit(opt$group1, ",")[[1]]
    mice_group1 <- trimws(mice_group1)  # Eliminar espacios
    cat("Group 1:", paste(mice_group1, collapse = ", "), "\n")
    grupos[["Group 1"]] <- mice_group1
  }
  
  if (!is.null(opt$group2)) {
    mice_group2 <- strsplit(opt$group2, ",")[[1]]
    mice_group2 <- trimws(mice_group2)  # Eliminar espacios
    cat("Group 2:", paste(mice_group2, collapse = ", "), "\n")
    grupos[["Group 2"]] <- mice_group2
  }
  
  # Verificar que los MouseID existen en los datos
  todos_ratones <- unique(data$MouseID)
  
  # Asignar grupo a cada ratón
  data <- data %>%
    mutate(Period = case_when(
      MouseID %in% grupos[["Group 1"]] ~ "Group 1",
      MouseID %in% grupos[["Group 2"]] ~ "Group 2",
      TRUE ~ NA_character_
    )) %>%
    filter(!is.na(Period))  # Filtrar solo los ratones en los grupos especificados
  
  # Verificar si hay ratones no encontrados
  for (grupo_nombre in names(grupos)) {
    ratones_faltantes <- grupos[[grupo_nombre]][!grupos[[grupo_nombre]] %in% todos_ratones]
    if (length(ratones_faltantes) > 0) {
      warning("Ratones no encontrados en ", grupo_nombre, ": ", 
              paste(ratones_faltantes, collapse = ", "))
    }
  }
  
  if (nrow(data) == 0) {
    stop("No se encontraron datos para los ratones especificados")
  }
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


# Definir etiquetas y colores
etiquetas_grupos <- c(
  "Group 1" = expression("control cre"^"+"),
  "Group 2" = expression("muscle-p38α"^"ko")
)

colores_personalizados <- c("Group 1" = "black",  
                            "Group 2" = "#009e73")

# Gráfica
p <- ggplot(stats_data, aes(x = hours_from_start, y = mean_rev, 
                            color = Period)) +
  # Añadir primera noche
  annotation_custom(
    grob = rectGrob(gp = gpar(fill = "grey90", col = NA)),
    xmin = 12, xmax = 24, ymin = -Inf, ymax = Inf
  ) +
  # Añadir segunda noche
  annotation_custom(
    grob = rectGrob(gp = gpar(fill = "grey90", col = NA)),
    xmin = 36, xmax = 48, ymin = -Inf, ymax = Inf
  ) +
  geom_line(linewidth = 1) +
  geom_point(na.rm = TRUE, size = 2) +
  geom_errorbar(aes(ymin = mean_rev - sem_rev, 
                    ymax = mean_rev + sem_rev), 
                width = 0.3, na.rm = TRUE) +
  #geom_ribbon(aes(ymin = mean_rev - sem_rev, ymax = mean_rev + sem_rev,
                  #fill = Period), alpha = 0.2) +
  scale_color_manual(values = colores_personalizados,
                     labels = etiquetas_grupos) +
  labs(
    title = "Voluntary activity",
    x = "Time (hours)",
    y = "Revolutions (no.)",
    color = "Genotype:"
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
  scale_x_continuous(limits = c(0,48), breaks = seq(0, 48, by = 6), 
                     expand = c(0, 0)) +
  scale_y_continuous(limits = c(0,1200), breaks = seq(0, 1200, by = 300), 
                     expand = c(0, 0))

p

# Guardar gráfico
ggsave("output/plots/revolutions_plot.png", p,
       width = 8, height = 5, dpi = 300)
cat("Plot saved at output/plots/revolutions_plot.png\n")
