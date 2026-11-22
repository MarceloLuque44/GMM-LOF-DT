const rawBaseUrl = import.meta.env.VITE_API_URL ?? ''

export const API_BASE_URL = rawBaseUrl.replace(/\/+$/, '')

export const apiUrl = (path) => {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`
  return `${API_BASE_URL}${normalizedPath}`
}

const requestJson = async (path, options = {}) => {
  const response = await fetch(apiUrl(path), {
    ...options,
    headers: { accept: 'application/json', ...options.headers },
    signal: AbortSignal.timeout(8000),
  })

  if (!response.ok) throw new Error(`La API respondió con estado ${response.status}`)
  if (response.status === 204) return null
  return response.json()
}

const sendJson = (path, method, body) => requestJson(path, {
  method,
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
})

export const checkHealth = () => requestJson('/api/health')
export const getDashboard = () => requestJson('/api/dashboard')
export const getAnalysisSteps = () => requestJson('/api/analysis-steps')

export const getObservations = ({ page = 1, limit = 10, anomalous } = {}) => {
  const params = new URLSearchParams({ page, limit })
  if (anomalous !== undefined) params.set('anomalous', anomalous)
  return requestJson(`/api/observations?${params}`)
}
export const getObservation = (id) => requestJson(`/api/observations/${id}`)
export const createObservation = (data) => sendJson('/api/observations', 'POST', data)
export const updateObservation = (id, data) => sendJson(`/api/observations/${id}`, 'PATCH', data)
export const deleteObservation = (id) => requestJson(`/api/observations/${id}`, { method: 'DELETE' })
export const getModelVariables = ({ page = 1, limit = 100 } = {}) => requestJson(`/api/model-variables?page=${page}&limit=${limit}`)

export const getLogs = ({ page = 1, limit = 200 } = {}) => requestJson(`/api/logs?page=${page}&limit=${limit}`)
export const getLogSeries = () => requestJson('/api/logs/series')
export const getLog = (id) => requestJson(`/api/logs/${id}`)
export const createLog = (data) => sendJson('/api/logs', 'POST', data)
export const updateLog = (id, data) => sendJson(`/api/logs/${id}`, 'PATCH', data)
export const deleteLog = (id) => requestJson(`/api/logs/${id}`, { method: 'DELETE' })
