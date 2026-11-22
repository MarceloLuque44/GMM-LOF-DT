import pg from 'pg'
import { config } from './config.js'

const { Pool } = pg

let pool

const buildConnectionString = (databaseUrl) => {
  const url = new URL(databaseUrl)
  // El parámetro sslmode de la URL tiene prioridad sobre la opción `ssl` y en
  // versiones recientes de pg fuerza verify-full. Usamos la configuración
  // explícita de DB_SSL / DB_SSL_REJECT_UNAUTHORIZED en su lugar.
  url.searchParams.delete('sslmode')
  return url.toString()
}

export const getPool = () => {
  if (!config.databaseUrl) {
    throw new Error('DATABASE_URL no está configurada')
  }

  if (!pool) {
    pool = new Pool({
      connectionString: buildConnectionString(config.databaseUrl),
      max: config.dbPoolMax,
      ssl: config.dbSsl
        ? { rejectUnauthorized: config.dbSslRejectUnauthorized }
        : false,
    })
  }

  return pool
}
