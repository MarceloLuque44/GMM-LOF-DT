import cors from 'cors'
import express from 'express'
import helmet from 'helmet'
import { config } from './config.js'
import { getPool } from './db.js'
import { dataRouter } from './routes/data.js'

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
  { number: 1, title: 'Selección y perfilado', description: 'Se auditaron 52.061 registros y seis variables laborales.', status: 'done' },
  { number: 2, title: 'Normalización y duplicados', description: 'Se validaron tipos e identificadores; no hubo identificadores duplicados.', status: 'done' },
  { number: 3, title: 'Faltantes y casos completos', description: 'Se seleccionaron 24.275 personas ocupadas con seis variables completas, sin imputación.', status: 'done' },
  { number: 4, title: 'Extremos y consistencia', description: 'Se señalaron extremos exploratorios y se conservaron las 24.275 filas.', status: 'done' },
  { number: 5, title: 'Transformación', description: 'Se aplicó log(1 + x) al ingreso y puntuación z a cuatro características.', status: 'done' },
  { number: 6, title: 'Minería con GMM', description: 'Cuatro componentes VEI y umbral P99 señalaron 243 perfiles.', status: 'done' },
  { number: 7, title: 'Minería con LOF', description: 'Con minPts = 20 y umbral P99 se señalaron 243 perfiles.', status: 'done' },
  { number: 8, title: 'Evaluación y comparación', description: 'Los modelos coincidieron en 40 candidatos; Jaccard = 0,0897.', status: 'done' },
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

app.use('/api', dataRouter)

app.use('/api', (_request, response) => {
  response.status(404).json({ error: 'Recurso no encontrado' })
})

app.use((error, _request, response, _next) => {
  console.error(error)
  if (error.code === '23505') return response.status(409).json({ error: 'El registro ya existe' })
  if (error.code === '22P02' || error.code === '22007') return response.status(400).json({ error: 'Uno de los valores tiene un formato inválido' })
  response.status(500).json({ error: 'Error interno del servidor' })
})

export default app

