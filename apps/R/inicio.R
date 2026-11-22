#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)

suppressPackageStartupMessages(library(data.table))

args_full <- commandArgs(trailingOnly = FALSE)
ruta_script <- function() {
  archivo <- sub("^--file=", "", grep("^--file=", args_full, value = TRUE))
  if (length(archivo)) dirname(normalizePath(archivo[1], mustWork = FALSE)) else getwd()
}

dir_r <- ruta_script()
dir_r <- paste(dir_r,"/apps/R",sep="")
print(dir_r)
ruta_csv <- file.path(dir_r, "ECE_1T2026.csv")
variables_analisis <- c("yprilab","phrs","s1_03a", "aestudio", "tothrs", "ylab")

if (!file.exists(ruta_csv)) {
  stop("No se encontro el archivo CSV: ", ruta_csv, call. = FALSE)
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
head(datos_analisis)
source(file.path(dir_r, "perfilado_inicial.R"))

ejecutar_perfilado_inicial(datos_analisis)
