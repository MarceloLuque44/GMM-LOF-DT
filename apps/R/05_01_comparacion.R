#!/usr/bin/env Rscript
# Etapa 5.1: comparación de etiquetas GMM y LOF sobre los mismos IDs.

etapa_05_01 <- function(datos_05, api_base = API_BASE_URL,
                        responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                        dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_05, "etapa"), "05")) stop("Ejecute primero etapa_05().", call. = FALSE)
  datos_05_01 <- data.table::as.data.table(data.table::copy(datos_05))
  n <- nrow(datos_05_01); p <- ncol(datos_05_01)
  gmm <- datos_05_01$gmm_atipico
  lof <- datos_05_01$lof_atipico
  if (anyNA(gmm) || anyNA(lof) || anyDuplicated(datos_05_01$id_persona)) stop("Etiquetas o identificadores inválidos.", call. = FALSE)
  ambos <- sum(gmm & lof)
  solo_gmm <- sum(gmm & !lof)
  solo_lof <- sum(!gmm & lof)
  ninguno <- sum(!gmm & !lof)
  union <- ambos + solo_gmm + solo_lof
  jaccard <- if (union) ambos / union else NA_real_
  acuerdo <- (ambos + ninguno) / n
  if (sum(c(ambos, solo_gmm, solo_lof, ninguno)) != n) stop("El cruce de etiquetas no cubre todas las filas.", call. = FALSE)
  resumen <- data.frame(n = n, ambos = ambos, solo_gmm = solo_gmm,
                       solo_lof = solo_lof, ninguno = ninguno,
                       union = union, jaccard = jaccard, acuerdo_global = acuerdo)

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "05_01_comparacion")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_comparacion.csv"))
  grDevices::png(file.path(ruta_salida, "acuerdo_modelos.png"), width = 1000, height = 650)
  graphics::barplot(c(ambos, solo_gmm, solo_lof), names.arg = c("Ambos", "Solo GMM", "Solo LOF"),
                    col = c("#6557d9", "#d98b42", "#2e9f9a"),
                    main = "Coincidencia de candidatos GMM y LOF", ylab = "Personas")
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_05_01[, .(id_persona, gmm_atipico, lof_atipico)], algo = "sha256")
  entrada <- list(
    responsible = responsable, dataset = dataset_nombre,
    variable = "GMM/LOF", problemType = "comparación de resultados",
    methodology = "KDD - 5.1 Comparación de resultados",
    action = sprintf("Ambos: %d; solo GMM: %d; solo LOF: %d; ninguno: %d. Jaccard %.4f y acuerdo global %.4f.",
                     ambos, solo_gmm, solo_lof, ninguno, jaccard, acuerdo),
    justification = "La coincidencia mide acuerdo entre algoritmos, no exactitud frente a una verdad externa. Se mantienen los casos discordantes para interpretación.",
    affectedRows = 0L,
    datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después; resultados individuales solo en R", n, p, n, p),
    script = sprintf("apps/R/05_01_comparacion.R [entrada=%s; comparacion=GMM_LOF]", hash_entrada)
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
    if (!identical(confirmado$script, entrada$script)) stop("La API no confirmó la comparación.", call. = FALSE)
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 05_01"; fin <- "% FIN RESULTADOS 05_01"
  bloque <- c(inicio,
    sprintf("Sobre los mismos %d identificadores, GMM y LOF coinciden en %d candidatos. Solo GMM señala %d y solo LOF %d; ambos consideran no candidatos a %d. La similitud de Jaccard entre conjuntos de candidatos es %.4f, y el acuerdo global %.4f. Este último está dominado por los casos no señalados, por lo que se informa junto con Jaccard. Los desacuerdos son perfiles de interés y no se eliminan.",
            n, ambos, solo_gmm, solo_lof, ninguno, jaccard, acuerdo),
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/05_01_comparacion/acuerdo_modelos.png}",
    "\\caption{Coincidencias y diferencias entre las etiquetas GMM y LOF.}", "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque de comparación incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("Figuras del perfilado de variables}", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección siguiente del informe.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_05_01, "etapa") <- "05_01"
  cat(sprintf("Etapa 5.1 completa: ambos=%d, solo GMM=%d, solo LOF=%d; API verificada.\n",
              ambos, solo_gmm, solo_lof))
  datos_05_01
}
