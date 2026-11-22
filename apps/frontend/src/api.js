const rawBaseUrl = import.meta.env.VITE_API_URL ?? ''

export const API_BASE_URL = rawBaseUrl.replace(/\/+$/, '')

export const apiUrl = (path) => {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`
  return `${API_BASE_URL}${normalizedPath}`
}

const getJson = async (path) => {
  const response = await fetch(apiUrl(path), {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(8000),
  })

  if (!response.ok) throw new Error(`La API respondió con estado ${response.status}`)
  return response.json()
}

export const checkHealth = () => getJson('/api/health')
export const getDashboard = () => getJson('/api/dashboard')
export const getAnalysisSteps = () => getJson('/api/analysis-steps')
export const getLogs = () => getJson('/api/logs')
