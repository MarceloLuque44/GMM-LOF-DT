#!/usr/bin/env Rscript
# Etapa 5: evaluación descriptiva sin etiquetas de verdad terreno.

etapa_05 <- function(datos_04_02, api_base = API_BASE_URL,
                     responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                     dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_04_02, "etapa"), "04_02")) stop("Ejecute primero etapa_04_02().", call. = FALSE)
  datos_05 <- data.table::as.data.table(data.table::copy(datos_04_02))
  n <- nrow(datos_05); p <- ncol(datos_05)
  if (anyNA(datos_05[, .(gmm_score, lof_score, gmm_atipico, lof_atipico, id_persona)]) ||
      any(!is.finite(datos_05$gmm_score)) || any(!is.finite(datos_05$lof_score)) ||
      anyDuplicated(datos_05$id_persona)) stop("Resultados de modelos incompletos o IDs repetidos.", call. = FALSE)
  resumen <- do.call(rbind, lapply(c("gmm", "lof"), function(modelo) {
    marca <- datos_05[[paste0(modelo, "_atipico")]]
    puntuacion <- datos_05[[paste0(modelo, "_score")]]
    data.frame(modelo = toupper(modelo), n = n, candidatos = sum(marca),
               porcentaje = 100 * mean(marca),
               score_mediana = stats::median(puntuacion),
               score_p99 = as.numeric(stats::quantile(puntuacion, .99)),
               score_max = max(puntuacion),
               ingreso_mediana_candidatos = stats::median(datos_05$ylab[marca]),
               ingreso_mediana_resto = stats::median(datos_05$ylab[!marca]),
               horas_mediana_candidatos = stats::median(datos_05$tothrs[marca]),
               horas_mediana_resto = stats::median(datos_05$tothrs[!marca]))
  }))
  if (nrow(datos_05) != n || ncol(datos_05) != p) stop("Se alteraron las dimensiones.", call. = FALSE)

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "05_evaluacion")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_evaluacion.csv"))
  grDevices::png(file.path(ruta_salida, "ingresos_candidatos.png"), width = 1000, height = 650)
  graphics::barplot(rbind(resumen$ingreso_mediana_candidatos, resumen$ingreso_mediana_resto),
                    beside = TRUE, names.arg = resumen$modelo, col = c("#d98b42", "#6557d9"),
                    main = "Mediana de ingreso por clasificación", ylab = "Bs/mes")
  graphics::legend("topright", legend = c("Candidatos", "Resto"), fill = c("#d98b42", "#6557d9"), bty = "n")
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_05[, .(id_persona, gmm_score, lof_score, gmm_atipico, lof_atipico)], algo = "sha256")
  base <- list(responsible = responsable, dataset = dataset_nombre,
               methodology = "KDD - 5 Evaluación e interpretación",
               datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después; sin modificaciones", n, p, n, p))
  operaciones <- lapply(seq_len(nrow(resumen)), function(i) c(base, list(
    variable = resumen$modelo[i], problemType = "evaluación de candidatos",
    action = sprintf("%d candidatos (%.2f %%); mediana ingreso candidatos %.2f Bs, resto %.2f Bs; mediana horas candidatos %.2f, resto %.2f.",
                     resumen$candidatos[i], resumen$porcentaje[i],
                     resumen$ingreso_mediana_candidatos[i], resumen$ingreso_mediana_resto[i],
                     resumen$horas_mediana_candidatos[i], resumen$horas_mediana_resto[i]),
    justification = "Evaluación descriptiva sin etiquetas externas; las diferencias observadas no son prueba de error ni de validez causal.",
    affectedRows = 0L,
    script = sprintf("apps/R/05_evaluacion.R [entrada=%s; modelo=%s]", hash_entrada, resumen$modelo[i])
  )))
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
    if (!identical(confirmado$script, op$script)) stop("No se confirmó la evaluación en la API.", call. = FALSE)
    siguiente <- siguiente + 1L
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 05"; fin <- "% FIN RESULTADOS 05"
  filas <- paste(sprintf("%s & %d & %.2f\\%% & %.2f & %.2f \\\\",
                         resumen$modelo, resumen$candidatos, resumen$porcentaje,
                         resumen$ingreso_mediana_candidatos, resumen$ingreso_mediana_resto), collapse = "\n")
  bloque <- c(inicio,
    sprintf("Se evaluaron %d personas con identificadores únicos y puntuaciones finitas de ambos modelos. No existen etiquetas externas de anomalía verdadera, por lo que no se calculan precisión ni sensibilidad. Los candidatos son exploratorios y se conservan los valores laborales originales.", n),
    "\\begin{table}[H]\\centering", "\\caption{Evaluación descriptiva de candidatos}",
    "\\begin{tabular}{lrrrr}\\toprule Modelo & Candidatos & Porcentaje & Ingreso mediano candidatos & Resto \\\\ \\midrule",
    filas, "\\bottomrule\\end{tabular}\\end{table}",
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/05_evaluacion/ingresos_candidatos.png}",
    "\\caption{Ingresos medianos de candidatos y resto por modelo.}", "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque de evaluación incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("Comparación de resultados}", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró comparación de resultados en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_05, "etapa") <- "05"
  cat(sprintf("Etapa 5 completa: %d personas y 2 evaluaciones confirmadas.\n", n))
  datos_05
}
