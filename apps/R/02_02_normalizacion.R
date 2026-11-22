#!/usr/bin/env Rscript
# Etapa 2.2: normalización de estructura y formatos.
# Uso en una sesión R: resultado_02_02 <- etapa_02_02(datos_analisis)
# El dataframe resultante permanece en memoria; el CSV original no se altera.

etapa_02_02 <- function(datos, api_base = API_BASE_URL,
                        responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                        dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  requeridas <- c("id_persona", "ylab", "tothrs", "aestudio", "s1_03a", "yprilab", "phrs")
  faltan <- setdiff(requeridas, names(datos))
  if (length(faltan)) stop("Faltan columnas: ", paste(faltan, collapse = ", "), call. = FALSE)
  if (!nrow(datos)) stop("El dataframe está vacío.", call. = FALSE)

  datos_02_02 <- data.table::as.data.table(data.table::copy(datos))
  n_inicial <- nrow(datos_02_02)
  columnas_iniciales <- ncol(datos_02_02)
  hash_entrada <- digest::digest(datos_02_02[, ..requeridas], algo = "sha256")
  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "02_02_normalizacion")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)

  # Se compara el identificador como texto; los valores vacíos se detectan,
  # pero no se convierten en un identificador artificial.
  id_antes <- as.character(datos_02_02$id_persona)
  id_despues <- trimws(id_antes)
  n_trim <- sum(!is.na(id_antes) & id_antes != id_despues)
  datos_02_02[, id_persona := id_despues]
  n_id_vacios <- sum(is.na(id_despues) | id_despues == "")
  n_id_repetidos <- sum(duplicated(id_despues[!is.na(id_despues) & id_despues != ""]))

  num_vars <- setdiff(requeridas, "id_persona")
  conversiones <- integer(length(num_vars))
  names(conversiones) <- num_vars
  invalidos <- integer(length(num_vars))
  names(invalidos) <- num_vars
  for (variable in num_vars) {
    original <- datos_02_02[[variable]]
    if (is.numeric(original)) next
    texto <- trimws(as.character(original))
    texto[texto %in% c("", "NA", "N/A", "NULL")] <- NA_character_
    convertido <- suppressWarnings(as.numeric(gsub(",", ".", texto, fixed = TRUE)))
    invalidos[variable] <- sum(!is.na(texto) & is.na(convertido))
    if (invalidos[variable] > 0) {
      stop(sprintf("%s contiene %d valores no numéricos; se requiere una regla de corrección antes de continuar.",
                   variable, invalidos[variable]), call. = FALSE)
    }
    conversiones[variable] <- sum(!is.na(convertido))
    data.table::set(datos_02_02, j = variable, value = convertido)
  }

  if (n_id_vacios || n_id_repetidos) {
    stop(sprintf("Identificadores inválidos: %d vacíos y %d repetidos. Se requiere revisar la fuente.",
                 n_id_vacios, n_id_repetidos), call. = FALSE)
  }

  resumen <- data.frame(
    variable = c("id_persona", num_vars),
    tipo_final = vapply(datos_02_02[, ..requeridas], function(x) class(x)[1], character(1)),
    filas_afectadas = c(n_trim, unname(conversiones)),
    valores_faltantes = vapply(datos_02_02[, ..requeridas], function(x) sum(is.na(x)), integer(1)),
    stringsAsFactors = FALSE
  )
  ruta_tabla <- file.path(ruta_salida, "resumen_formatos.csv")
  data.table::fwrite(resumen, ruta_tabla)
  ruta_figura <- file.path(ruta_salida, "faltantes_tras_normalizacion.png")
  grDevices::png(ruta_figura, width = 1000, height = 600)
  graphics::barplot(resumen$valores_faltantes, names.arg = resumen$variable,
                    col = "#6557d9", main = "Valores faltantes tras normalización",
                    ylab = "Registros", las = 2)
  grDevices::dev.off()

  if (nrow(datos_02_02) != n_inicial || ncol(datos_02_02) != columnas_iniciales) {
    stop("La normalización cambió las dimensiones del dataframe.", call. = FALSE)
  }

  # La bitácora existente es el contrato de la API para resultados agregados.
  # El marcador estable evita reenviar las mismas operaciones al reintentar.
  entrada_base <- list(
    responsible = responsable, dataset = dataset_nombre,
    methodology = "KDD - 2.2 Normalización de estructura y formatos",
    datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después",
                            n_inicial, columnas_iniciales, nrow(datos_02_02), ncol(datos_02_02))
  )
  operaciones <- lapply(seq_len(nrow(resumen)), function(i) {
    variable <- resumen$variable[i]
    afectados <- resumen$filas_afectadas[i]
    c(entrada_base, list(
      variable = variable,
      problemType = if (afectados) "formato" else "verificación sin anomalía de formato",
      action = if (variable == "id_persona")
        sprintf("Se verificó y normalizó el identificador; %d valores con espacios corregidos.", afectados)
      else sprintf("Se verificó el tipo numérico; %d valores convertidos y %d valores faltantes conservados.",
                   afectados, resumen$valores_faltantes[i]),
      justification = "Uniformidad de tipos para GMM/LOF; no se imputan faltantes ni se eliminan extremos en esta etapa.",
      affectedRows = as.integer(afectados),
      script = sprintf("apps/R/02_02_normalizacion.R [entrada=%s; variable=%s]", hash_entrada, variable)
    ))
  })

  # Leer todas las páginas, pues el endpoint solo devuelve 100 por solicitud.
  pagina <- 1L
  existentes <- list()
  repeat {
    respuesta <- api_obtener_bitacora(pagina = pagina, limite = 100L, api_base = api_base)
    existentes <- c(existentes, split(respuesta$entries, seq_len(nrow(respuesta$entries))))
    if (pagina >= respuesta$pagination$pages) break
    pagina <- pagina + 1L
  }
  scripts_existentes <- vapply(existentes, function(e) as.character(e$script), character(1))
  paso_siguiente <- if (length(existentes)) max(vapply(existentes, function(e) as.integer(e$stepNumber), integer(1))) + 1L else 1L
  for (i in seq_along(operaciones)) {
    op <- operaciones[[i]]
    if (op$script %in% scripts_existentes) next
    op$stepNumber <- paso_siguiente
    creado <- api_crear_bitacora(op, api_base = api_base)
    confirmado <- api_solicitud("GET", sprintf("/api/logs/%s", creado$id), api_base = api_base)
    if (!identical(as.character(confirmado$script), op$script)) {
      stop("La API no confirmó la persistencia de la operación ", i, call. = FALSE)
    }
    paso_siguiente <- paso_siguiente + 1L
  }

  # Actualizar únicamente el bloque generado para esta etapa en el informe.
  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  informe <- normalizePath(informe, mustWork = FALSE)
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 02_02"
  fin <- "% FIN RESULTADOS 02_02"
  tabla <- paste(sprintf("%s & %s & %d & %d \\\\",
                         gsub("_", "\\_", resumen$variable, fixed = TRUE),
                         resumen$tipo_final, resumen$filas_afectadas,
                         resumen$valores_faltantes), collapse = "\n")
  bloque <- c(inicio,
    sprintf("Se verificaron %d filas y %d columnas. La normalización conservó las dimensiones y los identificadores únicos; se corrigieron %d espacios en identificadores y se convirtieron %d valores numéricos.",
            n_inicial, columnas_iniciales, n_trim, sum(conversiones)),
    "\\begin{table}[H]\\centering",
    "\\caption{Validación de formatos en las variables seleccionadas}",
    "\\begin{tabular}{llrr}\\toprule Variable & Tipo final & Conversiones & Faltantes \\\\ \\midrule",
    tabla,
    "\\bottomrule\\end{tabular}\\end{table}",
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/02_02_normalizacion/faltantes_tras_normalizacion.png}",
    "\\caption{Valores faltantes conservados tras la validación de formatos.}",
    "\\end{figure}",
    "La auditoría conservó los valores extremos y los faltantes para las etapas siguientes.",
    fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque 02_02 del informe incompleto.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("duplicados}", texto, fixed = TRUE))
    ancla <- if (length(anclas)) anclas[1] else NA_integer_
    if (is.na(ancla)) stop("No se encontró la sección de duplicados en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = ancla - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_02_02, "etapa") <- "02_02"
  attr(datos_02_02, "hash_entrada") <- hash_entrada
  cat(sprintf("Etapa 2.2 completa: %d filas, %d columnas, %d operaciones verificadas.\n",
              n_inicial, columnas_iniciales, length(operaciones)))
  datos_02_02
}

archivo_ejecutado <- sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE))
if (length(archivo_ejecutado) && basename(archivo_ejecutado[1]) == "02_02_normalizacion.R") {
  DIR_R <- dirname(normalizePath(archivo_ejecutado[1], mustWork = TRUE))
  eval(parse(file = file.path(DIR_R, "cliente_api.R")), envir = .GlobalEnv)
  variables <- c("id_persona", "ylab", "tothrs", "aestudio", "s1_03a", "yprilab", "phrs")
  datos_analisis <- data.table::fread(
    file.path(DIR_R, "ECE_1T2026.csv"), sep = ";", dec = ",",
    na.strings = c("", "NA", "N/A"), select = variables,
    encoding = "UTF-8", showProgress = FALSE
  )
  resultado_02_02 <- etapa_02_02(datos_analisis)
}

