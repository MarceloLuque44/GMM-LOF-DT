#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages(library(data.table))

args_full <- commandArgs(trailingOnly = FALSE)
args <- commandArgs(trailingOnly = TRUE)

ruta_script <- function() {
  archivo <- sub("^--file=", "", grep("^--file=", args_full, value = TRUE))
  if (length(archivo)) dirname(normalizePath(archivo[1], mustWork = FALSE)) else getwd()
}

dir_r <- ruta_script()
ruta_csv <- file.path(dir_r, "ECE_1T2026.csv")
variables_analisis <- c("yprilab", "phrs", "s1_03a", "aestudio", "tothrs", "ylab")

solo_api <- "--solo-api" %in% args
solo_perfilado <- "--solo-perfilado" %in% args
if (solo_api && solo_perfilado) {
  stop("Use solo uno de estos argumentos: --solo-api o --solo-perfilado.", call. = FALSE)
}

if (!file.exists(ruta_csv)) {
  stop("No se encontró el archivo CSV: ", ruta_csv, call. = FALSE)
}

datos_analisis <- fread(
  ruta_csv,
  sep = ";",
  dec = ",",
  na.strings = c("", "NA", "N/A"),
  select = variables_analisis,
  encoding = "UTF-8",
  showProgress = FALSE,
  check.names = FALSE
)

# parse() evita problemas de source() con UTF-8 en algunas instalaciones de R
# para Windows cuya configuración regional no reconoce C.UTF-8.
eval(parse(file = file.path(dir_r, "perfilado_inicial.R")), envir = environment())

# 1. Genera el perfil, los gráficos y el reporte. Se omite con --solo-api.
if (!solo_api) {
  ejecutar_perfilado_inicial(datos_analisis)
}

# 2. Envía el perfil guardado a la API sin regenerar gráficos.
#    Puede ejecutarse por separado con: Rscript apps/R/inicio.R --solo-api
if (!solo_perfilado) {
  enviar_resultados_perfilado_api(datos_analisis)
}
