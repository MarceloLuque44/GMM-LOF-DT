#!/usr/bin/env Rscript
# Etapa 4.2: LOF sobre las mismas cuatro características que GMM.

etapa_04_02 <- function(datos_04_01, api_base = API_BASE_URL,
                         responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                         dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_04_01, "etapa"), "04_01")) stop("Ejecute primero etapa_04_01().", call. = FALSE)
  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  .libPaths(c(file.path(ruta_r, "library"), .libPaths()))
  if (!requireNamespace("dbscan", quietly = TRUE)) stop("Instale dbscan en apps/R/library.", call. = FALSE)
  datos_04_02 <- data.table::as.data.table(data.table::copy(datos_04_01))
  n <- nrow(datos_04_02); p <- ncol(datos_04_02)
  variables <- c("modelo_ylab", "modelo_tothrs", "modelo_aestudio", "modelo_s1_03a")
  x <- as.matrix(datos_04_02[, ..variables])
  if (nrow(x) != 24275L || any(!is.finite(x))) stop("Matriz de LOF inválida.", call. = FALSE)
  k <- 20L
  puntuacion <- as.numeric(dbscan::lof(x, minPts = k))
  if (length(puntuacion) != n || any(!is.finite(puntuacion))) stop("Puntuaciones LOF inválidas.", call. = FALSE)
  umbral <- as.numeric(stats::quantile(puntuacion, 0.99, names = FALSE))
  atipico <- puntuacion >= umbral
  data.table::set(datos_04_02, j = "lof_score", value = puntuacion)
  data.table::set(datos_04_02, j = "lof_atipico", value = atipico)
  n_atipicos <- sum(atipico)
  perfiles_iguales <- sum(duplicated(datos_04_02[, ..variables]))

  ruta_salida <- file.path(ruta_r, "output", "04_02_lof")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  resumen <- data.frame(n = n, minPts = k, umbral_p99 = umbral,
                       n_atipicos = n_atipicos, pct_atipicos = 100 * n_atipicos / n,
                       perfiles_transformados_iguales = perfiles_iguales,
                       score_min = min(puntuacion), score_mediana = stats::median(puntuacion),
                       score_max = max(puntuacion))
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_lof.csv"))
  grDevices::png(file.path(ruta_salida, "puntuaciones_lof.png"), width = 1000, height = 650)
  graphics::hist(puntuacion, breaks = 70, col = "#6557d9", border = "white",
                 main = "Factor de valores atípicos locales", xlab = "Puntuación LOF")
  graphics::abline(v = umbral, col = "#d33d3d", lwd = 2, lty = 2)
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_04_01[, c("id_persona", variables), with = FALSE], algo = "sha256")
  entrada <- list(
    responsible = responsable, dataset = dataset_nombre,
    variable = "(cuatro características transformadas)",
    problemType = "densidad local baja",
    methodology = "KDD - 4.2 LOF",
    action = sprintf("LOF con minPts=%d, umbral P99=%.4f; %d de %d perfiles señalados. %d perfiles transformados coinciden exactamente.",
                     k, umbral, n_atipicos, n, perfiles_iguales),
    justification = "El percentil 99 identifica candidatos exploratorios; las coincidencias entre personas distintas no se eliminan y dbscan define LOF=1 para vecinos idénticos densos.",
    affectedRows = 0L,
    datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después; puntuaciones solo en R",
                            n, p, nrow(datos_04_02), ncol(datos_04_02)),
    script = sprintf("apps/R/04_02_lof.R [entrada=%s; minPts=%d]", hash_entrada, k)
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
    if (!identical(confirmado$script, entrada$script)) stop("La API no confirmó LOF.", call. = FALSE)
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 04_02"; fin <- "% FIN RESULTADOS 04_02"
  bloque <- c(inicio,
    sprintf("LOF se aplicó a las mismas cuatro características de %d personas, con $\\mathrm{minPts}=%d$. El umbral exploratorio P99 fue %.4f y señaló %d perfiles (%.2f\\%%). Se observaron %d perfiles transformados idénticos; corresponden a identificadores distintos y se conservaron. Las puntuaciones individuales permanecen en R.",
            n, k, umbral, n_atipicos, 100 * n_atipicos / n, perfiles_iguales),
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/04_02_lof/puntuaciones_lof.png}",
    "\\caption{Distribución de puntuaciones LOF y umbral P99.}", "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque LOF incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("Evaluación e interpretación}", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección 5 en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_04_02, "etapa") <- "04_02"
  cat(sprintf("Etapa 4.2 completa: LOF minPts=%d, %d candidatos, sincronizado.\n", k, n_atipicos))
  datos_04_02
}
