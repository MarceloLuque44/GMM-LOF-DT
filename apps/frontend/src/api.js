const rawBaseUrl = import.meta.env.VITE_API_URL ?? ''

export const API_BASE_URL = rawBaseUrl.replace(/\/+$/, '')

export const apiUrl = (path) => {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`
  return `${API_BASE_URL}${normalizedPath}`
}

export const checkHealth = async () => {
  const response = await fetch(apiUrl('/api/health'), {
    headers: { accept: 'application/json' },
    signal: AbortSignal.timeout(8000),
  })

  if (!response.ok) {
    throw new Error(`La API respondió con estado ${response.status}`)
  }

  return response.json()
}
