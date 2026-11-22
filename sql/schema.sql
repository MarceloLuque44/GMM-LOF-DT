-- Esquema PostgreSQL para el análisis GMM/LOF de la ECE 1T 2026.
-- Las seis variables corresponden a la selección de docs/informe.tex.

BEGIN;

CREATE SCHEMA IF NOT EXISTS gmm;

CREATE TABLE IF NOT EXISTS gmm.observaciones_laborales (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dataset               text NOT NULL DEFAULT 'ECE_1T_2026',
  id_persona            text,

  -- Seis variables utilizadas por GMM y LOF
  ylab                  numeric, -- Ingreso laboral mensual total (Bs)
  tothrs                numeric, -- Horas semanales habituales totales
  aestudio              numeric, -- Años de escolaridad acumulados
  s1_03a                numeric, -- Edad cumplida en años
  yprilab               numeric, -- Ingreso laboral mensual de ocupación principal (Bs)
  phrs                  numeric, -- Horas semanales habituales en ocupación principal

  -- Resultados opcionales de los modelos
  puntuacion_gmm        double precision,
  puntuacion_lof        double precision,
  es_atipico_gmm        boolean NOT NULL DEFAULT false,
  es_atipico_lof        boolean NOT NULL DEFAULT false,
  creado_en             timestamptz NOT NULL DEFAULT now(),
  actualizado_en        timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT observacion_dataset_persona_uk UNIQUE (dataset, id_persona)
);

COMMENT ON TABLE gmm.observaciones_laborales IS
  'Variables numéricas seleccionadas en informe.tex y resultados de detección GMM/LOF.';

CREATE INDEX IF NOT EXISTS observaciones_atipicos_idx
  ON gmm.observaciones_laborales (es_atipico_gmm, es_atipico_lof);

CREATE TABLE IF NOT EXISTS gmm.bitacora (
  id                       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  paso_numero              integer NOT NULL CHECK (paso_numero > 0),
  fecha_hora               timestamptz NOT NULL DEFAULT now(),
  responsable              text NOT NULL,
  dataset                  text NOT NULL,
  atributo_variable        text NOT NULL,
  tipo_problema            text NOT NULL,
  metodologia              text NOT NULL,
  accion_realizada         text NOT NULL,
  criterio_justificacion   text NOT NULL,
  filas_afectadas          bigint NOT NULL DEFAULT 0 CHECK (filas_afectadas >= 0),
  impacto_dataset          text NOT NULL,
  codigo_script            text NOT NULL
);

COMMENT ON TABLE gmm.bitacora IS
  'Trazabilidad de limpieza: contiene todos los campos definidos en Base de datos.md.';
COMMENT ON COLUMN gmm.bitacora.paso_numero IS 'ID / Paso (#): número secuencial de la regla aplicada.';
COMMENT ON COLUMN gmm.bitacora.impacto_dataset IS 'Cantidad de registros antes y después del cambio.';

CREATE INDEX IF NOT EXISTS bitacora_fecha_idx
  ON gmm.bitacora (fecha_hora DESC);
CREATE INDEX IF NOT EXISTS bitacora_variable_idx
  ON gmm.bitacora (atributo_variable);

-- Vista limitada a la matriz de características que consumen los modelos.
CREATE OR REPLACE VIEW gmm.variables_modelo AS
SELECT id, ylab, tothrs, aestudio, s1_03a, yprilab, phrs
FROM gmm.observaciones_laborales;

COMMIT;
