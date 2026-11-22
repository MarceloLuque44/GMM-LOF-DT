#!/usr/bin/env Rscript
# =============================================================================
# PROYECTO GMM · ECE 1T2026 (INE Bolivia)
# PASO 1 · AUDITORÍA Y PERFILADO INICIAL (DATA PROFILING)
# -----------------------------------------------------------------------------
# Este script implementa el primer paso de "Estructura informe.md":
#   - Inspección de tipos de datos (numéricas, texto, fechas, lógicas)
#   - Estadísticas descriptivas (mín., máx., media, mediana y NA por columna)
#   - Cardinalidad de variables categóricas
#   - Lista inicial de anomalías a corregir en pasos posteriores
#
# Además genera 8 gráficos exploratorios aplicables a las seis variables,
# con el texto descriptivo (pregunta + lectura + hallazgos) DEBAJO de
# cada figura en un reporte HTML autocontenido.
#
# Uso:
#   Rscript apps/R/perfilado_inicial.R
#   Rscript apps/R/perfilado_inicial.R ruta/al/ECE_1T2026.csv ruta/de/salida
#
# Salidas:
#   apps/R/output/perfilado/reporte_perfilado.html
#   apps/R/output/perfilado/perfil_variables.csv
#   apps/R/output/perfilado/figuras/*.png
# =============================================================================

options(encoding = "UTF-8", stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
  library(tidyr)
  library(gridExtra)
})

.paquetes <- c("data.table", "ggplot2", "scales", "tidyr", "gridExtra", "e1071", "base64enc")
.faltan <- .paquetes[!vapply(.paquetes, requireNamespace, logical(1), quietly = TRUE)]
if (length(.faltan)) {
  stop("Faltan paquetes requeridos: ", paste(.faltan, collapse = ", "),
       ". Instálelos con install.packages(c(",
       paste(sprintf('"%s"', .faltan), collapse = ", "), ")).", call. = FALSE)
}

# -----------------------------------------------------------------------------
# 0. CONFIGURACIÓN
# -----------------------------------------------------------------------------

args_full <- commandArgs(trailingOnly = FALSE)

.ruta_script <- function() {
  f <- sub("^--file=", "", grep("^--file=", args_full, value = TRUE))
  if (length(f)) dirname(normalizePath(f[1], mustWork = FALSE)) else getwd()
}

DIR_R       <- .ruta_script()
DIR_SALIDA  <- file.path(DIR_R, "output", "perfilado")
DIR_FIG     <- file.path(DIR_SALIDA, "figuras")

SEMILLA <- 20261
set.seed(SEMILLA)

# Variables declaradas en docs/informe.tex, en el mismo orden de la tabla.
# Esta es la única selección usada por el perfilado, GMM y LOF.
VARS_NUM <- c(
  "ylab",     # Ingreso laboral mensual total (Bs)
  "tothrs",   # Total horas semanales habituales (todas ocupaciones)
  "aestudio", # Años de escolaridad acumulados
  "s1_03a",   # Edad cumplida en años
  "yprilab",  # Ingreso laboral mensual de ocupación principal (Bs)
  "phrs"      # Horas semanales habituales en ocupación principal
)

# Variables categóricas para el gráfico de frecuencias.
VARS_CAT <- c("depto", "area", "s1_02", "condact", "niv_ed",
              "tipohogar", "s1_16", "s2_18", "s2_26a")

# Paleta común
AZUL   <- "#1F4E79"
AZUL2  <- "#2E75B6"
ROJO   <- "#C0392B"
VERDE  <- "#2E7D5B"
GRIS   <- "#6B7785"
FONDO  <- "#F4F6F8"

TEMA_BASE <- theme_minimal(base_size = 10) +
  theme(
    plot.title       = element_text(face = "bold", colour = "#1B2631", size = 11),
    plot.subtitle    = element_text(colour = GRIS, size = 8.5, margin = margin(b = 6)),
    plot.caption     = element_text(colour = GRIS, size = 7.5, hjust = 0),
    axis.title       = element_text(colour = "#34495E", size = 8.5),
    axis.text        = element_text(colour = "#4D5656", size = 7.5),
    strip.background = element_rect(fill = "#E5EAF0", colour = NA),
    strip.text       = element_text(face = "bold", colour = "#1B2631", size = 8.5),
    panel.grid.minor = element_blank(),
    panel.grid.major = element_line(colour = "#DDE3EA", linewidth = 0.3),
    legend.title     = element_text(size = 8),
    legend.text      = element_text(size = 7.5),
    plot.background  = element_rect(fill = "white", colour = NA)
  )

# Etiquetas legibles para variables
ETIQ_VARS <- c(
  s1_03a = "Edad (a\u00f1os)",
  aestudio = "A\u00f1os de estudio",
  s2_26 = "N° de trabajadores",
  phrs = "Horas semanales habituales",
  tothrs = "Horas semanales totales",
  yprilab = "Ingreso laboral principal (Bs)",
  ylab = "Ingreso laboral total (Bs)",
  s2_33_v = "Salario líquido (Bs)",
  s2_37_v = "Ingreso bruto independiente (Bs)",
  s2_38_v = "Ingreso neto independiente (Bs)",
  s2_28 = "Días trabajados por semana",
  s2_29_h = "Horas trabajadas al día",
  depto = "Departamento",
  area = "Área de residencia",
  s1_02 = "Sexo",
  condact = "Condición de actividad",
  niv_ed = "Nivel educativo",
  tipohogar = "Tipo de hogar",
  s1_16 = "Estado civil",
  s2_18 = "Categoría ocupacional",
  s2_26a = "Rango de trabajadores",
  s1_14 = "Razón de inasistencia",
  s2_06 = "Razón de no búsqueda",
  s2_07 = "Condición de inactividad",
  s2_25 = "Lugar de trabajo"
)

# Etiquetas de valores para las categorías más usadas
ETIQ_VALORES <- list(
  depto = c("1" = "Chuquisaca", "2" = "La Paz", "3" = "Cochabamba",
            "4" = "Oruro", "5" = "Potosí", "6" = "Tarija",
            "7" = "Santa Cruz", "8" = "Beni", "9" = "Pando"),
  area = c("1" = "Urbana", "2" = "Rural"),
  s1_02 = c("1" = "Hombre", "2" = "Mujer"),
  condact = c("1" = "Ocupado", "2" = "Desocupado cesante",
              "3" = "Desocupado aspirante", "4" = "Inactivo"),
  niv_ed = c("0" = "Ninguno/alfabetización", "1" = "Primaria",
             "2" = "Secundaria", "3" = "Técnico", "4" = "Superior"),
  tipohogar = c("1" = "Unipersonal", "2" = "Nuclear", "3" = "Extenso",
                "4" = "Compuesto", "5" = "Sin núcleo"),
  s1_16 = c("1" = "Soltero/a", "2" = "Casado/a", "3" = "Conviviente",
            "4" = "Separado/a", "5" = "Divorciado/a", "6" = "Viudo/a"),
  s2_18 = c("1" = "Obrero/empleado", "2" = "Cuenta propia", "3" = "Empleador",
            "4" = "Cooperativista", "5" = "Familiar no remunerado",
            "6" = "Aprendiz", "7" = "Empleada del hogar"),
  s2_26a = c("1" = "1 persona", "2" = "2-5", "3" = "6-10", "4" = "11-20",
             "5" = "21-30", "6" = "31-50", "7" = "51-100", "8" = "101 o más")
)

etiqueta_var <- function(v) {
  v <- as.character(v)
  out <- unname(ETIQ_VARS[v])
  faltan <- is.na(out)
  out[faltan] <- v[faltan]
  out
}

etiqueta_valores <- function(x, v) {
  out <- rep(NA_character_, length(x))
  ok <- !is.na(x)
  out[ok] <- if (is.numeric(x)) {
    trimws(format(x[ok], trim = TRUE, scientific = FALSE))
  } else {
    as.character(x[ok])
  }
  lab <- ETIQ_VALORES[[v]]
  if (!is.null(lab)) {
    idx <- !is.na(out) & out %in% names(lab)
    out[idx] <- unname(lab[out[idx]])
  }
  out
}

# Porcentaje de NA de una variable (para mostrarlo en los gráficos)
pct_na_var <- function(dt, v) {
  x <- dt[[v]]
  if (!length(x)) return(0)
  round(100 * sum(is.na(x)) / length(x), 2)
}

# -----------------------------------------------------------------------------
# 1. LECTURA E INSPECCIÓN
# -----------------------------------------------------------------------------

#' Algunas líneas del CSV traen bytes Windows-1252 mezclados con UTF-8
#' (nombres de establecimientos). Se reparan antes de parsear para evitar
#' cadenas inválidas.
reparar_encoding_archivo <- function(ruta) {
  bytes <- readBin(ruta, what = "raw", n = file.info(ruta)$size)
  nl    <- which(bytes == as.raw(0x0A))
  cortes <- c(0L, nl, length(bytes) + 1L)

  segs <- lapply(seq_len(length(cortes) - 1L), function(i) {
    ini <- cortes[i] + 1L
    fin <- cortes[i + 1L] - 1L
    if (fin < ini) return(raw(0))
    seg <- bytes[ini:fin]
    if (length(seg) && seg[length(seg)] == as.raw(0x0D)) seg <- seg[-length(seg)]
    seg
  })
  if (length(segs) && length(segs[[length(segs)]]) == 0) {
    segs <- segs[-length(segs)]
  }

  vapply(segs, function(seg) {
    s <- rawToChar(seg)
    if (validUTF8(s)) {
      Encoding(s) <- "UTF-8"
      s
    } else {
      # 7 líneas traen comillas/° en Windows-1252
      iconv(list(seg), from = "CP1252", to = "UTF-8", sub = "")
    }
  }, character(1), USE.NAMES = FALSE)
}

#' Lee el CSV de la ECE (separador ';', decimal ',').
leer_ece <- function(ruta) {
  if (!file.exists(ruta)) stop("No se encontró el archivo: ", ruta, call. = FALSE)

  lineas <- reparar_encoding_archivo(ruta)
  tmp <- tempfile(fileext = ".csv")
  con <- file(tmp, open = "wb")
  writeLines(lineas, con, useBytes = TRUE)
  close(con)
  on.exit(unlink(tmp), add = TRUE)

  dt <- fread(
    tmp,
    sep = ";",
    dec = ",",
    na.strings = c("", "NA", "N/A"),
    encoding = "UTF-8",
    showProgress = FALSE,
    check.names = FALSE
  )

  # Cabeceras y textos: limpiar espacios al inicio/fin
  setnames(dt, trimws(names(dt)))
  cols_char <- names(dt)[vapply(dt, is.character, logical(1))]
  if (length(cols_char)) {
    dt[, (cols_char) := lapply(.SD, function(x) {
      x <- trimws(x)
      x[x == ""] <- NA_character_
      x
    }), .SDcols = cols_char]
  }

  # Las columnas que quedaron 100 % vacías se leen como logical; se informa
  # en el perfil y se mantienen para el mapa de faltantes.
  dt[]
}

#' Muestra dimensiones, cabeceras, tipos de datos y primeras filas.
inspeccionar_estructura <- function(dt, n_filas = 6, n_cols_vista = 12) {
  cat("\n", strrep("=", 78), "\n", sep = "")
  cat("1. INSPECCIÓN DE ESTRUCTURA\n")
  cat(strrep("=", 78), "\n", sep = "")

  cat(sprintf("Dimensiones: %s filas x %s columnas\n",
              format(nrow(dt), big.mark = ".", decimal.mark = ","),
              format(ncol(dt), big.mark = ".", decimal.mark = ",")))
  cat(sprintf("Memoria aproximada: %.1f MB\n", as.numeric(object.size(dt)) / 1024^2))

  tipos <- vapply(dt, function(x) class(x)[1], character(1))
  cat("\nTipos de datos detectados:\n")
  print(table(tipos))

  cat("\nCabeceras (", ncol(dt), " columnas):\n", sep = "")
  cat(sprintf("%3d. %s\n", seq_along(names(dt)), names(dt)), sep = "")

  cat("\nPrimeras ", n_filas, " filas (primeras ",
      min(n_cols_vista, ncol(dt)), " columnas):\n", sep = "")
  print(dt[seq_len(min(n_filas, nrow(dt))), seq_len(min(n_cols_vista, ncol(dt))),
           with = FALSE])

  cat("\nValores únicos de las variables temporales:\n")
  for (v in intersect(c("gestion", "trimestre", "meses", "semana", "panel"), names(dt))) {
    vals <- sort(unique(dt[[v]]))
    if (length(vals) > 15) vals <- c(vals[1:15], NA)
    cat(sprintf("  %-10s : %s\n", v,
                paste(format(vals, trim = TRUE), collapse = ", ")))
  }

  invisible(tipos)
}

#' Construye la tabla de perfilado por variable: tipo, NA, cardinalidad,
#' estadísticos descriptivos y categoría modal.
perfilar_variables <- function(dt) {
  n <- nrow(dt)
  clases   <- vapply(dt, function(x) class(x)[1], character(1))
  n_na     <- vapply(dt, function(x) sum(is.na(x)), integer(1))
  n_unicos <- vapply(dt, function(x) uniqueN(x, na.rm = TRUE), integer(1))

  perfil <- data.table(
    variable   = names(dt),
    clase      = unname(clases),
    n_na       = unname(n_na),
    pct_na     = round(100 * n_na / n, 2),
    n_unicos   = unname(n_unicos),
    minimo     = NA_real_,
    maximo     = NA_real_,
    media      = NA_real_,
    mediana    = NA_real_,
    categoria_top = NA_character_,
    freq_top      = NA_integer_
  )

  for (v in names(dt)) {
    x <- dt[[v]]
    i <- match(v, perfil$variable)
    if (is.numeric(x)) {
      xv <- x[!is.na(x)]
      if (length(xv)) {
        perfil[i, `:=`(
          minimo  = min(xv),
          maximo  = max(xv),
          media   = mean(xv),
          mediana = median(xv)
        )]
        set(perfil, i, "media", round(mean(xv), 3))
      }
    }
    if ((!is.numeric(x) && !is.logical(x)) || uniqueN(x, na.rm = TRUE) <= 30) {
      xv <- x[!is.na(x)]
      if (length(xv)) {
        tb <- sort(table(xv), decreasing = TRUE)
        set(perfil, i, "categoria_top", as.character(names(tb)[1]))
        set(perfil, i, "freq_top", as.integer(tb[1]))
      }
    }
  }

  # Tipo sugerido para el perfilado
  perfil[, tipo_sugerido := fifelse(
    n_unicos == 0, "Vacía",
    fifelse(n_unicos == 1, "Constante",
      fifelse(grepl("^id_|_panel$", variable), "Identificador",
        fifelse(clase == "character" & n_unicos > 30, "Texto libre",
          fifelse(clase == "numeric" & n_unicos > 15, "Numérica",
            fifelse(clase == "logical", "Lógica", "Categórica"))))))
  ]

  perfil[]
}

#' Imprime un resumen ejecutivo del perfilado y detecta anomalías iniciales.
resumir_perfil <- function(dt, perfil) {
  n <- nrow(dt)
  cat("\n", strrep("=", 78), "\n", sep = "")
  cat("2. RESUMEN DEL PERFILADO\n")
  cat(strrep("=", 78), "\n", sep = "")

  cat(sprintf("Celdas faltantes: %s de %s (%.2f %%)\n",
              format(sum(perfil$n_na), big.mark = ".", decimal.mark = ","),
              format(n * ncol(dt), big.mark = ".", decimal.mark = ","),
              sum(perfil$n_na) / (n * ncol(dt)) * 100))
  cat(sprintf("Filas completas: %s de %s (%.2f %%)\n",
              format(sum(complete.cases(dt)), big.mark = ".", decimal.mark = ","),
              format(n, big.mark = ".", decimal.mark = ","),
              sum(complete.cases(dt)) / n * 100))
  cat(sprintf("Columnas sin ningún NA: %d de %d\n",
              sum(perfil$n_na == 0), ncol(dt)))
  cat(sprintf("Duplicados exactos: %s\n",
              format(sum(duplicated(dt)), big.mark = ".", decimal.mark = ",")))

  cat("\nVariables con mayor porcentaje de faltantes:\n")
  top <- perfil[order(-pct_na)][1:min(12, .N)]
  print(top[, .(variable, clase, pct_na, n_unicos)], row.names = FALSE)

  cat("\nVariables constantes o vacías:\n")
  const <- perfil[tipo_sugerido %in% c("Constante", "Vacía")]
  if (nrow(const)) print(const[, .(variable, clase, n_unicos, pct_na)], row.names = FALSE) else cat("  Ninguna.\n")

  cat("\nVariables candidatas a eliminar (> 50 % de NA):\n")
  alt <- perfil[pct_na > 50]
  cat(sprintf("  %d columnas: %s\n", nrow(alt), paste(alt$variable, collapse = ", ")))

  invisible(perfil)
}

# -----------------------------------------------------------------------------
# UTILIDADES DE GRÁFICOS
# -----------------------------------------------------------------------------

guardar_grafico <- function(objeto, nombre, ancho, alto, dpi = 130) {
  ruta <- file.path(DIR_FIG, nombre)
  if (inherits(objeto, "ggplot")) {
    ggsave(ruta, plot = objeto, width = ancho, height = alto,
           dpi = dpi, bg = "white", limitsize = FALSE)
  } else {
    png(ruta, width = ancho, height = alto, units = "in", res = dpi, bg = "white")
    grid::grid.draw(objeto)
    dev.off()
  }
  ruta
}

# Calcula un lienzo proporcional al contenido. Evita barras demasiado gruesas
# y paneles comprimidos cuando cambia la cantidad de variables o categorías.
dimensiones_paneles <- function(n, ncol = 3, ancho_panel = 4.2,
                                alto_panel = 3.1, extra_alto = 1.1) {
  n <- max(1L, as.integer(n))
  ncol <- max(1L, min(as.integer(ncol), n))
  nfilas <- ceiling(n / ncol)
  c(
    ancho = max(6, ncol * ancho_panel),
    alto = max(4.5, nfilas * alto_panel + extra_alto)
  )
}

dimensiones_barras <- function(etiquetas, alto_barra = 0.48,
                               ancho_min = 7, alto_min = 4.2) {
  etiquetas <- as.character(etiquetas)
  largo_max <- if (length(etiquetas)) max(nchar(etiquetas), na.rm = TRUE) else 0
  c(
    ancho = max(ancho_min, min(13, 7 + 0.055 * largo_max)),
    alto = max(alto_min, 2.5 + alto_barra * length(etiquetas))
  )
}

# Cantidad de modos (máximos locales) de una densidad
contar_modos <- function(x) {
  x <- x[is.finite(x)]
  if (length(unique(x)) < 3) return(1L)
  d <- tryCatch(density(x, n = 512), error = function(e) NULL)
  if (is.null(d)) return(NA_integer_)
  sum(diff(sign(diff(d$y))) == -2)
}

# Construye la fecha semanal de referencia a partir de gestión/trimestre/semana
construir_fecha <- function(dt) {
  if (!all(c("gestion", "trimestre", "semana") %in% names(dt))) return(rep(as.Date(NA), nrow(dt)))
  inicio_trim <- as.Date(sprintf("%d-%02d-01",
                                 dt$gestion,
                                 (dt$trimestre - 1) * 3 + 1))
  inicio_trim + (dt$semana - 1) * 7
}

# -----------------------------------------------------------------------------
# BLOQUE 1 · ESTRUCTURA DEL DATASET
# -----------------------------------------------------------------------------

#' 1. Mapa de valores faltantes (Missing Values Heatmap)
grafico_mapa_faltantes <- function(dt, max_filas = 1200) {
  na_mat  <- is.na(dt)
  pct_col <- colMeans(na_mat) * 100
  n_na_col <- colSums(na_mat)
  vars <- names(dt)
  if (!length(vars)) stop("El dataset no tiene columnas.", call. = FALSE)

  tot_fila <- rowSums(na_mat)
  idx <- order(tot_fila, decreasing = TRUE)
  if (length(idx) > max_filas) {
    idx <- idx[round(seq(1, length(idx), length.out = max_filas))]
  }

  m <- na_mat[idx, vars, drop = FALSE]
  df <- data.frame(
    fila     = rep(seq_along(idx), times = length(vars)),
    variable = rep(vars, each = length(idx)),
    estado   = factor(ifelse(as.vector(m), "Faltante", "Presente"),
                      levels = c("Presente", "Faltante"))
  )
  df$variable <- factor(df$variable,
                        levels = vars[order(pct_col[vars])])

  # Etiquetas del eje x con porcentaje y cantidad de NA por variable
  etq_x <- sprintf("%s\n(NA %.1f %% - n=%s)", etiqueta_var(vars),
                   vapply(vars, function(v) pct_col[v], numeric(1)),
                   vapply(vars, function(v) comma(n_na_col[v], big.mark = ".", decimal.mark = ","), character(1)))
  names(etq_x) <- vars
  levels(df$variable) <- etq_x[levels(df$variable)]

  p <- ggplot(df, aes(x = variable, y = fila, fill = estado)) +
    geom_tile(width = 0.7) +
    scale_fill_manual(values = c("Presente" = "#E8EDF2", "Faltante" = ROJO),
                      name = NULL) +
    scale_y_reverse(expand = c(0, 0)) +
    labs(
      title = "Mapa de valores faltantes",
      subtitle = sprintf(
        "%d columnas totales - %s registros mostrados de %s (ordenados por cantidad de NA)",
        length(vars), format(length(idx), big.mark = ".", decimal.mark = ","),
        format(nrow(dt), big.mark = ".", decimal.mark = ",")),
      x = NULL, y = "Registros (ordenados por N° de NA)",
      caption = "Cada columna es una variable y cada fila un registro. El rojo indica valor faltante."
    ) +
    TEMA_BASE +
    theme(
      axis.text.x  = element_text(angle = 55, vjust = 1, hjust = 1, size = 8.5),
      axis.text.y  = element_blank(),
      panel.grid   = element_blank(),
      legend.position = "bottom"
    )

  dim <- c(
    ancho = max(7.5, min(16, 5.5 + 1.25 * length(vars))),
    alto = max(5, min(9, 4.5 + 0.002 * length(idx)))
  )
  img <- guardar_grafico(p, "01_mapa_faltantes.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  n_na_total  <- sum(na_mat)
  pct_celdas  <- n_na_total / length(na_mat) * 100
  comp_filas  <- sum(complete.cases(dt))
  pct_col_50  <- sum(pct_col > 50)
  top5 <- head(sort(pct_col, decreasing = TRUE), 5)

  hallazgos <- c(
    sprintf("Se concentran %s celdas faltantes (%.1f %% del total) en %d de %d columnas.",
            format(n_na_total, big.mark = ".", decimal.mark = ","), pct_celdas, length(vars), ncol(dt)),
    if (comp_filas == 0) {
      "Ninguna fila está completa: todos los registros tienen al menos un NA."
    } else {
      sprintf("Solo %s filas (%s %%) están completas; el resto tiene al menos un NA.",
              format(comp_filas, big.mark = ".", decimal.mark = ","),
              format(round(comp_filas / nrow(dt) * 100, 2), decimal.mark = ","))
    },
    "El patrón no es aleatorio: las ausencias se agrupan en bloques de preguntas filtradas (secciones s2_*) y en texto de especificación.",
    sprintf("Columnas con mayor ausencia: %s.",
            paste(sprintf("%s (%.1f %%)", names(top5), top5), collapse = ", ")),
    sprintf("%d columnas superan el 50 %% de NA (candidatas a eliminación según el paso 4).", pct_col_50)
  )

  list(
    id = "g1", numero = 1,
    titulo = "Mapa de valores faltantes (Missing Values Heatmap)",
    pregunta = "¿Los valores faltantes son aleatorios o se concentran en determinados grupos?",
    imagen = img,
    lectura = paste(
      "Cada columna representa una variable y cada fila un registro. El color rojo señala un valor",
      "faltante y el gris un valor presente. Las columnas se ordenaron de menor a mayor porcentaje de NA",
      "y las filas por cantidad de NA, de modo que los bloques rojos revelan preguntas que solo se",
      "formulan a subgrupos (por ejemplo, ocupados o desocupados) y no pérdida aleatoria."
    ),
    hallazgos = hallazgos
  )
}

#' 2. Barras de porcentaje de valores faltantes
grafico_barras_faltantes <- function(dt, top = NULL) {
  na_mat <- is.na(dt)
  pct <- sort(colMeans(na_mat) * 100, decreasing = TRUE)
  n_na <- colSums(na_mat)[names(pct)]
  if (!is.null(top)) {
    pct <- pct[seq_len(min(top, length(pct)))]
    n_na <- n_na[names(pct)]
  }

  df <- data.frame(variable = names(pct), pct = unname(pct),
                   n_na = unname(n_na))
  df$etiqueta <- factor(etiqueta_var(df$variable),
                        levels = rev(etiqueta_var(df$variable)))
  df$umbral <- factor(ifelse(df$pct > 50, "> 50 %", "<= 50 %"),
                      levels = c("<= 50 %", "> 50 %"))

  p <- ggplot(df, aes(x = pct, y = etiqueta, fill = umbral)) +
    geom_col(width = 0.58) +
    geom_vline(xintercept = 50, linetype = "dashed", colour = ROJO, linewidth = 0.5) +
    geom_text(aes(label = sprintf("%.1f %% (n=%s)", pct, comma(n_na, big.mark = ".", decimal.mark = ","))),
              hjust = -0.08, size = 2.3, colour = "#34495E") +
    scale_fill_manual(values = c("<= 50 %" = AZUL2, "> 50 %" = ROJO), name = NULL) +
    scale_x_continuous(expand = expansion(mult = c(0, 0.28)),
                       labels = label_number(suffix = " %", decimal.mark = ",")) +
    labs(
      title = "Porcentaje de valores faltantes por variable",
      subtitle = sprintf("%d variables totales - linea punteada = umbral de eliminacion (50 %%)", nrow(df)),
      x = "Porcentaje de NA", y = NULL,
      caption = "Ordenado de mayor a menor. Las barras rojas superan el umbral del 50 % definido en el informe."
    ) +
    TEMA_BASE +
    theme(
      axis.text.y = element_text(size = 7.4),
      panel.grid.major.y = element_blank(),
      legend.position = "top"
    )

  dim <- dimensiones_barras(as.character(df$etiqueta), ancho_min = 9)
  img <- guardar_grafico(p, "02_barras_faltantes.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  n50 <- sum(pct > 50); n20 <- sum(pct > 20); n5 <- sum(pct > 5)
  hallazgos <- c(
    sprintf("%d de %d variables presentan algún NA; %d superan el 50 %%, %d el 20 %% y %d el 5 %%.",
            length(pct), ncol(dt), n50, n20, n5),
    sprintf("Las más incompletas son %s.",
            paste(sprintf("%s (%.1f %%)", names(pct)[1:min(8, length(pct))],
                          pct[1:min(8, length(pct))]), collapse = ", ")),
    if (any(pct >= 99.99)) {
      sprintf("Variables con 100 %% de NA: %s; deben revisarse antes de continuar.",
              paste(names(pct)[pct >= 99.99], collapse = ", "))
    } else {
      "Ninguna de las variables seleccionadas tiene 100 % de valores faltantes."
    },
    "Las variables de ingreso y horas presentan NA estructurales (solo aplican a ocupados): no conviene imputarlas sin separar antes por condición de actividad."
  )

  list(
    id = "g2", numero = 2,
    titulo = "Barras de porcentaje de valores faltantes",
    pregunta = "¿Qué columnas presentan más problemas de completitud?",
    imagen = img,
    lectura = paste(
      "El gráfico ordena las variables según su porcentaje de NA. La línea punteada marca el 50 %,",
      "umbral a partir del cual el informe recomienda eliminar la columna. Este orden es la primera",
      "guía para decidir qué variables conservar y cuáles requieren imputación o descarte."
    ),
    hallazgos = hallazgos
  )
}

#' 3. Gráfico de frecuencias categóricas (panel con una barra por variable)
grafico_frecuencias_categoricas <- function(dt, vars = VARS_CAT) {
  vars <- intersect(vars, names(dt))
  if (!length(vars)) {
    stop("No hay variables categóricas seleccionadas para este perfilado.", call. = FALSE)
  }
  plots <- list()
  resumen <- list()

  for (v in vars) {
    x <- dt[[v]]
    cat_lab <- etiqueta_valores(x, v)
    cat_lab[is.na(cat_lab)] <- "Sin dato"

    tb <- as.data.frame(table(cat_lab), stringsAsFactors = FALSE)
    names(tb) <- c("categoria", "n")
    tb <- tb[tb$n > 0, ]
    tb$pct <- tb$n / sum(tb$n) * 100
    tb$poco_frecuente <- ifelse(tb$pct < 1, "Poco frecuente (< 1 %)", "Frecuente")
    tb <- tb[order(tb$n), ]
    tb$categoria <- factor(substr(tb$categoria, 1, 28),
                           levels = substr(tb$categoria, 1, 28))

    p <- ggplot(tb, aes(x = n, y = categoria, fill = poco_frecuente)) +
      geom_col(width = 0.58) +
      geom_text(aes(label = sprintf("%s (%.1f %%)", comma(n, big.mark = ".", decimal.mark = ","), pct)),
                hjust = -0.06, size = 2.2, colour = "#34495E") +
      scale_fill_manual(values = c("Frecuente" = AZUL2,
                                   "Poco frecuente (< 1 %)" = ROJO),
                        name = NULL) +
      scale_x_continuous(expand = expansion(mult = c(0, 0.42)),
                         labels = label_number(big.mark = ".", decimal.mark = ",")) +
      labs(title = etiqueta_var(v), x = "Registros", y = NULL) +
      TEMA_BASE +
      theme(
        plot.title = element_text(size = 8.6),
        axis.text = element_text(size = 6.3),
        panel.grid.major.y = element_blank(),
        legend.position = "none"
      )
    plots[[v]] <- p

    tb2 <- tb[order(-tb$n), ]
    pct_sd <- tb$pct[tb$categoria == "Sin dato"]
    if (!length(pct_sd)) pct_sd <- 0
    tb_sin <- tb2[tb2$categoria != "Sin dato", ]
    top_cat <- if (nrow(tb_sin)) tb_sin[1, ] else tb2[1, ]
    resumen[[v]] <- sprintf(
      "%s: %d categorías; la más frecuente es «%s» (%.1f %% de los casos); «Sin dato» = %.1f %%.",
      etiqueta_var(v), nrow(tb), as.character(top_cat$categoria), top_cat$pct,
      pct_sd[1]
    )
  }

  ncol_panel <- min(3L, length(plots))
  g <- arrangeGrob(grobs = plots, ncol = ncol_panel,
                   top = grid::textGrob(
                     "Frecuencias de variables categóricas",
                     gp = grid::gpar(fontsize = 13, fontface = "bold", col = "#1B2631")
                   ))
  max_categorias <- max(vapply(plots, function(p) nrow(p$data), integer(1)))
  dim <- dimensiones_paneles(length(plots), ncol = ncol_panel,
                            ancho_panel = 4.8,
                            alto_panel = max(3.2, 1.8 + 0.34 * max_categorias))
  img <- guardar_grafico(g, "03_frecuencias_categoricas.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  bajas <- names(which(vapply(vars, function(v) {
    tb <- table(etiqueta_valores(dt[[v]], v), useNA = "no")
    any(tb / sum(tb) < 0.01)
  }, logical(1))))

  hallazgos <- c(
    unlist(resumen, use.names = FALSE),
    sprintf("Categorías con menos del 1 %% de frecuencia aparecen en rojo; conviene agruparlas antes de modelar: %s.",
            paste(if (length(bajas)) etiqueta_var(bajas) else "ninguna", collapse = ", ")),
    "«Sin dato» se muestra como categoría explícita para no ocultar el peso real de la no respuesta."
  )

  list(
    id = "g3", numero = 3,
    titulo = "Gráfico de frecuencias categóricas",
    pregunta = "¿Existen categorías poco frecuentes, inconsistentes o dominantes?",
    imagen = img,
    lectura = paste(
      "Cada panel muestra el número de registros por categoría para una variable discreta. Las barras",
      "rojas señalan categorías con menos del 1 % de los casos, candidatas a agruparse en «Otra» o",
      "«Desconocido». «Sin dato» permite dimensionar la no respuesta de cada pregunta."
    ),
    hallazgos = hallazgos
  )
}

# -----------------------------------------------------------------------------
# BLOQUE 2 · VARIABLES NUMÉRICAS
# -----------------------------------------------------------------------------

#' 4. Histograma con curva de densidad
grafico_histogramas <- function(dt, vars = VARS_NUM) {
  vars <- intersect(vars, names(dt))
  df <- list(); metas <- list()

  for (v in vars) {
    x <- dt[[v]]; x <- x[is.finite(x)]
    skew <- tryCatch(e1071::skewness(x), error = function(e) NA_real_)
    if (length(x) >= 2) {
      qs <- quantile(x, c(0.005, 0.995), na.rm = TRUE)
      xp <- x[x >= qs[1] & x <= qs[2]]
    } else {
      xp <- x
    }
    df[[v]] <- data.frame(
      variable = sprintf("%s\n(n=%s - asim.=%.2f - NA %.1f %%)", etiqueta_var(v),
                         comma(length(x), big.mark = ".", decimal.mark = ","), skew,
                         pct_na_var(dt, v)),
      valor = xp
    )
    metas[[v]] <- c(n = length(x), skew = skew)
  }
  df <- do.call(rbind, df)
  if (!nrow(df)) stop("No hay variables numéricas válidas para histogramas.")
  df$variable <- factor(df$variable, levels = unique(df$variable))

  tiene_densidad <- any(vapply(metas, function(m) m["n"] >= 2, logical(1)))
  ncol_panel <- min(3L, length(vars))
  p <- ggplot(df, aes(x = valor)) +
    geom_histogram(aes(y = after_stat(density)), bins = 45,
                   fill = AZUL2, colour = "white", linewidth = 0.15, alpha = 0.85) +
    (if (tiene_densidad) geom_density(colour = ROJO, linewidth = 0.7) else NULL) +
    facet_wrap(~variable, scales = "free", ncol = ncol_panel,
               labeller = label_value) +
    labs(
      title = "Histogramas con curva de densidad",
      subtitle = "Forma de cada distribución: simetría, asimetría, colas y posibles múltiples picos",
      x = "Valor", y = "Densidad",
      caption = "Para visualizar la forma se recorta el eje al percentil 0,5–99,5; el texto reporta la asimetría calculada con todos los datos."
    ) +
    TEMA_BASE

  dim <- dimensiones_paneles(length(vars), ncol = ncol_panel)
  img <- guardar_grafico(p, "04_histogramas.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  fuertes <- names(which(vapply(metas, function(m) abs(m["skew"]) > 1, logical(1))))
  modos <- vapply(vars, function(v) {
    x <- dt[[v]]; x <- x[is.finite(x)]
    if (length(x) < 30) return(NA_integer_)
    contar_modos(x)
  }, integer(1))
  multimod <- names(modos)[!is.na(modos) & modos >= 2]

  hallazgos <- c(
    sprintf("Variables con asimetría fuerte (|asimetría| > 1): %s. Requieren transformación logarítmica o análisis con mediana antes de GMM.",
            paste(etiqueta_var(fuertes), collapse = ", ")),
    sprintf("Densidades con más de un pico local: %s. Sugieren posibles subpoblaciones, hipótesis que deberá validar el GMM.",
            if (length(multimod)) paste(etiqueta_var(multimod), collapse = ", ") else "ninguna clara"),
    sprintf("Tamaños de muestra por variable: %s.",
            paste(sprintf("%s=%s", etiqueta_var(vars), comma(vapply(vars, function(v) sum(is.finite(dt[[v]])), integer(1)), big.mark = ".", decimal.mark = ",")), collapse = ", ")),
    "Un histograma multimodal no demuestra una mezcla gaussiana: solo motiva la comparación de modelos con distinto número de componentes."
  )

  list(
    id = "g4", numero = 4,
    titulo = "Histograma con curva de densidad",
    pregunta = "¿Los datos parecen provenir de una distribución o de varias poblaciones?",
    imagen = img,
    lectura = paste(
      "El histograma muestra la frecuencia de los valores y la curva roja suaviza la densidad. Una forma",
      "simétrica sugiere una sola población; los picos múltiples o las colas largas sugieren mezclas o",
      "subgrupos. Es un insumo directo para decidir cuántas componentes probar en el GMM."
    ),
    hallazgos = hallazgos
  )
}

#' 5. Diagrama de caja y bigotes
grafico_boxplots <- function(dt, vars = VARS_NUM) {
  vars <- intersect(vars, names(dt))
  vars_log <- c("s2_26", "yprilab", "ylab")
  df <- list()
  for (v in vars) {
    x <- dt[[v]][is.finite(dt[[v]])]
    etq <- etiqueta_var(v)
    if (v %in% vars_log) {
      x <- log10(x + if (v == "s2_26") 1 else 0)
      etq <- paste0(etq, " (log10)")
    }
    etq <- sprintf("%s (n=%s - NA %.1f %%)", etq, comma(length(dt[[v]])), pct_na_var(dt, v))
    df[[v]] <- data.frame(variable = etq, valor = x)
  }
  df <- do.call(rbind, df)
  df$variable <- factor(df$variable, levels = unique(df$variable))

  ncol_panel <- min(3L, length(vars))
  p <- ggplot(df, aes(x = variable, y = valor)) +
    geom_boxplot(fill = AZUL2, colour = AZUL, alpha = 0.7, width = 0.55,
                 outlier.colour = ROJO, outlier.alpha = 0.18, outlier.size = 0.5) +
    stat_summary(fun = mean, geom = "point", shape = 18, size = 1.8,
                 colour = ROJO, show.legend = FALSE) +
    facet_wrap(~variable, scales = "free", ncol = ncol_panel,
               labeller = label_wrap_gen(width = 22)) +
    labs(
      title = "Diagramas de caja y bigotes",
      subtitle = "Caja = Q1–Q3 - línea central = mediana - rombo rojo = media - puntos = valores atípicos (IQR)",
      x = NULL, y = "Valor (log10 en variables marcadas)",
      caption = "El ingreso se grafica en log10 por su fuerte asimetría; los atípicos se cuantifican en la escala original."
    ) +
    TEMA_BASE +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())

  dim <- dimensiones_paneles(length(vars), ncol = ncol_panel,
                            alto_panel = 3.4)
  img <- guardar_grafico(p, "05_boxplots.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  out <- data.table(
    variable = vars,
    n = vapply(vars, function(v) sum(is.finite(dt[[v]])), integer(1)),
    outliers = vapply(vars, function(v) {
      x <- dt[[v]][is.finite(dt[[v]])]
      if (length(x) < 4) return(0L)
      q <- quantile(x, c(0.25, 0.75), names = FALSE)
      iqr <- q[2] - q[1]
      sum(x < q[1] - 1.5 * iqr | x > q[2] + 1.5 * iqr)
    }, integer(1))
  )
  out[, pct_out := round(100 * outliers / n, 2)]

  hallazgos <- c(
    sprintf("La variable con más atípicos es %s: %s casos (%.2f %% de sus datos válidos).",
            etiqueta_var(out[which.max(pct_out), variable]),
            comma(out[which.max(pct_out), outliers], big.mark = ".", decimal.mark = ","),
            out[which.max(pct_out), pct_out]),
    sprintf("Porcentaje de atípicos por IQR: %s.",
            paste(sprintf("%s=%.1f %%", etiqueta_var(out$variable), out$pct_out), collapse = ", ")),
    "Los atípicos de ingresos y horas suelen ser valores reales (trabajadores de altos ingresos o jornadas extensas), no errores: no deben eliminarse automáticamente.",
    "La media (rombo) se separa de la mediana en las variables asimétricas; refuerza la convención de usar mediana para imputar."
  )

  list(
    id = "g5", numero = 5,
    titulo = "Diagrama de caja y bigotes (Boxplot)",
    pregunta = "¿Existen observaciones demasiado alejadas del comportamiento central?",
    imagen = img,
    lectura = paste(
      "La caja abarca el rango intercuartílico (Q1–Q3) y la línea central es la mediana. Los bigotes",
      "llegan hasta 1,5 veces el IQR y los puntos rojos son observaciones fuera de ese rango. El rombo",
      "marca la media: cuando se aleja de la mediana, la distribución es asimétrica."
    ),
    hallazgos = hallazgos
  )
}

#' 6. Gráfico de violín
grafico_violines <- function(dt, vars = VARS_NUM) {
  vars <- intersect(vars, names(dt))
  df <- list()
  for (v in vars) {
    x <- dt[[v]][is.finite(dt[[v]])]
    df[[v]] <- data.frame(variable = sprintf("%s (n=%s - NA %.1f %%)", etiqueta_var(v), comma(length(dt[[v]])), pct_na_var(dt, v)), valor = x)
  }
  df <- do.call(rbind, df)
  df$variable <- factor(df$variable, levels = unique(df$variable))

  ncol_panel <- min(3L, length(vars))
  p <- ggplot(df, aes(x = variable, y = valor)) +
    geom_violin(scale = "width", trim = TRUE, fill = AZUL2,
                colour = AZUL, alpha = 0.45, linewidth = 0.3) +
    geom_boxplot(width = 0.13, fill = "white", colour = AZUL,
                 alpha = 0.85, outlier.shape = NA, linewidth = 0.3) +
    facet_wrap(~variable, scales = "free", ncol = ncol_panel,
               labeller = label_wrap_gen(width = 22)) +
    labs(
      title = "Gráficos de violín",
      subtitle = "Densidad (ancho del violín) + caja central con mediana y cuartiles",
      x = NULL, y = "Valor",
      caption = "El ancho del violín indica concentración de datos. Varios ensanchamientos sugieren varias concentraciones que el boxplot no distingue."
    ) +
    TEMA_BASE +
    theme(axis.text.x = element_blank(), axis.ticks.x = element_blank())

  dim <- dimensiones_paneles(length(vars), ncol = ncol_panel,
                            alto_panel = 3.5)
  img <- guardar_grafico(p, "06_violines.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  modos <- vapply(vars, function(v) {
    x <- dt[[v]][is.finite(dt[[v]])]
    if (length(x) < 30) return(NA_integer_)
    contar_modos(x)
  }, integer(1))
  multi <- names(modos)[!is.na(modos) & modos >= 2]

  hallazgos <- c(
    sprintf("Se detectan %d variables con dos o más concentraciones locales: %s.",
            length(multi),
            if (length(multi)) paste(etiqueta_var(multi), collapse = ", ") else "ninguna"),
    "Los violines de horas e ingresos muestran colas derechas: la mayoría se concentra en valores bajos y unos pocos casos se extienden hacia arriba.",
    "En variables con NA estructural (ingresos u horas), el violín describe solo a la subpoblación con dato y no al total de la encuesta."
  )

  list(
    id = "g6", numero = 6,
    titulo = "Gráfico de violín (Violin Plot)",
    pregunta = "¿Existen varias concentraciones de datos que un boxplot no permite distinguir?",
    imagen = img,
    lectura = paste(
      "El violín combina la densidad de los valores con la caja de cuartiles. Las zonas más anchas",
      "concentran más observaciones; varios ensanchamientos en un mismo violín sugieren subgrupos.",
      "A diferencia del boxplot, permite ver si la masa de datos es unimodal o multimodal."
    ),
    hallazgos = hallazgos
  )
}

# -----------------------------------------------------------------------------
# BLOQUE 3 · RELACIONES ENTRE VARIABLES
# -----------------------------------------------------------------------------

#' 7. Matriz de correlaciones
grafico_correlaciones <- function(dt, vars = VARS_NUM) {
  vars <- intersect(vars, names(dt))
  X <- as.data.frame(dt[, ..vars])
  if (ncol(X) < 2) stop("Se necesitan al menos dos variables numéricas para correlacionar.")

  mat <- cor(X, use = "pairwise.complete.obs")
  mat[is.na(mat)] <- 0
  hc  <- hclust(as.dist(1 - abs(mat)))
  ord <- colnames(mat)[hc$order]
  mat <- mat[ord, ord]

  df <- as.data.frame(as.table(mat))
  names(df) <- c("var1", "var2", "r")
  etq_ord <- sprintf("%s (n=%s - NA %.1f %%)", etiqueta_var(ord),
                     vapply(ord, function(v) comma(length(dt[[v]]), big.mark = ".", decimal.mark = ","), character(1)),
                     vapply(ord, function(v) pct_na_var(dt, v), numeric(1)))
  names(etq_ord) <- ord
  df$var1 <- factor(etq_ord[df$var1], levels = etq_ord)
  df$var2 <- factor(etq_ord[df$var2], levels = rev(etq_ord))
  p <- ggplot(df, aes(x = var1, y = var2, fill = r)) +
    geom_tile(colour = "white", linewidth = 0.7) +
    geom_text(aes(label = sprintf("%.2f", r)), size = 2.8, colour = "#1B2631") +
    scale_fill_gradient2(low = ROJO, mid = "#F7F9FB", high = AZUL,
                         midpoint = 0, limits = c(-1, 1), name = "r") +
    coord_fixed() +
    labs(
      title = "Matriz de correlaciones (Pearson)",
      subtitle = sprintf("%d variables numéricas - ordenadas por similitud (dendrograma jerárquico)", ncol(mat)),
      x = NULL, y = NULL,
      caption = "r = 1 implica redundancia perfecta; valores cercanos a 0 indican ausencia de relación lineal."
    ) +
    TEMA_BASE +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 7.5),
      axis.text.y = element_text(size = 7.5),
      panel.grid = element_blank()
    )

  lado <- max(7, min(14, 5.5 + 0.75 * length(ord)))
  img <- guardar_grafico(p, "07_correlaciones.png",
                         ancho = lado + 0.8, alto = lado)

  ut <- mat[upper.tri(mat)]
  pares <- which(upper.tri(mat), arr.ind = TRUE)
  det <- data.table(
    var1 = rownames(mat)[pares[, 1]],
    var2 = colnames(mat)[pares[, 2]],
    r = ut
  )[order(-abs(r))]

  redundantes <- det[abs(r) >= 0.9]
  negativas <- det[r < -0.3]
  hallazgos <- c(
    sprintf("Correlaciones más fuertes: %s.",
            paste(sprintf("%s–%s (r=%.2f)", etiqueta_var(det$var1[1:min(4, .N)]),
                          etiqueta_var(det$var2[1:min(4, .N)]), det$r[1:min(4, .N)]),
                  collapse = "; ")),
    if (nrow(redundantes)) {
      sprintf("Pares redundantes (|r| ≥ 0,90): %s. Conviene conservar solo una de las dos variables para GMM y LOF.",
              paste(sprintf("%s–%s (%.2f)", etiqueta_var(redundantes$var1),
                            etiqueta_var(redundantes$var2), redundantes$r), collapse = "; "))
    } else {
      "No hay pares con |r| ≥ 0,90: no se detecta redundancia lineal severa."
    },
    if (nrow(negativas)) {
      sprintf("Correlaciones negativas relevantes: %s.",
              paste(sprintf("%s–%s (%.2f)", etiqueta_var(negativas$var1),
                            etiqueta_var(negativas$var2), negativas$r), collapse = "; "))
    } else {
      "No hay correlaciones negativas relevantes (r < -0,30)."
    },
    "La correlación mide solo relaciones lineales; relaciones no lineales o grupos ocultos se exploran mejor con el gráfico de dispersión y el PCA."
  )

  list(
    id = "g7", numero = 7,
    titulo = "Matriz de correlaciones",
    pregunta = "¿Existen variables redundantes o relaciones fuertes entre atributos?",
    imagen = img,
    lectura = paste(
      "Cada celda contiene el coeficiente de Pearson entre dos variables. El azul indica relación",
      "positiva y el rojo relación negativa; los valores cercanos a cero no muestran relación lineal.",
      "Los pares con |r| ≥ 0,90 son redundantes y pueden eliminarse antes de aplicar GMM y LOF."
    ),
    hallazgos = hallazgos
  )
}

#' 8. Diagrama de dispersión para los pares con mayor correlación
grafico_dispersion <- function(dt, vars = VARS_NUM, n_pares = 4) {
  vars <- intersect(vars, names(dt))
  pares <- combn(vars, 2, simplify = FALSE)

  stats <- rbindlist(lapply(pares, function(pr) {
    x <- dt[[pr[1]]]; y <- dt[[pr[2]]]
    ok <- is.finite(x) & is.finite(y)
    data.table(var1 = pr[1], var2 = pr[2], n = sum(ok),
               r = if (sum(ok) > 100) cor(x[ok], y[ok]) else NA_real_)
  }))
  stats <- stats[!is.na(r)][order(-abs(r))]

  plots <- list()
  for (i in seq_len(nrow(stats))) {
    v1 <- stats$var1[i]; v2 <- stats$var2[i]
    d <- data.table(x = dt[[v1]], y = dt[[v2]])
    d <- d[is.finite(x) & is.finite(y)]
    qx <- quantile(d$x, c(0.005, 0.995), names = FALSE)
    qy <- quantile(d$y, c(0.005, 0.995), names = FALSE)
    # Submuestra para que loess y el PNG sean viables con decenas de miles de puntos
    if (nrow(d) > 5000) d <- d[sample.int(nrow(d), 5000)]

    plots[[i]] <- ggplot(d, aes(x = x, y = y)) +
      geom_point(alpha = 0.16, size = 0.35, colour = AZUL2) +
      geom_smooth(method = "loess", formula = y ~ x, span = 0.9,
                  colour = ROJO, fill = "#F5B7B1", linewidth = 0.6, se = TRUE) +
      coord_cartesian(xlim = qx, ylim = qy) +
      labs(
        title = sprintf("%s vs %s", etiqueta_var(v1), etiqueta_var(v2)),
        subtitle = sprintf("r = %.2f - n = %s", stats$r[i], comma(stats$n[i], big.mark = ".", decimal.mark = ",")),
        x = etiqueta_var(v1), y = etiqueta_var(v2)
      ) +
      TEMA_BASE +
      theme(plot.title = element_text(size = 9),
            plot.subtitle = element_text(size = 7.5))
  }

  ncol_panel <- min(3L, length(plots))
  g <- arrangeGrob(grobs = plots, ncol = ncol_panel,
                   top = grid::textGrob(
                     "Dispersión de los pares con mayor correlación",
                     gp = grid::gpar(fontsize = 13, fontface = "bold", col = "#1B2631")
                   ))
  dim <- dimensiones_paneles(length(plots), ncol = ncol_panel,
                            ancho_panel = 4.3, alto_panel = 3.6)
  img <- guardar_grafico(g, "08_dispersion.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  hallazgos <- c(
    sprintf("Pares graficados: %s.",
            paste(sprintf("%s–%s (r=%.2f, n=%s)", etiqueta_var(stats$var1),
                          etiqueta_var(stats$var2), stats$r,
                          comma(stats$n, big.mark = ".", decimal.mark = ",")), collapse = "; ")),
    "La curva roja es un ajuste loess: si se aparta de una recta, la relación no es lineal y la correlación subestima la asociación.",
    "Los puntos aislados en las esquinas son candidatos a anomalías multivariadas; el LOF permitirá cuantificarlos.",
    "La nube de puntos revela si la asociación proviene de un solo grupo o de varios; un cambio de pendiente puede indicar subpoblaciones."
  )

  list(
    id = "g8", numero = 8,
    titulo = "Diagrama de dispersión (Scatter Plot)",
    pregunta = "¿Hay combinaciones de valores inusuales aunque cada variable individual parezca normal?",
    imagen = img,
    lectura = paste(
      "Cada panel cruza dos variables numéricas y cada punto es una persona. Se grafican los cuatro",
      "pares con mayor correlación absoluta. La curva loess ayuda a detectar relaciones no lineales y",
      "los puntos alejados de la nube son candidatos a anomalías multivariadas para LOF."
    ),
    hallazgos = hallazgos
  )
}

#' 9. PCA (Análisis de Componentes Principales)
grafico_pca <- function(dt, vars = VARS_NUM) {
  vars <- intersect(vars, names(dt))
  X <- as.data.frame(dt[, ..vars])
  X <- X[complete.cases(X), , drop = FALSE]
  if (ncol(X) < 2) stop("No hay suficientes variables completas para el PCA.")

  pca <- prcomp(X, center = TRUE, scale. = FALSE)
  ve  <- 100 * pca$sdev^2 / sum(pca$sdev^2)

  var_grupo <- if ("area" %in% names(dt)) "area" else if ("condact" %in% names(dt)) "condact" else NA_character_
  grupo <- if (!is.na(var_grupo)) {
    g <- dt[[var_grupo]][complete.cases(as.data.frame(dt[, ..vars]))]
    g <- etiqueta_valores(g, var_grupo)
    g[is.na(g)] <- "Sin dato"
    g
  } else {
    rep("Total", nrow(pca$x))
  }
  grupo <- factor(grupo)
  # Evitar demasiadas categorías en la leyenda
  if (nlevels(grupo) > 8) {
    top <- names(sort(table(grupo), decreasing = TRUE))[1:7]
    grupo[!grupo %in% top] <- "Otros"
  }
  titulo_grupo <- if (identical(var_grupo, "area")) "Área de residencia" else "Condición de actividad"

  scores <- data.frame(PC1 = pca$x[, 1], PC2 = pca$x[, 2], grupo = grupo)

  p1 <- ggplot(scores, aes(x = PC1, y = PC2, colour = grupo)) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "#AEB6BF", linewidth = 0.3) +
    geom_vline(xintercept = 0, linetype = "dashed", colour = "#AEB6BF", linewidth = 0.3) +
    geom_point(alpha = 0.30, size = 0.55) +
    scale_colour_brewer(palette = "Dark2", name = titulo_grupo) +
    labs(
      title = "PCA - proyección de los dos primeros componentes",
      subtitle = sprintf("PC1 = %.1f %% - PC2 = %.1f %% - varianza acumulada = %.1f %% - n = %s",
                         ve[1], ve[2], ve[1] + ve[2],
                         comma(nrow(scores), big.mark = ".", decimal.mark = ",")),
      x = sprintf("PC1 (%.1f %%)", ve[1]),
      y = sprintf("PC2 (%.1f %%)", ve[2]),
      caption = "Solo se incluyen registros completos en edad, años de estudio, horas semanales totales e ingreso laboral mensual."
    ) +
    TEMA_BASE +
    guides(colour = guide_legend(override.aes = list(size = 2.5, alpha = 1))) +
    theme(legend.position = "bottom")

  cargas <- as.data.frame(pca$rotation[, 1:2])
  cargas$variable <- etiqueta_var(rownames(cargas))
  cargas_long <- pivot_longer(cargas, cols = c("PC1", "PC2"),
                              names_to = "componente", values_to = "carga")

  p2 <- ggplot(cargas_long, aes(x = reorder(variable, carga), y = carga,
                                fill = componente)) +
    geom_col(position = position_dodge(width = 0.75), width = 0.65) +
    geom_hline(yintercept = 0, colour = GRIS, linewidth = 0.3) +
    coord_flip() +
    scale_fill_manual(values = c("PC1" = AZUL, "PC2" = ROJO), name = NULL) +
    labs(title = "Cargas de las variables", x = NULL, y = "Carga") +
    TEMA_BASE +
    theme(legend.position = "bottom",
          axis.text.y = element_text(size = 7))

  g <- arrangeGrob(p1, p2, ncol = 2, widths = c(1.55, 1))
  dim <- dimensiones_paneles(2, ncol = 2, ancho_panel = 6.2,
                            alto_panel = 5.5, extra_alto = 0.8)
  img <- guardar_grafico(g, "09_pca.png",
                         ancho = dim["ancho"], alto = dim["alto"])

  z1 <- abs(scale(scores$PC1))[, 1]
  z2 <- abs(scale(scores$PC2))[, 1]
  extremos <- sum(z1 > 3 | z2 > 3)

  hallazgos <- c(
    sprintf("PC1 y PC2 explican conjuntamente el %.1f %% de la variabilidad; se necesitan %d componentes para superar el 80 %%.",
            ve[1] + ve[2], which(cumsum(ve) >= 80)[1]),
    sprintf("PC1 está dominado por %s; PC2 por %s.",
            paste(etiqueta_var(rownames(pca$rotation)[order(-abs(pca$rotation[, 1]))][1:2]), collapse = " y "),
            paste(etiqueta_var(rownames(pca$rotation)[order(-abs(pca$rotation[, 2]))][1:2]), collapse = " y ")),
    sprintf("%d registros (%.2f %%) se ubican a más de 3 desviaciones estándar en PC1 o PC2: posibles anomalías multivariadas.",
            extremos, 100 * extremos / nrow(scores)),
    sprintf("La proyección usa %s registros completos; por la ausencia estructural de ingresos y horas, representa a población ocupada y no a inactivos ni desocupados.",
            comma(nrow(scores), big.mark = ".", decimal.mark = ",")),
    "La proyección es lineal y puede ocultar anomalías en componentes de baja varianza; el LOF se aplicará sobre el espacio original."
  )

  list(
    id = "g9", numero = 9,
    titulo = "PCA (Análisis de Componentes Principales)",
    pregunta = "¿Se observan agrupaciones o registros aislados considerando varias variables simultáneamente?",
    imagen = img,
    lectura = paste(
      "El PCA resume las variables numéricas en componentes no correlacionados. El panel izquierdo",
      "proyecta a las personas en PC1–PC2 y el derecho muestra cuánto aporta cada variable a esos ejes.",
      "Nubes separadas sugieren subpoblaciones; puntos aislados son candidatos a anomalías multivariadas.",
      "La varianza explicada indica cuánta información conserva la proyección."
    ),
    hallazgos = hallazgos
  )
}

#' 10. Serie temporal (semanal) de indicadores laborales
grafico_serie_temporal <- function(dt, vars = c("ylab", "phrs", "tothrs")) {
  vars <- intersect(vars, names(dt))
  fecha <- construir_fecha(dt)
  if (all(is.na(fecha))) stop("No hay variables temporales para construir la serie.")
  peso_ok <- "fact_trim_act" %in% names(dt)

  df <- rbindlist(lapply(vars, function(v) {
    d <- data.table(
      fecha = fecha,
      valor = dt[[v]],
      peso  = if (peso_ok) dt[["fact_trim_act"]] else 1
    )
    d <- d[!is.na(fecha) & is.finite(valor)]
    if (!nrow(d)) return(NULL)
    agg <- d[, .(
      n       = .N,
      media   = mean(valor),
      mediana = median(valor),
      q25     = quantile(valor, 0.25),
      q75     = quantile(valor, 0.75),
      media_p = if (all(is.na(peso))) mean(valor) else weighted.mean(valor, peso, na.rm = TRUE)
    ), by = fecha][order(fecha)]
    agg[, variable := etiqueta_var(v)]
    agg
  }))
  if (is.null(df) || !nrow(df)) stop("No hay datos suficientes para la serie temporal.")
  df$variable <- factor(df$variable, levels = unique(df$variable))

  p <- ggplot(df, aes(x = fecha)) +
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = AZUL2, alpha = 0.15) +
    geom_line(aes(y = media_p), colour = AZUL, linewidth = 0.75) +
    geom_point(aes(y = media_p), colour = AZUL, size = 1.3) +
    geom_line(aes(y = mediana), colour = ROJO, linewidth = 0.55, linetype = "dashed") +
    facet_wrap(~variable, scales = "free_y", ncol = 1,
               labeller = label_wrap_gen(width = 32)) +
    scale_x_date(date_breaks = "2 weeks", date_labels = "%d/%m") +
    labs(
      title = "Serie temporal semanal de indicadores laborales",
      subtitle = "Línea azul = media ponderada por factor de expansión - línea roja discontinua = mediana - banda = Q1–Q3",
      x = "Semana de referencia (inicio de semana)", y = "Valor",
      caption = "La fecha se construye con gestión, trimestre y semana de la encuesta. El 1T2026 cubre 13 semanas (enero–marzo)."
    ) +
    TEMA_BASE +
    theme(axis.text.x = element_text(angle = 45, hjust = 1, size = 7))

  img <- guardar_grafico(p, "10_serie_temporal.png", ancho = 13, alto = 10)

  cambios <- df[, .(
    primera = media_p[1],
    ultima  = media_p[.N],
    cambio  = 100 * (media_p[.N] - media_p[1]) / media_p[1],
    maximo  = max(media_p),
    minimo  = min(media_p)
  ), by = variable]

  hallazgos <- c(
    sprintf("%s: variación de %.1f %% entre la primera y la última semana (de %s a %s).",
            cambios$variable, cambios$cambio,
            comma(round(cambios$primera, 1), big.mark = ".", decimal.mark = ","),
            comma(round(cambios$ultima, 1), big.mark = ".", decimal.mark = ",")),
    sprintf("Semanas cubiertas: %d, con entre %s y %s registros válidos por semana y variable.",
            uniqueN(df$fecha), comma(min(df$n), big.mark = ".", decimal.mark = ","), comma(max(df$n), big.mark = ".", decimal.mark = ",")),
    "La banda Q1–Q3 es amplia en ingresos: la media puede ocultar cambios en la composición de ocupados entre semanas.",
    "Con un solo trimestre no es posible evaluar estacionalidad anual; los cambios observados son de corto plazo."
  )

  list(
    id = "g10", numero = 10,
    titulo = "Serie temporal",
    pregunta = "¿Los valores extremos corresponden a eventos aislados, tendencias o patrones periódicos?",
    imagen = img,
    lectura = paste(
      "La serie agrupa los datos por semana de referencia y muestra la media ponderada, la mediana y",
      "el rango intercuartílico de cada indicador. Permite ver tendencias, saltos bruscos y semanas",
      "atípicas. Con un único trimestre, la lectura es de corto plazo y no de estacionalidad anual."
    ),
    hallazgos = hallazgos
  )
}

# -----------------------------------------------------------------------------
# ORQUESTADOR DE GRÁFICOS
# -----------------------------------------------------------------------------

#' Ejecuta los 8 gráficos aplicables a las variables numéricas del informe.
generar_graficos_perfilado <- function(dt) {
  cat("\n", strrep("=", 78), "\n", sep = "")
  cat("3. GENERACIÓN DE GRÁFICOS EXPLORATORIOS\n")
  cat(strrep("=", 78), "\n", sep = "")

  graficadores <- list(
    grafico_mapa_faltantes,
    grafico_barras_faltantes,
    grafico_histogramas,
    grafico_boxplots,
    grafico_violines,
    grafico_correlaciones,
    grafico_dispersion,
    grafico_pca
  )

  nombres <- c(
    "Mapa de faltantes", "Barras de faltantes", "Histogramas", "Boxplots",
    "Violines", "Correlaciones", "Dispersión", "PCA"
  )

  resultados <- list()
  for (i in seq_along(graficadores)) {
    cat(sprintf("\n[%02d/%02d] %s ...\n", i, length(graficadores), nombres[i]))
    res <- tryCatch(
      graficadores[[i]](dt),
      error = function(e) {
        warning(sprintf("Gráfico %d omitido: %s", i, conditionMessage(e)), call. = FALSE)
        NULL
      }
    )
    if (!is.null(res)) {
      resultados[[res$id]] <- res
      cat(sprintf("  OK · %s\n", basename(res$imagen)))
      for (h in res$hallazgos) cat("   - ", h, "\n", sep = "")
    }
    invisible(gc())
  }
  resultados
}

# -----------------------------------------------------------------------------
# REPORTE HTML
# -----------------------------------------------------------------------------

esc_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x
}

img_base64 <- function(ruta) {
  if (!file.exists(ruta)) return("")
  base64enc::dataURI(file = ruta, mime = "image/png")
}

#' Genera un reporte HTML autocontenido: cada figura seguida por su texto
#' descriptivo (pregunta, cómo leerla y hallazgos).
generar_reporte_html <- function(dt, perfil, resultados) {
  ruta_html <- file.path(DIR_SALIDA, "reporte_perfilado.html")

  n <- nrow(dt)
  n_na <- sum(perfil$n_na)
  completas <- sum(complete.cases(dt))
  dups <- sum(duplicated(dt))
  anomalas <- perfil[pct_na > 50]
  constantes <- perfil[n_unicos <= 1]
  const_diseno <- intersect(c("gestion", "trimestre", "trim"), constantes$variable)
  const_vacias <- setdiff(constantes$variable, const_diseno)

  kpi <- function(valor, etiqueta) {
    sprintf('<div class="kpi"><div class="kpi-val">%s</div><div class="kpi-lab">%s</div></div>',
            valor, etiqueta)
  }

  kpis <- paste0(
    kpi(format(n, big.mark = ".", decimal.mark = ","), "Filas"),
    kpi(format(ncol(dt), big.mark = ".", decimal.mark = ","), "Columnas"),
    kpi(sprintf("%.1f %%", 100 * (1 - n_na / (n * ncol(dt)))), "Celdas completas"),
    kpi(sprintf("%.1f %%", 100 * completas / n), "Filas completas"),
    kpi(format(dups, big.mark = ".", decimal.mark = ","), "Duplicados exactos")
  )

  anomalias_li <- c(
    if (nrow(anomalas)) sprintf("<li><b>%d columnas con más del 50 %% de NA</b> (candidatas a eliminación): %s.</li>",
                                nrow(anomalas), paste(sprintf("<code>%s</code> (%.1f %%)",
                                                              anomalas$variable, anomalas$pct_na), collapse = ", ")),
    if (length(const_diseno)) sprintf("<li><b>%d columnas constantes por diseño</b>: %s. Es esperado al analizar un solo trimestre; no son un error.</li>",
                                      length(const_diseno), paste(sprintf("<code>%s</code>", const_diseno), collapse = ", ")),
    if (length(const_vacias)) sprintf("<li><b>%d columnas vacías</b> (sin ningún dato): %s. Deben eliminarse.</li>",
                                      length(const_vacias), paste(sprintf("<code>%s</code>", const_vacias), collapse = ", ")),
    sprintf("<li><b>%s duplicados exactos</b> que deben resolverse en el paso 3.</li>",
            format(dups, big.mark = ".", decimal.mark = ",")),
    sprintf("<li><b>%d variables de texto libre</b> con alta cardinalidad (nombres de establecimiento, especificaciones); no son aptas para GMM sin codificar.</li>",
            nrow(perfil[clase == "character" & n_unicos > 30])),
    sprintf("<li><b>%d variables numéricas</b> con NA estructural superior al 40 %% (ingresos, horas, tiempos de búsqueda): la imputación debe hacerse por subpoblación.</li>",
            nrow(perfil[clase %in% c("numeric", "integer") & pct_na > 40]))
  )
  anomalias_li <- paste(anomalias_li, collapse = "")

  # Tabla resumen de variables (top 25 por NA)
  top_na <- perfil[order(-pct_na)][1:min(25, .N)]
  filas_tabla <- paste(sprintf(
    "<tr><td><code>%s</code></td><td>%s</td><td>%s</td><td>%d</td><td>%s %%</td><td>%s</td></tr>",
    top_na$variable, top_na$clase, top_na$tipo_sugerido,
    top_na$n_unicos,
    format(top_na$pct_na, decimal.mark = ","),
    ifelse(is.na(top_na$categoria_top), "—",
           sprintf("%s (%s)", esc_html(top_na$categoria_top),
                   format(top_na$freq_top, big.mark = ".", decimal.mark = ",")))
  ), collapse = "\n")

  # Secciones
  secciones <- list(
    "1" = list(titulo = "Gráficos para comprender la estructura del dataset",
               intro = "Identifican problemas de completitud y patrones de ausencia antes de transformar los datos.",
               ids = c("g1", "g2")),
    "2" = list(titulo = "Gráficos para comprender las variables numéricas",
               intro = "Describen la forma de las distribuciones, la asimetría y los valores atípicos que condicionan la especificación del GMM.",
               ids = c("g4", "g5", "g6")),
    "3" = list(titulo = "Gráficos para comprender relaciones entre variables",
               intro = "Exploran redundancia, relaciones no lineales, subpoblaciones y anomalías multivariadas antes de aplicar GMM y LOF.",
               ids = c("g7", "g8", "g9"))
  )

  html_secciones <- character()
  for (sec in secciones) {
    bloques <- character()
    for (id in sec$ids) {
      res <- resultados[[id]]
      if (is.null(res)) next
      hallazgos <- paste(sprintf("<li>%s</li>", esc_html(res$hallazgos)), collapse = "")
      bloques <- c(bloques, sprintf('
<article class="grafico" id="%s">
  <h3>%s</h3>
  <p class="pregunta"><b>Pregunta:</b> %s</p>
  <figure>
    <img src="%s" alt="%s">
    <figcaption>Figura %d. %s</figcaption>
  </figure>
  <div class="lectura">
    <h4>Cómo leer el gráfico</h4>
    <p>%s</p>
  </div>
  <div class="hallazgos">
    <h4>Texto descriptivo y hallazgos</h4>
    <ul>%s</ul>
  </div>
</article>',
        res$id, esc_html(sprintf("%d. %s", res$numero, res$titulo)),
        esc_html(res$pregunta),
        img_base64(res$imagen), esc_html(res$titulo), res$numero, esc_html(res$titulo),
        esc_html(res$lectura), hallazgos))
    }
    html_secciones <- c(html_secciones, sprintf(
      '<section><h2>%s</h2><p class="intro">%s</p>%s</section>',
      esc_html(sec$titulo), esc_html(sec$intro), paste(bloques, collapse = "\n")))
  }

  css <- "
:root{--azul:#1F4E79;--rojo:#C0392B;--gris:#6B7785;--fondo:#F4F6F8}
*{box-sizing:border-box}
body{margin:0;background:var(--fondo);color:#1B2631;font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;line-height:1.55}
.wrap{max-width:1180px;margin:0 auto;padding:32px 22px 60px}
header{background:linear-gradient(135deg,#16324F,#1F4E79);color:#fff;border-radius:14px;padding:30px 34px;margin-bottom:26px}
header h1{margin:0 0 6px;font-size:28px}
header .sub{opacity:.9;font-size:14px}
header .meta{margin-top:14px;font-size:12px;opacity:.8}
.kpis{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin:0 0 26px}
.kpi{background:#fff;border-radius:12px;padding:16px;text-align:center;box-shadow:0 1px 4px rgba(0,0,0,.06)}
.kpi-val{font-size:22px;font-weight:700;color:var(--azul)}
.kpi-lab{font-size:11px;text-transform:uppercase;letter-spacing:.5px;color:var(--gris)}
section{background:#fff;border-radius:14px;padding:26px 30px;margin-bottom:24px;box-shadow:0 1px 5px rgba(0,0,0,.05)}
section h2{margin-top:0;color:var(--azul);font-size:22px;border-bottom:2px solid #E5EAF0;padding-bottom:10px}
.intro{color:#4D5656;margin-top:-4px}
h3{margin:34px 0 6px;font-size:18px;color:#16324F}
.pregunta{background:#EEF4FA;border-left:4px solid var(--azul);padding:10px 14px;border-radius:0 8px 8px 0;font-size:14px;margin:10px 0 16px}
figure{margin:0 0 14px;text-align:center}
figure img{max-width:100%;height:auto;border:1px solid #E1E6EC;border-radius:8px;background:#fff}
figcaption{font-size:12px;color:var(--gris);margin-top:6px}
.lectura h4,.hallazgos h4{margin:12px 0 4px;font-size:13.5px;text-transform:uppercase;letter-spacing:.4px;color:var(--gris)}
.lectura p{margin:0 0 10px;font-size:14px;color:#2C3E50}
.hallazgos{background:#FBFCFD;border:1px solid #E5EAF0;border-radius:10px;padding:4px 18px 10px;margin-top:10px}
.hallazgos ul{margin:8px 0 6px;padding-left:20px}
.hallazgos li{margin-bottom:7px;font-size:13.5px}
.anomalias{background:#FDF3F2;border-left:5px solid var(--rojo);border-radius:10px;padding:8px 20px 12px}
.anomalias li{margin-bottom:7px}
table{border-collapse:collapse;width:100%;font-size:12.5px;margin-top:12px}
th,td{padding:7px 9px;border-bottom:1px solid #E5EAF0;text-align:left}
th{background:#EEF4FA;color:var(--azul);font-size:11px;text-transform:uppercase;letter-spacing:.4px}
code{background:#EEF1F4;padding:1px 5px;border-radius:4px;font-size:12px}
footer{color:var(--gris);font-size:12px;text-align:center;margin-top:30px}
@media(max-width:900px){.kpis{grid-template-columns:repeat(2,1fr)}section{padding:18px}}
@media print{body{background:#fff}.wrap{max-width:100%}section{box-shadow:none;page-break-inside:avoid}header{background:#16324F!important;-webkit-print-color-adjust:exact}}
"

  html <- sprintf('<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Perfilado inicial ECE 1T2026</title>
<style>%s</style>
</head>
<body>
<div class="wrap">
<header>
  <h1>Auditoría y perfilado inicial · ECE 1T2026</h1>
  <div class="sub">Paso 1 del informe de preparación de datos · Encuesta Continua de Empleo (INE Bolivia)</div>
  <div class="meta">Fuente: %s · Generado: %s · Script: apps/R/perfilado_inicial.R</div>
</header>

<div class="kpis">%s</div>

<section>
  <h2>Resumen del dataset</h2>
  <p>El archivo contiene <b>%s registros</b> y <b>%d variables</b>. El perfilado revisó tipos de datos,
  estadísticos descriptivos, cardinalidad y valores faltantes antes de cualquier transformación.
  La tabla completa está en <code>output/perfilado/perfil_variables.csv</code>.</p>
  <h3>Anomalías iniciales detectadas</h3>
  <div class="anomalias"><ul>%s</ul></div>
  <h3>Variables con mayor porcentaje de valores faltantes</h3>
  <table>
    <thead><tr><th>Variable</th><th>Clase</th><th>Tipo sugerido</th><th>Únicos</th><th>%% NA</th><th>Categoría modal</th></tr></thead>
    <tbody>%s</tbody>
  </table>
</section>

%s

<footer>Reporte generado automáticamente con R %s · ECE 1T2026 · Los gráficos y textos están pensados como insumo para los pasos 2–6 del informe.</footer>
</div>
</body>
</html>',
    css,
    "Dataframe seleccionado en apps/R/inicio.R",
    format(Sys.time(), "%Y-%m-%d %H:%M"),
    kpis,
    format(n, big.mark = ".", decimal.mark = ","),
    ncol(dt),
    anomalias_li,
    filas_tabla,
    paste(html_secciones, collapse = "\n"),
    getRversion()
  )

  writeBin(charToRaw(html), ruta_html)

  cat(sprintf("\nReporte HTML: %s\n", ruta_html))
  invisible(ruta_html)
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------

ejecutar_perfilado_inicial <- function(dataset) {
  t0 <- Sys.time()

  if (!is.data.frame(dataset)) {
    stop("El argumento 'dataset' debe ser un data.frame o data.table.", call. = FALSE)
  }
  faltantes <- setdiff(VARS_NUM, names(dataset))
  if (length(faltantes)) {
    stop("Faltan variables requeridas: ", paste(faltantes, collapse = ", "), call. = FALSE)
  }
  if (!nrow(dataset)) {
    stop("El dataset no contiene filas.", call. = FALSE)
  }

  datos <- as.data.table(copy(dataset))[, ..VARS_NUM]
  no_numericas <- VARS_NUM[!vapply(datos[, ..VARS_NUM], is.numeric, logical(1))]
  if (length(no_numericas)) {
    stop("Estas variables deben ser numéricas: ",
         paste(no_numericas, collapse = ", "), call. = FALSE)
  }

  dir.create(DIR_FIG, recursive = TRUE, showWarnings = FALSE)

  cat("\n", strrep("#", 78), "\n", sep = "")
  cat("#  PASO 1 · AUDITORÍA Y PERFILADO INICIAL (ECE 1T2026)\n")
  cat("#  Variables: ", paste(VARS_NUM, collapse = ", "), "\n", sep = "")
  cat("#  Salida : ", DIR_SALIDA, "\n", sep = "")
  cat(strrep("#", 78), "\n", sep = "")

  inspeccionar_estructura(datos)

  perfil <- perfilar_variables(datos)
  resumir_perfil(datos, perfil)

  fwrite(perfil, file.path(DIR_SALIDA, "perfil_variables.csv"),
         bom = TRUE, na = "")
  cat(sprintf("\nPerfil por variable guardado en: %s\n",
              file.path(DIR_SALIDA, "perfil_variables.csv")))

  resultados <- generar_graficos_perfilado(datos)
  reporte <- generar_reporte_html(datos, perfil, resultados)

  cat("\n", strrep("=", 78), "\n", sep = "")
  cat(sprintf("Proceso completado en %.1f segundos · %d/8 gráficos generados.\n",
              as.numeric(difftime(Sys.time(), t0, units = "secs")),
              length(resultados)))
  cat(strrep("=", 78), "\n", sep = "")

  invisible(list(perfil = perfil, graficos = resultados, reporte = reporte))
}
