#!/usr/bin/env Rscript
# Etapa 4.1: mezcla gaussiana y puntuación de baja densidad.

etapa_04_01 <- function(datos_03, api_base = API_BASE_URL,
                         responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                         dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_03, "etapa"), "03")) stop("Ejecute primero etapa_03().", call. = FALSE)
  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  .libPaths(c(file.path(ruta_r, "library"), .libPaths()))
  if (!requireNamespace("mclust", quietly = TRUE)) stop("Instale mclust en apps/R/library.", call. = FALSE)
  suppressPackageStartupMessages(library("mclust", character.only = TRUE))
  datos_04_01 <- data.table::as.data.table(data.table::copy(datos_03))
  n <- nrow(datos_04_01); p <- ncol(datos_04_01)
  variables <- c("modelo_ylab", "modelo_tothrs", "modelo_aestudio", "modelo_s1_03a")
  x <- as.matrix(datos_04_01[, ..variables])
  if (nrow(x) != 24275L || any(!is.finite(x))) stop("La matriz de modelado no coincide con la etapa 3.", call. = FALSE)
  set.seed(20261)
  modelo <- mclust::Mclust(x, G = 1:4, modelNames = c("EII", "VII", "EEI", "VEI"),
                          control = mclust::emControl(itmax = c(100L, 100L)))
  if (is.null(modelo) || !is.finite(modelo$bic)) stop("GMM no convergió a un modelo válido.", call. = FALSE)
  log_densidad <- mclust::dens(x, modelName = modelo$modelName,
                               parameters = modelo$parameters, logarithm = TRUE)
  if (length(log_densidad) != n || any(!is.finite(log_densidad))) stop("Puntuaciones GMM inválidas.", call. = FALSE)
  puntuacion <- -as.numeric(log_densidad)
  umbral <- as.numeric(stats::quantile(puntuacion, 0.99, names = FALSE))
  data.table::set(datos_04_01, j = "gmm_score", value = puntuacion)
  data.table::set(datos_04_01, j = "gmm_atipico", value = puntuacion >= umbral)
  data.table::set(datos_04_01, j = "gmm_componente", value = as.integer(modelo$classification))
  n_atipicos <- sum(datos_04_01$gmm_atipico)

  ruta_salida <- file.path(ruta_r, "output", "04_01_gmm")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  resumen <- data.frame(n = n, componentes = modelo$G, estructura = modelo$modelName,
                       bic = modelo$bic, log_verosimilitud = modelo$loglik,
                       umbral_p99 = umbral, n_atipicos = n_atipicos,
                       pct_atipicos = 100 * n_atipicos / n)
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_gmm.csv"))
  grDevices::png(file.path(ruta_salida, "puntuaciones_gmm.png"), width = 1000, height = 650)
  graphics::hist(puntuacion, breaks = 70, col = "#6557d9", border = "white",
                 main = "Baja densidad según GMM", xlab = "Puntuación = -log(densidad)")
  graphics::abline(v = umbral, col = "#d33d3d", lwd = 2, lty = 2)
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_03[, c("id_persona", variables), with = FALSE], algo = "sha256")
  entrada <- list(
    responsible = responsable, dataset = dataset_nombre,
    variable = "(cuatro características transformadas)",
    problemType = "perfil de baja densidad",
    methodology = "KDD - 4.1 GMM",
    action = sprintf("GMM ajustó %d componentes (%s, BIC %.2f). Umbral percentil 99 de -log(densidad): %.4f; %d de %d perfiles señalados.",
                     modelo$G, modelo$modelName, modelo$bic, umbral, n_atipicos, n),
    justification = "Se seleccionó el modelo por BIC entre 1-4 componentes y estructuras diagonales; el 1% superior de baja densidad se etiqueta como candidato, no como error.",
    affectedRows = 0L,
    datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después; originales intactas, resultados solo en R",
                            n, p, nrow(datos_04_01), ncol(datos_04_01)),
    script = sprintf("apps/R/04_01_gmm.R [entrada=%s; modelo=%s; G=%d]", hash_entrada, modelo$modelName, modelo$G)
  )
  pagina <- 1L; existentes <- list()
  repeat {
    respuesta <- api_obtener_bitacora(pagina = pagina, limite = 100L, api_base = api_base)
    if (NROW(respuesta$entries)) existentes <- c(existentes, split(respuesta$entries, seq_len(NROW(respuesta$entries))))
    if (pagina >= respuesta$pagination$pages) break
    pagina <- pagina + 1L
  }
  marcadores <- vapply(existentes, function(e) as.character(e$script), character(1))
  if (!(entrada$script %in% marcadores)) {
    entrada$stepNumber <- if (length(existentes)) max(vapply(existentes, function(e) as.integer(e$stepNumber), integer(1))) + 1L else 1L
    creado <- api_crear_bitacora(entrada, api_base = api_base)
    confirmado <- api_solicitud("GET", sprintf("/api/logs/%s", creado$id), api_base = api_base)
    if (!identical(confirmado$script, entrada$script)) stop("La API no confirmó GMM.", call. = FALSE)
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 04_01"; fin <- "% FIN RESULTADOS 04_01"
  bloque <- c(inicio,
    sprintf("El GMM se ajustó sobre las cuatro características transformadas de %d personas. La selección por BIC dio %d componentes y estructura \\texttt{%s} (BIC %.2f, log-verosimilitud %.2f). La puntuación individual es la densidad logarítmica negativa. Con umbral P99 = %.4f se señalaron %d perfiles (%.2f\\%%). Las puntuaciones y etiquetas individuales permanecen en R y no reemplazan los valores laborales.",
            n, modelo$G, modelo$modelName, modelo$bic, modelo$loglik,
            umbral, n_atipicos, 100 * n_atipicos / n),
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/04_01_gmm/puntuaciones_gmm.png}",
    "\\caption{Puntuación de baja densidad GMM y umbral exploratorio P99.}",
    "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque GMM incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("Local Outlier Factor", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección LOF en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_04_01, "etapa") <- "04_01"
  cat(sprintf("Etapa 4.1 completa: GMM %s/G=%d, %d candidatos, sincronizado.\n",
              modelo$modelName, modelo$G, n_atipicos))
  datos_04_01
}
