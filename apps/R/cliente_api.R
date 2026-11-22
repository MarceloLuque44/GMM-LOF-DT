#!/usr/bin/env Rscript
# =============================================================================
# Cliente de la API GMM para scripts R
# -----------------------------------------------------------------------------
# Variable de entorno:
#   GMM_API_URL=http://localhost:3001
#
# Este archivo puede usarse de forma independiente o mediante source().
# =============================================================================

.paquetes_api <- c("httr2", "jsonlite")
.faltan_api <- .paquetes_api[!vapply(.paquetes_api, requireNamespace, logical(1), quietly = TRUE)]
if (length(.faltan_api)) {
  stop(
    "Faltan paquetes para consumir la API: ", paste(.faltan_api, collapse = ", "),
    ". Instálelos con install.packages(c(",
    paste(sprintf('"%s"', .faltan_api), collapse = ", "), ")).",
    call. = FALSE
  )
}

API_BASE_URL <- sub("/+$", "", Sys.getenv("GMM_API_URL", "http://localhost:3001"))

api_solicitud <- function(metodo = "GET", ruta, cuerpo = NULL,
                          api_base = API_BASE_URL, timeout_seg = 15) {
  ruta <- paste0("/", sub("^/+", "", ruta))
  req <- httr2::request(paste0(sub("/+$", "", api_base), ruta)) |>
    httr2::req_method(toupper(metodo)) |>
    httr2::req_headers(Accept = "application/json") |>
    httr2::req_timeout(timeout_seg)

  if (!is.null(cuerpo)) {
    req <- req |>
      httr2::req_body_json(cuerpo, auto_unbox = TRUE, null = "null")
  }

  respuesta <- httr2::req_perform(req)
  httr2::resp_check_status(respuesta)
  if (httr2::resp_status(respuesta) == 204L) return(invisible(NULL))
  httr2::resp_body_json(respuesta, simplifyVector = TRUE)
}

api_estado <- function(api_base = API_BASE_URL) {
  api_solicitud("GET", "/api/health", api_base = api_base)
}

api_obtener_observaciones <- function(pagina = 1L, limite = 100L,
                                      atipicas = NULL, api_base = API_BASE_URL) {
  query <- sprintf("page=%d&limit=%d", as.integer(pagina), as.integer(limite))
  if (!is.null(atipicas)) query <- paste0(query, "&anomalous=", tolower(as.character(atipicas)))
  api_solicitud("GET", paste0("/api/observations?", query), api_base = api_base)
}

api_obtener_variables_modelo <- function(pagina = 1L, limite = 100L,
                                         api_base = API_BASE_URL) {
  ruta <- sprintf("/api/model-variables?page=%d&limit=%d", as.integer(pagina), as.integer(limite))
  api_solicitud("GET", ruta, api_base = api_base)
}

api_obtener_bitacora <- function(pagina = 1L, limite = 200L,
                                 api_base = API_BASE_URL) {
  ruta <- sprintf("/api/logs?page=%d&limit=%d", as.integer(pagina), as.integer(limite))
  api_solicitud("GET", ruta, api_base = api_base)
}

api_crear_bitacora <- function(entrada, api_base = API_BASE_URL) {
  api_solicitud("POST", "/api/logs", cuerpo = entrada, api_base = api_base)
}

# Guarda identificadores y respuestas de lectura verificables para cada etapa.
api_registrar_respuestas <- function(ruta, api_base = API_BASE_URL) {
  pagina <- 1L
  paginas <- list()
  repeat {
    respuesta <- api_obtener_bitacora(pagina = pagina, limite = 100L, api_base = api_base)
    paginas[[pagina]] <- respuesta$entries
    if (pagina >= respuesta$pagination$pages) break
    pagina <- pagina + 1L
  }
  entradas <- data.table::rbindlist(paginas, fill = TRUE)
  entradas <- entradas[grepl("^apps/R/(02_|03_|04_|05_)", script)]
  if (!nrow(entradas)) stop("No se encontraron respuestas de etapas en la API.", call. = FALSE)
  registro <- entradas[, .(
    id_api = id, paso = stepNumber, fecha_hora_api = executedAt,
    script, respuesta = "persistido y leído desde GET /api/logs"
  )]
  data.table::fwrite(registro, ruta)
  invisible(registro)
}

crear_entrada_perfilado <- function(variable, n_na, pct_na, n_registros,
                                    reporte, responsable, dataset) {
  problema <- if (n_na > 0) "valor nulo" else "sin valores nulos"
  criterio <- if (pct_na > 50) {
    sprintf("La variable presenta %.2f %% de valores faltantes y supera el umbral de revisión del 50 %%.", pct_na)
  } else if (n_na > 0) {
    sprintf("La variable presenta %.2f %% de valores faltantes; debe evaluarse si son NA estructurales antes de imputar.", pct_na)
  } else {
    "La variable no presenta valores faltantes; se conserva para las siguientes etapas."
  }

  list(
    stepNumber = 1L,
    responsible = responsable,
    dataset = dataset,
    variable = variable,
    problemType = problema,
    methodology = "KDD - selección y auditoría inicial",
    action = sprintf("Perfilado de completitud: %s valores faltantes (%.2f %%); no se modificaron datos.", n_na, pct_na),
    justification = criterio,
    affectedRows = as.numeric(n_na),
    datasetImpact = sprintf("%s registros antes / %s registros después (auditoría sin modificación)", n_registros, n_registros),
    script = sprintf("apps/R/perfilado_inicial.R::perfilar_variables(); reporte: %s", normalizePath(reporte, winslash = "/", mustWork = FALSE))
  )
}

#' Envía los resultados del perfilado a gmm.bitacora mediante la API.
#'
#' Los fallos de red o de configuración se informan como advertencias y no
#' invalidan los archivos y gráficos que ya generó el perfilado.
sincronizar_perfilado_bitacora <- function(perfil, n_registros, duplicados,
                                           reporte,
                                           responsable = Sys.getenv("GMM_RESPONSABLE", "Marcelo Luque Tarqui"),
                                           dataset = Sys.getenv("GMM_DATASET", "ECE_1T_2026"),
                                           api_base = API_BASE_URL) {
  estado <- tryCatch(api_estado(api_base), error = identity)
  if (inherits(estado, "error")) {
    warning("No se pudo conectar con la API en ", api_base, ": ", conditionMessage(estado), call. = FALSE)
    return(invisible(list(enviadas = 0L, fallidas = nrow(perfil), errores = conditionMessage(estado))))
  }

  bitacora_actual <- tryCatch({
    pagina <- 1L
    paginas <- list()
    repeat {
      actual <- api_obtener_bitacora(pagina = pagina, limite = 100L, api_base = api_base)
      paginas[[pagina]] <- actual$entries
      if (pagina >= actual$pagination$pages) break
      pagina <- pagina + 1L
    }
    list(entries = data.table::rbindlist(paginas, fill = TRUE))
  }, error = identity)
  if (inherits(bitacora_actual, "error")) {
    warning("La API responde, pero no se pudo consultar la bitácora: ", conditionMessage(bitacora_actual), call. = FALSE)
    return(invisible(list(enviadas = 0L, fallidas = nrow(perfil), errores = conditionMessage(bitacora_actual))))
  }

  pasos_existentes <- suppressWarnings(as.integer(bitacora_actual$entries$stepNumber))
  pasos_existentes <- pasos_existentes[!is.na(pasos_existentes)]
  siguiente_paso <- if (length(pasos_existentes)) max(pasos_existentes) + 1L else 1L

  entradas <- lapply(seq_len(nrow(perfil)), function(i) {
    crear_entrada_perfilado(
      variable = as.character(perfil$variable[i]),
      n_na = as.numeric(perfil$n_na[i]),
      pct_na = as.numeric(perfil$pct_na[i]),
      n_registros = n_registros,
      reporte = reporte,
      responsable = responsable,
      dataset = dataset
    )
  })

  if (duplicados > 0) {
    entradas[[length(entradas) + 1L]] <- list(
      stepNumber = 1L,
      responsible = responsable,
      dataset = dataset,
      variable = "(seis variables del modelo)",
      problemType = "coincidencia de perfil",
      methodology = "KDD - selección y auditoría inicial",
      action = sprintf("Detección de %s perfiles iguales en las seis variables; no se eliminaron registros.", duplicados),
      justification = "Coincidir en seis variables no implica identidad personal; contrastar id_persona antes de decidir si hay duplicados.",
      affectedRows = 0L,
      datasetImpact = sprintf("%s registros antes / %s registros después (auditoría sin modificación)", n_registros, n_registros),
      script = "apps/R/perfilado_inicial.R::resumir_perfil()"
    )
  }

  errores <- character()
  enviadas <- 0L
  omitidas <- 0L
  for (i in seq_along(entradas)) {
    entrada <- entradas[[i]]
    previo <- bitacora_actual$entries[
      dataset == entrada$dataset & variable == entrada$variable &
        problemType == entrada$problemType &
        as.numeric(affectedRows) == entrada$affectedRows
    ]
    if (nrow(previo)) {
      omitidas <- omitidas + 1L
      next
    }
    entrada$stepNumber <- siguiente_paso
    resultado <- tryCatch({
      creado <- api_crear_bitacora(entrada, api_base)
      confirmado <- api_solicitud("GET", sprintf("/api/logs/%s", creado$id), api_base = api_base)
      if (!identical(confirmado$variable, entrada$variable) ||
          as.numeric(confirmado$affectedRows) != entrada$affectedRows) {
        stop("La API no confirmó la persistencia")
      }
      confirmado
    }, error = identity)
    if (inherits(resultado, "error")) {
      errores <- c(errores, sprintf("Entrada %d (%s): %s", i, entradas[[i]]$variable, conditionMessage(resultado)))
    } else {
      enviadas <- enviadas + 1L
      siguiente_paso <- siguiente_paso + 1L
    }
  }

  if (length(errores)) warning(paste(errores, collapse = "\n"), call. = FALSE)
  cat(sprintf("\nBitácora API: %d enviada(s), %d ya existente(s), %d fallida(s) · %s\n",
              enviadas, omitidas, length(errores), api_base))
  invisible(list(enviadas = enviadas, omitidas = omitidas, fallidas = length(errores), errores = errores))
}
