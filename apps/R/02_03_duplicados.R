#!/usr/bin/env Rscript
# Etapa 2.3. Se ejecuta en la misma sesión R que 02_02_normalizacion.R.
# Los perfiles laborales iguales se conservan cuando id_persona es distinto.

etapa_02_03 <- function(datos_02_02, api_base = API_BASE_URL,
                        responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                        dataset_nombre = Sys.getenv("GMM_DATASET", "ECE_1T_2026")) {
  if (!identical(attr(datos_02_02, "etapa"), "02_02")) {
    stop("Ejecute primero etapa_02_02() en esta misma sesión R.", call. = FALSE)
  }
  datos_02_03 <- data.table::as.data.table(data.table::copy(datos_02_02))
  n_antes <- nrow(datos_02_03)
  p_antes <- ncol(datos_02_03)
  if (!"id_persona" %in% names(datos_02_03)) stop("Falta id_persona.", call. = FALSE)
  id <- as.character(datos_02_03$id_persona)
  vacios <- sum(is.na(id) | trimws(id) == "")
  repetidos_id <- sum(duplicated(id[!is.na(id) & trimws(id) != ""]))
  repetidos_exactos <- sum(duplicated(datos_02_03))
  variables <- c("ylab", "tothrs", "aestudio", "s1_03a", "yprilab", "phrs")
  perfiles_iguales <- sum(duplicated(datos_02_03[, ..variables]))
  if (vacios || repetidos_id || repetidos_exactos) {
    stop("Se detectaron identificadores vacíos/repetidos o filas exactas. Se requiere revisar la fuente antes de eliminar registros.", call. = FALSE)
  }

  ruta_r <- if (exists("DIR_R", inherits = TRUE)) DIR_R else file.path(getwd(), "apps", "R")
  ruta_salida <- file.path(ruta_r, "output", "02_03_duplicados")
  dir.create(ruta_salida, recursive = TRUE, showWarnings = FALSE)
  resumen <- data.frame(
    verificacion = c("ID vacíos", "ID repetidos", "Filas exactas", "Perfiles coincidentes en seis variables"),
    casos = c(vacios, repetidos_id, repetidos_exactos, perfiles_iguales),
    decision = c("No requiere acción", "No requiere acción", "No requiere acción", "Conservar: personas distintas"),
    stringsAsFactors = FALSE
  )
  data.table::fwrite(resumen, file.path(ruta_salida, "resumen_duplicados.csv"))
  grDevices::png(file.path(ruta_salida, "verificacion_duplicados.png"), width = 1000, height = 600)
  graphics::barplot(resumen$casos, names.arg = c("ID vacíos", "ID repetidos", "Filas exactas", "Perfiles iguales"),
                    col = "#6557d9", las = 2, main = "Verificación de duplicados en la ECE", ylab = "Registros")
  grDevices::dev.off()

  hash_entrada <- digest::digest(datos_02_03[, c("id_persona", variables), with = FALSE], algo = "sha256")
  base <- list(
    responsible = responsable, dataset = dataset_nombre,
    methodology = "KDD - 2.3 Gestión de duplicados",
    datasetImpact = sprintf("%d filas y %d columnas antes / %d filas y %d columnas después",
                            n_antes, p_antes, nrow(datos_02_03), ncol(datos_02_03)),
    justification = "id_persona es único; la igualdad de los seis atributos laborales no identifica a una misma persona. No se eliminan observaciones válidas."
  )
  operaciones <- list(
    c(base, list(variable = "id_persona", problemType = "verificación de duplicados",
                 action = sprintf("Se comprobaron %d identificadores: %d vacíos y %d repetidos.", n_antes, vacios, repetidos_id),
                 affectedRows = 0L,
                 script = sprintf("apps/R/02_03_duplicados.R [entrada=%s; control=id]", hash_entrada))),
    c(base, list(variable = "(registro completo)", problemType = "verificación de duplicados",
                 action = sprintf("Se detectaron %d filas idénticas incluyendo id_persona; no se eliminaron filas.", repetidos_exactos),
                 affectedRows = 0L,
                 script = sprintf("apps/R/02_03_duplicados.R [entrada=%s; control=fila]", hash_entrada))),
    c(base, list(variable = "(seis variables del modelo)", problemType = "coincidencia de perfil",
                 action = sprintf("Se detectaron %d perfiles laborales coincidentes con id_persona distinto; se conservaron todas las personas.", perfiles_iguales),
                 affectedRows = 0L,
                 script = sprintf("apps/R/02_03_duplicados.R [entrada=%s; control=perfil]", hash_entrada)))
  )

  pagina <- 1L
  existentes <- list()
  repeat {
    respuesta <- api_obtener_bitacora(pagina = pagina, limite = 100L, api_base = api_base)
    if (NROW(respuesta$entries)) {
      existentes <- c(existentes, split(respuesta$entries, seq_len(NROW(respuesta$entries))))
    }
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
    if (!identical(confirmado$script, op$script)) stop("No se confirmó la persistencia de una verificación.", call. = FALSE)
    siguiente <- siguiente + 1L
  }

  informe <- file.path(ruta_r, "..", "..", "docs", "informe.tex")
  texto <- readLines(informe, warn = FALSE, encoding = "UTF-8")
  inicio <- "% INICIO RESULTADOS 02_03"
  fin <- "% FIN RESULTADOS 02_03"
  bloque <- c(inicio,
    sprintf("Se verificaron %d registros y %d columnas: %d identificadores vacíos, %d identificadores repetidos y %d filas idénticas incluyendo el identificador. Hay %d coincidencias en las seis variables laborales; pertenecen a personas distintas y se conservaron. La etapa terminó con %d filas y %d columnas.",
            n_antes, p_antes, vacios, repetidos_id, repetidos_exactos, perfiles_iguales,
            nrow(datos_02_03), ncol(datos_02_03)),
    "\\begin{figure}[H]\\centering",
    "\\includegraphics[width=0.75\\textwidth]{../apps/R/output/02_03_duplicados/verificacion_duplicados.png}",
    "\\caption{Comprobación de identificadores, filas y perfiles coincidentes.}",
    "\\end{figure}", fin)
  if (inicio %in% texto) {
    a <- match(inicio, texto); b <- match(fin, texto)
    if (is.na(b) || b < a) stop("Bloque 02_03 incompleto en el informe.", call. = FALSE)
    texto <- c(texto[seq_len(a - 1L)], bloque, if (b < length(texto)) texto[(b + 1L):length(texto)])
  } else {
    anclas <- which(grepl("valores faltantes (Missing Data)", texto, fixed = TRUE))
    if (!length(anclas)) stop("No se encontró la sección siguiente en informe.tex.", call. = FALSE)
    texto <- append(texto, c(bloque, ""), after = anclas[1] - 1L)
  }
  writeLines(texto, informe, useBytes = TRUE)
  attr(datos_02_03, "etapa") <- "02_03"
  cat(sprintf("Etapa 2.3 completa: %d perfiles coincidentes conservados; %d entradas verificadas.\n",
              perfiles_iguales, length(operaciones)))
  datos_02_03
}
