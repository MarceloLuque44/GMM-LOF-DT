#!/usr/bin/env Rscript
# Etapa 2.5: detección exploratoria de extremos. No elimina ni capa valores.

etapa_02_05 <- function(datos_02_04, api_base = API_BASE_URL,
                        responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                        dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_02_04, "etapa"), "02_04")) {
    stop("Ejecute primero etapa_02_04() en la misma sesión R.", call. = FALSE)
  }
  datos_02_05 <- data.table::as.data.table(data.table::copy(datos_02_04))
  variables <- c("ylab", "tothrs", "aestudio", "s1_03a", "yprilab", "phrs")
  n_antes <- nrow(datos_02_05)
  p_antes <- ncol(datos_02_05)
  conteos <- lapply(variables, function(variable) {
    x <- datos_02_05[[variable]]
    if (anyNA(x) || any(!is.finite(x))) stop("La variable tiene faltantes o valores no finitos: ", variable, call. = FALSE)
    q <- stats::quantile(x, c(0.25, 0.75), names = FALSE)
    rango <- q[2] - q[1]
    inferior <- q[1] - 1.5 * rango
    superior <- q[2] + 1.5 * rango
    marca_iqr <- x < inferior | x > superior
    desvio <- stats::sd(x)
    marca_z <- if (is.finite(desvio) && desvio > 0) abs((x - mean(x)) / desvio) > 3 else rep(FALSE, length(x))
    data.frame(variable = variable, minimo = min(x), q1 = q[1], mediana = stats::median(x),
               q3 = q[2], maximo = max(x), limite_inferior = inferior,
               limite_superior = superior, iqr = sum(marca_iqr), z3 = sum(marca_z),
               union = sum(marca_iqr | marca_z))
  })
  resumen <- do.call(rbind, conteos)
  stopifnot(nrow(datos_02_05) == n_antes, ncol(datos_02_05) == p_antes)

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "02_05_outliers")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_outliers.csv"))
  grDevices::png(file.path(ruta_salida, "extremos_iqr_z.png"), width = 1100, height = 650)
  graphics::barplot(rbind(resumen$iqr, resumen$z3), beside = TRUE,
                    names.arg = resumen$variable, las = 2,
                    col = c("#6557d9", "#d98b42"),
                    main = "Registros señalados por IQR y Z > 3",
                    ylab = "Observaciones")
  graphics::legend("topright", legend = c("IQR", "Z > 3"),
                   fill = c("#6557d9", "#d98b42"), bty = "n")
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_02_04[, c("id_persona", variables), with = FALSE], algo = "sha256")
  base <- list(responsible = responsable, dataset = dataset_nombre,
               methodology = "KDD - 2.5 Identificación de valores atípicos",
               datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después; sin eliminación ni capado",
                                       n_antes, p_antes, nrow(datos_02_05), ncol(datos_02_05)))
  operaciones <- lapply(seq_len(nrow(resumen)), function(i) {
    c(base, list(variable = resumen$variable[i], problemType = "candidato atípico",
                 action = sprintf("Se señalaron %d valores por IQR y %d por |Z|>3; %d en la unión. No se modificaron datos.",
                                  resumen$iqr[i], resumen$z3[i], resumen$union[i]),
                 justification = "Un valor extremo puede representar un perfil laboral válido; la detección univariada no confirma error.",
                 affectedRows = 0L,
                 script = sprintf("apps/R/02_05_outliers.R [entrada=%s; variable=%s]", hash_entrada, resumen$variable[i])))
  })
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
    if (!identical(confirmado$script, op$script)) stop("No se confirmó la persistencia de 2.5.", call. = FALSE)
    siguiente <- siguiente + 1L
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 02_05"
  fin <- "% FIN RESULTADOS 02_05"
  filas <- paste(sprintf("%s & %d & %d & %d \\\\",
                         gsub("_", "\\_", resumen$variable, fixed = TRUE),
                         resumen$iqr, resumen$z3, resumen$union), collapse = "\n")
  bloque <- c(inicio,
    sprintf("En los %d casos completos se aplicaron límites IQR (1,5 veces el rango intercuartílico) y la regla |Z|>3 a las seis variables. Las etiquetas son candidaturas exploratorias, no errores confirmados. Se conservaron las %d filas y %d columnas para GMM y LOF.",
            n_antes, nrow(datos_02_05), ncol(datos_02_05)),
    "\\begin{table}[H]\\centering",
    "\\caption{Candidatos a valores extremos por variable}",
    "\\begin{tabular}{lrrr}\\toprule Variable & IQR & $|Z|>3$ & Unión \\\\ \\midrule",
    filas,
    "\\bottomrule\\end{tabular}\\end{table}",
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/02_05_outliers/extremos_iqr_z.png}",
    "\\caption{Frecuencia de candidatos extremos según IQR y Z.}",
    "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque 02_05 incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("reglas de negocio}", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección de consistencia en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_02_05, "etapa") <- "02_05"
  cat(sprintf("Etapa 2.5 completa: %d observaciones conservadas; %d verificaciones en API.\n",
              nrow(datos_02_05), length(operaciones)))
  datos_02_05
}
