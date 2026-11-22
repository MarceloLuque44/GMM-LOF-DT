import cors from 'cors'
import express from 'express'
import helmet from 'helmet'
import { config } from './config.js'

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

app.use('/api', (_request, response) => {
  response.status(404).json({ error: 'Recurso no encontrado' })
})

app.use((error, _request, response, _next) => {
  console.error(error)
  response.status(500).json({ error: 'Error interno del servidor' })
})

export default app

