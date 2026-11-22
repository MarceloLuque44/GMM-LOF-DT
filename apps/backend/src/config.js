const toBoolean = (value, fallback) => {
  if (value === undefined) return fallback
  return value.toLowerCase() === 'true'
}

const toPositiveInteger = (value, fallback) => {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback
}

const toOriginList = (value) => {
  if (!value) return []
  return value
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
}

export const config = {
  nodeEnv: process.env.NODE_ENV ?? 'development',
  port: toPositiveInteger(process.env.PORT, 3001),
  databaseUrl: process.env.DATABASE_URL,
  dbPoolMax: toPositiveInteger(process.env.DB_POOL_MAX, 3),
  dbSsl: toBoolean(process.env.DB_SSL, true),
  dbSslRejectUnauthorized: toBoolean(
    process.env.DB_SSL_REJECT_UNAUTHORIZED,
    false,
  ),
  corsOrigins: toOriginList(process.env.CORS_ORIGIN),
}
