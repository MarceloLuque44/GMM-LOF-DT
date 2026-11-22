#!/usr/bin/env Rscript

options(stringsAsFactors = FALSE)
Sys.setlocale("LC_CTYPE", "")

suppressPackageStartupMessages(library(data.table))

args_full <- commandArgs(trailingOnly = FALSE)
args <- commandArgs(trailingOnly = TRUE)
if (!length(args) && nzchar(Sys.getenv("GMM_HASTA_ETAPA"))) {
  args <- paste0("--hasta-", Sys.getenv("GMM_HASTA_ETAPA"))
}

ruta_script <- function() {
  archivo_source <- tryCatch(sys.frame(1)$ofile, error = function(e) NULL)
  if (!is.null(archivo_source)) return(dirname(normalizePath(archivo_source, mustWork = FALSE)))
  archivo <- sub("^--file=", "", grep("^--file=", args_full, value = TRUE))
  if (length(archivo)) return(dirname(normalizePath(archivo[1], mustWork = FALSE)))
  ruta_repo <- file.path(getwd(), "apps", "R")
  if (file.exists(file.path(ruta_repo, "ECE_1T2026.csv"))) return(ruta_repo)
  getwd()
}

dir_r <- ruta_script()
ruta_csv <- file.path(dir_r, "ECE_1T2026.csv")
variables_analisis <- c("id_persona", "yprilab", "phrs", "s1_03a", "aestudio", "tothrs", "ylab")

solo_api <- "--solo-api" %in% args
solo_perfilado <- "--solo-perfilado" %in% args
etapas <- c("02-02", "02-03", "02-04", "02-05", "02-06", "03", "04-01", "04-02", "05", "05-01")
modos_etapa <- paste0("--hasta-", etapas)
solicitadas <- intersect(args, modos_etapa)
if (length(solicitadas) + as.integer(solo_api) + as.integer(solo_perfilado) > 1L ||
    any(!args %in% c("--solo-api", "--solo-perfilado", modos_etapa))) {
  stop("Seleccione un solo modo de ejecución por vez.", call. = FALSE)
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
if (!solo_api && !length(solicitadas)) {
  ejecutar_perfilado_inicial(datos_analisis)
}

# 2. Envía el perfil guardado a la API sin regenerar gráficos.
#    Puede ejecutarse por separado con: Rscript apps/R/inicio.R --solo-api
if (!solo_perfilado && !length(solicitadas)) {
  enviar_resultados_perfilado_api(datos_analisis)
}

if (length(solicitadas)) {
  scripts <- c("02_02_normalizacion.R", "02_03_duplicados.R",
               "02_04_valores_faltantes.R", "02_05_outliers.R",
               "02_06_consistencia.R", "03_transformacion.R",
               "04_01_gmm.R", "04_02_lof.R", "05_evaluacion.R", "05_01_comparacion.R")
  ids <- c("02_02", "02_03", "02_04", "02_05", "02_06", "03", "04_01", "04_02", "05", "05_01")
  ultimo <- match(sub("^--hasta-", "", solicitadas[1]), etapas)
  actual <- datos_analisis
  for (i in seq_len(ultimo)) {
    eval(parse(file = file.path(dir_r, scripts[i])), envir = environment())
    actual <- tryCatch(
      get(paste0("etapa_", ids[i]))(actual),
      error = function(e) {
        ruta_error <- file.path(dir_r, "output", "errores_sincronizacion.csv")
        dir.create(dirname(ruta_error), recursive = TRUE, showWarnings = FALSE)
        registro <- data.table(
          fecha_hora = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
          etapa = ids[i],
          version_entrada = digest::digest(actual, algo = "sha256"),
          api = Sys.getenv("GMM_API_URL", "http://localhost:3001"),
          error = conditionMessage(e)
        )
        fwrite(registro, ruta_error, append = file.exists(ruta_error),
               col.names = !file.exists(ruta_error))
        stop(e)
      }
    )
    assign(paste0("datos_", ids[i]), actual)
  }
  tryCatch(
    api_registrar_respuestas(file.path(dir_r, "output", "respuestas_api.csv")),
    error = function(e) {
      ruta_error <- file.path(dir_r, "output", "errores_sincronizacion.csv")
      registro <- data.table(
        fecha_hora = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
        etapa = ids[ultimo], version_entrada = digest::digest(actual, algo = "sha256"),
        api = Sys.getenv("GMM_API_URL", "http://localhost:3001"),
        error = conditionMessage(e)
      )
      fwrite(registro, ruta_error, append = file.exists(ruta_error),
             col.names = !file.exists(ruta_error))
      stop(e)
    }
  )
}
