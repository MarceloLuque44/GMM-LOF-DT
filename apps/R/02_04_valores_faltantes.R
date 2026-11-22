#!/usr/bin/env Rscript
# Etapa 2.4: selección de casos completos para GMM/LOF.
# Los registros excluidos siguen disponibles en datos_02_03 en la misma sesión.

etapa_02_04 <- function(datos_02_03, api_base = API_BASE_URL,
                        responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                        dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_02_03, "etapa"), "02_03")) {
    stop("Ejecute primero etapa_02_03() en esta misma sesión R.", call. = FALSE)
  }
  variables <- c("ylab", "tothrs", "aestudio", "s1_03a", "yprilab", "phrs")
  faltan <- setdiff(c("id_persona", variables), names(datos_02_03))
  if (length(faltan)) stop("Faltan columnas: ", paste(faltan, collapse = ", "), call. = FALSE)
  n_antes <- nrow(datos_02_03)
  p_antes <- ncol(datos_02_03)
  conteos <- vapply(datos_02_03[, ..variables], function(x) sum(is.na(x) | !is.finite(x)), integer(1))
  tabla <- data.frame(variable = variables, faltantes = unname(conteos),
                      porcentaje = round(100 * unname(conteos) / n_antes, 2))
  apto <- complete.cases(datos_02_03[, ..variables]) &
    Reduce(`&`, lapply(datos_02_03[, ..variables], is.finite))
  datos_02_04 <- data.table::copy(datos_02_03[apto])
  n_despues <- nrow(datos_02_04)
  if (n_despues != 24275L) {
    stop(sprintf("Se esperaban 24275 casos completos; se encontraron %d. Revise la versión de la fuente.", n_despues), call. = FALSE)
  }
  if (ncol(datos_02_04) != p_antes || anyDuplicated(datos_02_04$id_persona)) {
    stop("El resultado no conserva columnas o identificadores estables.", call. = FALSE)
  }

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  condicion <- data.table::fread(
    file.path(ruta_r, "ECE_1T2026.csv"), sep = ";",
    select = c("id_persona", "condact"), showProgress = FALSE
  )
  indice <- match(datos_02_04$id_persona, condicion$id_persona)
  if (anyNA(indice) || any(condicion$condact[indice] != 1L, na.rm = TRUE) ||
      anyNA(condicion$condact[indice])) {
    stop("Los casos completos no corresponden íntegramente a personas ocupadas (condact=1).", call. = FALSE)
  }
  n_ocupados <- sum(condicion$condact == 1L, na.rm = TRUE)
  ocupados_sin_ingreso <- sum(condicion$condact == 1L &
    is.na(datos_02_03$ylab[match(condicion$id_persona, datos_02_03$id_persona)]), na.rm = TRUE)

  ruta_salida <- file.path(ruta_r, "output", "02_04_valores_faltantes")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(tabla, file.path(ruta_salida, "resumen_faltantes.csv"))
  grDevices::png(file.path(ruta_salida, "faltantes_por_variable.png"), width = 1000, height = 600)
  graphics::barplot(tabla$porcentaje, names.arg = tabla$variable, las = 2,
                    col = "#6557d9", ylim = c(0, 100), ylab = "Porcentaje",
                    main = "Faltantes antes de seleccionar casos completos")
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_02_03[, c("id_persona", variables), with = FALSE], algo = "sha256")
  impacto <- sprintf("%d filas y %d columnas antes / %d filas y %d columnas para modelado; %d conservadas en el dataframe anterior",
                     n_antes, p_antes, n_despues, ncol(datos_02_04), n_antes - n_despues)
  base <- list(responsible = responsable, dataset = dataset_nombre,
               methodology = "KDD - 2.4 Tratamiento de valores faltantes",
               datasetImpact = impacto)
  operaciones <- lapply(seq_len(nrow(tabla)), function(i) {
    c(base, list(
      variable = tabla$variable[i], problemType = if (tabla$faltantes[i]) "valor faltante" else "verificación sin faltantes",
      action = sprintf("Se verificaron %d faltantes (%.2f %%) antes de seleccionar casos completos; no hubo imputación.",
                       tabla$faltantes[i], tabla$porcentaje[i]),
      justification = "Se conservan las seis variables esenciales y se evita imputar ingresos que podrían alterar perfiles atípicos.",
      affectedRows = 0L,
      script = sprintf("apps/R/02_04_valores_faltantes.R [entrada=%s; variable=%s]", hash_entrada, tabla$variable[i])
    ))
  })
  operaciones[[length(operaciones) + 1L]] <- c(base, list(
    variable = "(conjunto de modelado)", problemType = "selección de casos completos",
    action = sprintf("Se seleccionaron %d casos completos y ocupados de %d registros; %d no entran al modelado. Entre %d ocupados, %d carecen de ingreso laboral.",
                     n_despues, n_antes, n_antes - n_despues, n_ocupados, ocupados_sin_ingreso),
    justification = "Decisión metodológica del responsable: entrenar GMM/LOF con casos completos, sin imputación ni eliminación del CSV original.",
    affectedRows = as.integer(n_antes - n_despues),
    script = sprintf("apps/R/02_04_valores_faltantes.R [entrada=%s; seleccion=casos_completos]", hash_entrada)
  ))

  pagina <- 1L
  existentes <- list()
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
    if (!identical(confirmado$script, op$script)) stop("La API no confirmó una operación de 2.4.", call. = FALSE)
    siguiente <- siguiente + 1L
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 02_04"
  fin <- "% FIN RESULTADOS 02_04"
  filas_tabla <- paste(sprintf("%s & %d & %.2f\\%% \\\\ ",
                             gsub("_", "\\_", tabla$variable, fixed = TRUE),
                             tabla$faltantes, tabla$porcentaje), collapse = "\n")
  bloque <- c(inicio,
    sprintf("Se revisaron %d registros y %d columnas. Para GMM y LOF se seleccionaron %d personas ocupadas con las seis variables completas (%.2f\\%% del total). Los %d registros restantes se conservan en el dataframe de la etapa anterior. Entre %d ocupados, %d no tienen ingreso laboral; no se imputaron valores.",
            n_antes, p_antes, n_despues, 100 * n_despues / n_antes,
            n_antes - n_despues, n_ocupados, ocupados_sin_ingreso),
    "\\begin{table}[H]\\centering",
    "\\caption{Valores faltantes en las seis variables antes de la selección}",
    "\\begin{tabular}{lrr}\\toprule Variable & Faltantes & Porcentaje \\\\ \\midrule",
    filas_tabla,
    "\\bottomrule\\end{tabular}\\end{table}",
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/02_04_valores_faltantes/faltantes_por_variable.png}",
    "\\caption{Faltantes por variable antes de seleccionar casos completos.}",
    "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque 02_04 incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("(Outliers)", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección de outliers en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_02_04, "etapa") <- "02_04"
  attr(datos_02_04, "hash_entrada") <- hash_entrada
  cat(sprintf("Etapa 2.4 completa: %d de %d personas seleccionadas; %d operaciones verificadas.\n",
              n_despues, n_antes, length(operaciones)))
  datos_02_04
}
