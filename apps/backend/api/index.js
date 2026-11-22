import app from '../src/app.js'

export default function handler(request, response) {
  const url = new URL(request.url, 'http://localhost')
  const forwardedPath = url.searchParams.get('__path')

  if (forwardedPath) {
    url.searchParams.delete('__path')
    const query = url.searchParams.toString()
    request.url = `/api/${forwardedPath}${query ? `?${query}` : ''}`
  }

  return app(request, response)
}
