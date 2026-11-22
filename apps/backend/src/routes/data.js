import { Router } from 'express'
import { config } from '../config.js'
import { getPool } from '../db.js'

export const dataRouter = Router()

const observationColumns = {
  dataset: 'dataset',
  personId: 'id_persona',
  ylab: 'ylab',
  tothrs: 'tothrs',
  aestudio: 'aestudio',
  age: 's1_03a',
  yprilab: 'yprilab',
  phrs: 'phrs',
  gmmScore: 'puntuacion_gmm',
  lofScore: 'puntuacion_lof',
  gmmAnomaly: 'es_atipico_gmm',
  lofAnomaly: 'es_atipico_lof',
}

const logColumns = {
  stepNumber: 'paso_numero',
  executedAt: 'fecha_hora',
  responsible: 'responsable',
  dataset: 'dataset',
  variable: 'atributo_variable',
  problemType: 'tipo_problema',
  methodology: 'metodologia',
  action: 'accion_realizada',
  justification: 'criterio_justificacion',
  affectedRows: 'filas_afectadas',
  datasetImpact: 'impacto_dataset',
  script: 'codigo_script',
}

const observationSelect = `
  id,
  dataset,
  id_persona AS "personId",
  ylab,
  tothrs,
  aestudio,
  s1_03a AS age,
  yprilab,
  phrs,
  puntuacion_gmm AS "gmmScore",
  puntuacion_lof AS "lofScore",
  es_atipico_gmm AS "gmmAnomaly",
  es_atipico_lof AS "lofAnomaly",
  creado_en AS "createdAt",
  actualizado_en AS "updatedAt"
`

const logSelect = `
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
`

const parsePagination = (query) => {
  const page = Math.max(Number.parseInt(query.page ?? '1', 10) || 1, 1)
  const limit = Math.min(Math.max(Number.parseInt(query.limit ?? '20', 10) || 20, 1), 100)
  return { page, limit, offset: (page - 1) * limit }
}

const requireDatabase = (_request, response, next) => {
  if (!config.databaseUrl) {
    return response.status(503).json({ error: 'DATABASE_URL no está configurada' })
  }
  return next()
}

const parseId = (request, response) => {
  const id = Number.parseInt(request.params.id, 10)
  if (!Number.isSafeInteger(id) || id < 1) {
    response.status(400).json({ error: 'El identificador debe ser un entero positivo' })
    return null
  }
  return id
}

const buildUpdate = (body, columns) => {
  const entries = Object.entries(columns).filter(([apiName]) => Object.hasOwn(body, apiName))
  if (entries.length === 0) return null

  return {
    clause: entries.map(([, column], index) => `${column} = $${index + 1}`).join(', '),
    values: entries.map(([apiName]) => body[apiName]),
  }
}

const requiredLogFields = Object.keys(logColumns).filter((field) => field !== 'executedAt')

dataRouter.use(requireDatabase)

dataRouter.get('/observations', async (request, response) => {
  const { page, limit, offset } = parsePagination(request.query)
  const filters = []
  const values = []

  if (request.query.dataset) {
    values.push(request.query.dataset)
    filters.push(`dataset = $${values.length}`)
  }
  if (request.query.anomalous === 'true') filters.push('(es_atipico_gmm OR es_atipico_lof)')
  if (request.query.anomalous === 'false') filters.push('NOT es_atipico_gmm AND NOT es_atipico_lof')

  const where = filters.length > 0 ? `WHERE ${filters.join(' AND ')}` : ''
  values.push(limit, offset)
  const { rows } = await getPool().query(`
    SELECT ${observationSelect}, COUNT(*) OVER()::int AS "totalCount"
    FROM gmm.observaciones_laborales
    ${where}
    ORDER BY creado_en DESC, id DESC
    LIMIT $${values.length - 1} OFFSET $${values.length}
  `, values)

  const total = rows[0]?.totalCount ?? 0
  const items = rows.map(({ totalCount: _totalCount, ...row }) => row)
  return response.json({ items, pagination: { page, limit, total, pages: Math.ceil(total / limit) } })
})

dataRouter.get('/observations/:id', async (request, response) => {
  const id = parseId(request, response)
  if (!id) return
  const { rows } = await getPool().query(`SELECT ${observationSelect} FROM gmm.observaciones_laborales WHERE id = $1`, [id])
  if (!rows[0]) return response.status(404).json({ error: 'Observación no encontrada' })
  return response.json(rows[0])
})

dataRouter.post('/observations', async (request, response) => {
  const body = request.body ?? {}
  const { rows } = await getPool().query(`
    INSERT INTO gmm.observaciones_laborales (
      dataset, id_persona, ylab, tothrs, aestudio, s1_03a, yprilab, phrs,
      puntuacion_gmm, puntuacion_lof, es_atipico_gmm, es_atipico_lof
    ) VALUES (
      COALESCE($1, 'ECE_1T_2026'), $2, $3, $4, $5, $6, $7, $8, $9, $10,
      COALESCE($11, false), COALESCE($12, false)
    ) RETURNING ${observationSelect}
  `, [body.dataset, body.personId, body.ylab, body.tothrs, body.aestudio, body.age, body.yprilab, body.phrs, body.gmmScore, body.lofScore, body.gmmAnomaly, body.lofAnomaly])
  return response.status(201).json(rows[0])
})

dataRouter.patch('/observations/:id', async (request, response) => {
  const id = parseId(request, response)
  if (!id) return
  const update = buildUpdate(request.body ?? {}, observationColumns)
  if (!update) return response.status(400).json({ error: 'No se enviaron campos editables' })
  update.values.push(id)
  const { rows } = await getPool().query(`
    UPDATE gmm.observaciones_laborales
    SET ${update.clause}, actualizado_en = now()
    WHERE id = $${update.values.length}
    RETURNING ${observationSelect}
  `, update.values)
  if (!rows[0]) return response.status(404).json({ error: 'Observación no encontrada' })
  return response.json(rows[0])
})

dataRouter.delete('/observations/:id', async (request, response) => {
  const id = parseId(request, response)
  if (!id) return
  const result = await getPool().query('DELETE FROM gmm.observaciones_laborales WHERE id = $1', [id])
  if (result.rowCount === 0) return response.status(404).json({ error: 'Observación no encontrada' })
  return response.status(204).end()
})

dataRouter.get('/model-variables', async (request, response) => {
  const { page, limit, offset } = parsePagination(request.query)
  const { rows } = await getPool().query(`
    SELECT id, ylab, tothrs, aestudio, s1_03a AS age, yprilab, phrs,
           COUNT(*) OVER()::int AS "totalCount"
    FROM gmm.variables_modelo
    ORDER BY id
    LIMIT $1 OFFSET $2
  `, [limit, offset])
  const total = rows[0]?.totalCount ?? 0
  const items = rows.map(({ totalCount: _totalCount, ...row }) => row)
  return response.json({ items, pagination: { page, limit, total, pages: Math.ceil(total / limit) } })
})

dataRouter.get('/logs', async (request, response) => {
  const { page, limit, offset } = parsePagination(request.query)
  const { rows } = await getPool().query(`
    SELECT ${logSelect}, COUNT(*) OVER()::int AS "totalCount"
    FROM gmm.bitacora
    ORDER BY paso_numero DESC, fecha_hora DESC
    LIMIT $1 OFFSET $2
  `, [limit, offset])
  const total = rows[0]?.totalCount ?? 0
  const entries = rows.map(({ totalCount: _totalCount, ...row }) => row)
  return response.json({ entries, pagination: { page, limit, total, pages: Math.ceil(total / limit) } })
})

dataRouter.get('/logs/:id', async (request, response) => {
  const id = parseId(request, response)
  if (!id) return
  const { rows } = await getPool().query(`SELECT ${logSelect} FROM gmm.bitacora WHERE id = $1`, [id])
  if (!rows[0]) return response.status(404).json({ error: 'Entrada de bitácora no encontrada' })
  return response.json(rows[0])
})

dataRouter.post('/logs', async (request, response) => {
  const body = request.body ?? {}
  const missing = requiredLogFields.filter((field) => body[field] === undefined || body[field] === '')
  if (missing.length > 0) return response.status(400).json({ error: 'Faltan campos obligatorios', fields: missing })

  const { rows } = await getPool().query(`
    INSERT INTO gmm.bitacora (
      paso_numero, fecha_hora, responsable, dataset, atributo_variable, tipo_problema,
      metodologia, accion_realizada, criterio_justificacion, filas_afectadas,
      impacto_dataset, codigo_script
    ) VALUES ($1, COALESCE($2, now()), $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
    RETURNING ${logSelect}
  `, [body.stepNumber, body.executedAt, body.responsible, body.dataset, body.variable, body.problemType, body.methodology, body.action, body.justification, body.affectedRows, body.datasetImpact, body.script])
  return response.status(201).json(rows[0])
})

dataRouter.patch('/logs/:id', async (request, response) => {
  const id = parseId(request, response)
  if (!id) return
  const update = buildUpdate(request.body ?? {}, logColumns)
  if (!update) return response.status(400).json({ error: 'No se enviaron campos editables' })
  update.values.push(id)
  const { rows } = await getPool().query(`UPDATE gmm.bitacora SET ${update.clause} WHERE id = $${update.values.length} RETURNING ${logSelect}`, update.values)
  if (!rows[0]) return response.status(404).json({ error: 'Entrada de bitácora no encontrada' })
  return response.json(rows[0])
})

dataRouter.delete('/logs/:id', async (request, response) => {
  const id = parseId(request, response)
  if (!id) return
  const result = await getPool().query('DELETE FROM gmm.bitacora WHERE id = $1', [id])
  if (result.rowCount === 0) return response.status(404).json({ error: 'Entrada de bitácora no encontrada' })
  return response.status(204).end()
})
