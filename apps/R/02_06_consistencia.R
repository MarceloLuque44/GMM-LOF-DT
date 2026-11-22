#!/usr/bin/env Rscript
# Etapa 2.6: reglas de dominio. No modifica extremos válidos.

etapa_02_06 <- function(datos_02_05, api_base = API_BASE_URL,
                        responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                        dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_02_05, "etapa"), "02_05")) stop("Ejecute primero etapa_02_05().", call. = FALSE)
  datos_02_06 <- data.table::as.data.table(data.table::copy(datos_02_05))
  n <- nrow(datos_02_06); p <- ncol(datos_02_06)
  reglas <- list(
    ylab = function(x) x > 0,
    tothrs = function(x) x > 0 & x <= 168,
    aestudio = function(x) x >= 0 & x <= 30,
    s1_03a = function(x) x >= 10 & x <= 98,
    yprilab = function(x) x > 0,
    phrs = function(x) x > 0 & x <= 168
  )
  errores <- vapply(names(reglas), function(v) {
    x <- datos_02_06[[v]]
    sum(is.na(x) | !is.finite(x) | !reglas[[v]](x))
  }, integer(1))
  variables <- names(errores)
  resumen <- data.frame(variable = variables, minimo = vapply(datos_02_06[, ..variables], min, numeric(1)),
                       maximo = vapply(datos_02_06[, ..variables], max, numeric(1)),
                       fuera_dominio = unname(errores), row.names = NULL)
  pares <- c(ingresos_iguales = sum(datos_02_06$ylab == datos_02_06$yprilab),
             horas_iguales = sum(datos_02_06$tothrs == datos_02_06$phrs))
  if (any(errores)) stop("Hay valores fuera de dominio; revise la fuente y la regla antes de continuar.", call. = FALSE)
  if (nrow(datos_02_06) != n || ncol(datos_02_06) != p) stop("Cambió el tamaño del dataframe.", call. = FALSE)

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "02_06_consistencia")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_consistencia.csv"))
  grDevices::png(file.path(ruta_salida, "rangos_variables.png"), width = 1000, height = 650)
  graphics::barplot(resumen$maximo, names.arg = resumen$variable, las = 2, log = "y",
                    col = "#6557d9", ylab = "Máximo observado (escala log)",
                    main = "Máximos observados de las variables")
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_02_06[, c("id_persona", names(reglas)), with = FALSE], algo = "sha256")
  base <- list(responsible = responsable, dataset = dataset_nombre,
               methodology = "KDD - 2.6 Validación de consistencia",
               datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después", n, p, n, p))
  operaciones <- lapply(seq_len(nrow(resumen)), function(i) c(base, list(
    variable = resumen$variable[i], problemType = "verificación de dominio",
    action = sprintf("Rango observado: %s a %s; %d valores fuera de dominio.",
                     resumen$minimo[i], resumen$maximo[i], resumen$fuera_dominio[i]),
    justification = "Se comprobó el dominio esperado sin recortar valores extremos válidos.",
    affectedRows = 0L,
    script = sprintf("apps/R/02_06_consistencia.R [entrada=%s; variable=%s]", hash_entrada, resumen$variable[i])
  )))
  operaciones[[7]] <- c(base, list(variable = "ylab/yprilab", problemType = "verificación de redundancia",
    action = sprintf("Los dos ingresos son iguales en %d de %d personas.", pares[1], n),
    justification = "La igualdad exacta impide usar ambos ingresos como características independientes en GMM.",
    affectedRows = 0L, script = sprintf("apps/R/02_06_consistencia.R [entrada=%s; par=ingresos]", hash_entrada)))
  operaciones[[8]] <- c(base, list(variable = "tothrs/phrs", problemType = "verificación de redundancia",
    action = sprintf("Las dos jornadas son iguales en %d de %d personas.", pares[2], n),
    justification = "La igualdad exacta daría doble peso a las horas en LOF; se entrenará con cuatro características.",
    affectedRows = 0L, script = sprintf("apps/R/02_06_consistencia.R [entrada=%s; par=horas]", hash_entrada)))
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
    if (!identical(confirmado$script, op$script)) stop("No se confirmó la persistencia de 2.6.", call. = FALSE)
    siguiente <- siguiente + 1L
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 02_06"; fin <- "% FIN RESULTADOS 02_06"
  filas <- paste(sprintf("%s & %.2f & %.2f & %d \\\\",
                         gsub("_", "\\_", resumen$variable, fixed = TRUE),
                         resumen$minimo, resumen$maximo, resumen$fuera_dominio), collapse = "\n")
  bloque <- c(inicio,
    sprintf("Se validaron %d personas y %d columnas. Ninguna de las seis variables presenta valores fuera de los dominios comprobados; no se modificó ningún registro. Los ingresos \\texttt{ylab} y \\texttt{yprilab} son iguales en %d filas, y las horas \\texttt{tothrs} y \\texttt{phrs} en %d. Se conservarán las seis columnas, pero se utilizarán cuatro características no redundantes en los modelos.", n, p, pares[1], pares[2]),
    "\\begin{table}[H]\\centering", "\\caption{Rangos observados y valores fuera de dominio}",
    "\\begin{tabular}{lrrr}\\toprule Variable & Mínimo & Máximo & Fuera de dominio \\\\ \\midrule",
    filas, "\\bottomrule\\end{tabular}\\end{table}",
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/02_06_consistencia/rangos_variables.png}",
    "\\caption{Rangos de las variables antes de la transformación.}", "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque 02_06 incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("Transformación", texto, fixed = TRUE) & grepl("section", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección 3 en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[length(anclas)] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_02_06, "etapa") <- "02_06"
  cat(sprintf("Etapa 2.6 completa: %d filas, 0 valores fuera de dominio y %d verificaciones.\n", n, length(operaciones)))
  datos_02_06
}
