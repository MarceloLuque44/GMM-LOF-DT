import cors from 'cors'
import express from 'express'
import helmet from 'helmet'
import { config } from './config.js'
import { getPool } from './db.js'

const app = express()

app.disable('x-powered-by')
app.use(helmet())
app.use(
  cors({
    origin: config.corsOrigins.length > 0 ? config.corsOrigins : true,
  }),
)
app.use(express.json({ limit: '1mb' }))

app.get('/api/health', (_request, response) => {
  response.status(200).json({
    status: 'ok',
    service: 'gmm-api',
    databaseConfigured: Boolean(config.databaseUrl),
    timestamp: new Date().toISOString(),
  })
})

const analysisSteps = [
  { number: 1, title: 'Selección de datos', description: 'Filtrar la población ocupada y conservar las seis variables laborales.', status: 'ready' },
  { number: 2, title: 'Preprocesamiento y limpieza', description: 'Auditar faltantes, duplicados, tipos y valores fuera de dominio.', status: 'pending' },
  { number: 3, title: 'Transformación', description: 'Imputar, transformar distribuciones asimétricas y estandarizar.', status: 'pending' },
  { number: 4, title: 'Minería con GMM', description: 'Estimar mezclas gaussianas e identificar observaciones de baja probabilidad.', status: 'pending' },
  { number: 5, title: 'Minería con LOF', description: 'Calcular densidad local y detectar perfiles poco frecuentes.', status: 'pending' },
  { number: 6, title: 'Evaluación e interpretación', description: 'Comparar resultados y caracterizar los perfiles laborales atípicos.', status: 'pending' },
]

app.get('/api/analysis-steps', (_request, response) => {
  response.status(200).json({ steps: analysisSteps })
})

app.get('/api/dashboard', async (_request, response) => {
  if (!config.databaseUrl) {
    return response.status(200).json({
      databaseConfigured: false,
      totalRecords: 0,
      completeRecords: 0,
      anomalousRecords: 0,
      logEntries: 0,
    })
  }

  const { rows } = await getPool().query(`
    SELECT
      (SELECT COUNT(*)::int FROM gmm.observaciones_laborales) AS "totalRecords",
      (SELECT COUNT(*)::int
       FROM gmm.observaciones_laborales
       WHERE ylab IS NOT NULL AND tothrs IS NOT NULL AND aestudio IS NOT NULL
         AND s1_03a IS NOT NULL AND yprilab IS NOT NULL AND phrs IS NOT NULL) AS "completeRecords",
      (SELECT COUNT(*)::int
       FROM gmm.observaciones_laborales
       WHERE es_atipico_gmm OR es_atipico_lof) AS "anomalousRecords",
      (SELECT COUNT(*)::int FROM gmm.bitacora) AS "logEntries"
  `)

  return response.status(200).json({ databaseConfigured: true, ...rows[0] })
})

app.get('/api/logs', async (_request, response) => {
  if (!config.databaseUrl) return response.status(200).json({ entries: [] })

  const { rows } = await getPool().query(`
    SELECT
      id,
      paso_numero AS "stepNumber",
      fecha_hora AS "executedAt",
      responsable AS responsible,
      dataset,
      atributo_variable AS variable,
      tipo_problema AS "problemType",
      metodologia AS methodology,
      accion_realizada AS action,
      criterio_justificacion AS justification,
      filas_afectadas AS "affectedRows",
      impacto_dataset AS "datasetImpact",
      codigo_script AS script
    FROM gmm.bitacora
    ORDER BY paso_numero DESC, fecha_hora DESC
    LIMIT 200
  `)

  return response.status(200).json({ entries: rows })
})

app.use('/api', (_request, response) => {
  response.status(404).json({ error: 'Recurso no encontrado' })
})

app.use((error, _request, response, _next) => {
  console.error(error)
  response.status(500).json({ error: 'Error interno del servidor' })
})

export default app

