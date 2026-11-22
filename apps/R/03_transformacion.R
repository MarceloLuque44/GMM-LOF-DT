#!/usr/bin/env Rscript
# Etapa 3: cuatro características no redundantes para GMM y LOF.
# Se conserva cada una de las seis variables laborales originales.

etapa_03 <- function(datos_02_06, api_base = API_BASE_URL,
                     responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                     dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_02_06, "etapa"), "02_06")) stop("Ejecute primero etapa_02_06().", call. = FALSE)
  datos_03 <- data.table::as.data.table(data.table::copy(datos_02_06))
  n <- nrow(datos_03); p <- ncol(datos_03)
  variables <- c("ylab", "tothrs", "aestudio", "s1_03a")
  if (anyNA(datos_03[, ..variables])) stop("Las características tienen faltantes.", call. = FALSE)
  originales <- data.table::copy(datos_03[, c("id_persona", "ylab", "tothrs", "aestudio", "s1_03a", "yprilab", "phrs"), with = FALSE])
  transformadas <- list(
    modelo_ylab = log1p(datos_03$ylab),
    modelo_tothrs = datos_03$tothrs,
    modelo_aestudio = datos_03$aestudio,
    modelo_s1_03a = datos_03$s1_03a
  )
  resumen <- data.frame(variable = variables, transformacion = c("log1p + z", "z", "z", "z"),
                       media_pre = vapply(transformadas, mean, numeric(1)),
                       sd_pre = vapply(transformadas, stats::sd, numeric(1)),
                       row.names = NULL)
  if (any(!is.finite(resumen$sd_pre)) || any(resumen$sd_pre <= 0)) {
    stop("Una característica es constante o inválida; no puede estandarizarse.", call. = FALSE)
  }
  for (i in seq_along(transformadas)) {
    columna <- names(transformadas)[i]
    data.table::set(datos_03, j = columna,
                    value = (transformadas[[i]] - resumen$media_pre[i]) / resumen$sd_pre[i])
  }
  nuevas <- names(transformadas)
  if (nrow(datos_03) != n || ncol(datos_03) != p + 4L ||
      !identical(datos_03[, names(originales), with = FALSE], originales) ||
      anyNA(datos_03[, ..nuevas])) stop("La transformación alteró datos originales o produjo NA.", call. = FALSE)
  resumen$media_post <- vapply(datos_03[, ..nuevas], mean, numeric(1))
  resumen$sd_post <- vapply(datos_03[, ..nuevas], stats::sd, numeric(1))

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "03_transformacion")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(resumen, file.path(ruta_salida, "parametros_transformacion.csv"))
  grDevices::png(file.path(ruta_salida, "distribucion_transformada.png"), width = 1000, height = 750)
  graphics::par(mfrow = c(2, 2), mar = c(4, 4, 3, 1))
  for (i in seq_along(nuevas)) {
    graphics::hist(datos_03[[nuevas[i]]], breaks = 50, col = "#6557d9",
                   border = "white", main = nuevas[i], xlab = "Valor estandarizado")
  }
  grDevices::dev.off()

  hash_entrada <- digest::digest(originales, algo = "sha256")
  base <- list(responsible = responsable, dataset = dataset_nombre,
               methodology = "KDD - 3 Transformación",
               datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después; 6 variables originales intactas",
                                       n, p, nrow(datos_03), ncol(datos_03)))
  operaciones <- lapply(seq_along(variables), function(i) c(base, list(
    variable = variables[i], problemType = "escala/asimetría",
    action = sprintf("Se añadió %s mediante %s; media previa %.4f, desvío previo %.4f, media posterior %.4f y desvío posterior %.4f.",
                     nuevas[i], resumen$transformacion[i], resumen$media_pre[i], resumen$sd_pre[i],
                     resumen$media_post[i], resumen$sd_post[i]),
    justification = if (i == 1) "El ingreso es asimétrico; log1p reduce escala sin eliminar extremos y z evita dominar distancias." else
      "La escala z permite comparar características con unidades distintas en GMM y LOF.",
    affectedRows = n,
    script = sprintf("apps/R/03_transformacion.R [entrada=%s; variable=%s]", hash_entrada, variables[i])
  )))
  operaciones[[5]] <- c(base, list(
    variable = "yprilab/phrs", problemType = "redundancia exacta",
    action = "Se conservaron las seis variables originales, pero se usan cuatro características no redundantes para los modelos.",
    justification = "ylab=yprilab y tothrs=phrs en todos los casos completos; evitar singularidad y doble peso.",
    affectedRows = 0L,
    script = sprintf("apps/R/03_transformacion.R [entrada=%s; control=redundancia]", hash_entrada)))
  pagina <- 1L; existentes <- list()
  repeat {
    respuesta <- api_obtener_bitacora(pagina = pagina, limite = 100L, api_base = api_base)
    if (NROW(respuesta$entries)) existentes <- c(existentes, split(respuesta$entries, seq_len(NROW(respuesta$entries))))
    if (pagina >= respuesta$pagination$pages) break
    pagina <- pagina + 1L
  }
  marcadores <- vapply(existentes, function(e) as.character(e$script), character(1))
  siguiente <- if (length(existentes)) max(vapply(existentes, function(e) as.integer(e$stepNumber), integer(1))) + 1L else 1L
  for (op in operaciones) {
    if (op$script %in% marcadores) next
    op$stepNumber <- siguiente
    creado <- api_crear_bitacora(op, api_base = api_base)
    confirmado <- api_solicitud("GET", sprintf("/api/logs/%s", creado$id), api_base = api_base)
    if (!identical(confirmado$script, op$script)) stop("No se confirmó la persistencia de etapa 3.", call. = FALSE)
    siguiente <- siguiente + 1L
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 03"; fin <- "% FIN RESULTADOS 03"
  filas <- paste(sprintf("%s & %s & %.3f & %.3f \\\\",
                         gsub("_", "\\_", resumen$variable, fixed = TRUE),
                         resumen$transformacion, resumen$media_pre, resumen$sd_pre), collapse = "\n")
  bloque <- c(inicio,
    sprintf("Para %d personas se añadieron cuatro características no redundantes. Se aplicó $\\log(1+x)$ al ingreso total y después se estandarizaron las cuatro características. Las seis variables laborales originales y los identificadores permanecen intactos. El dataframe pasó de %d a %d columnas.", n, p, ncol(datos_03)),
    "\\begin{table}[H]\\centering", "\\caption{Parámetros de transformación para GMM y LOF}",
    "\\begin{tabular}{llrr}\\toprule Variable & Operación & Media previa & Desvío previo \\\\ \\midrule",
    filas, "\\bottomrule\\end{tabular}\\end{table}",
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/03_transformacion/distribucion_transformada.png}",
    "\\caption{Distribuciones de las cuatro características transformadas.}", "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque 03 incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("Minería de datos}", texto, fixed = TRUE) & grepl("section", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección 4 en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[length(anclas)] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_03, "etapa") <- "03"
  cat(sprintf("Etapa 3 completa: %d personas, 4 características transformadas, %d verificaciones.\n", n, length(operaciones)))
  datos_03
}
