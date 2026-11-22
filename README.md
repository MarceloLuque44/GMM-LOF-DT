# GMM · Calidad del aire

Monorepo inicial para el proyecto **Detección de episodios anómalos de contaminación atmosférica en Bolivia mediante GMM y LOF**.

## Estructura

```text
apps/frontend/   React + Vite (dashboard) — proyecto Vercel independiente
apps/backend/    Node.js + Express + pg — proyecto Vercel independiente
api/server.js    Adaptador serverless del monorepo (alternativa de un solo proyecto)
vercel.json      Configuración del monorepo (alternativa de un solo proyecto)
```

> pgAdmin es una herramienta de administración. La aplicación se conecta directamente a PostgreSQL mediante `pg`; las mismas credenciales pueden utilizarse desde pgAdmin.

## Desarrollo local

Requisitos: Node.js 20 o superior.

1. Instala dependencias con `npm install`.
2. Copia `apps/backend/.env.example` como `apps/backend/.env`.
3. Copia `apps/frontend/.env.example` como `apps/frontend/.env`.
4. Completa `apps/backend/.env` con los valores que ya existen en `Metadata.md`.
5. Ejecuta `sql/schema.sql` en PostgreSQL/Supabase para crear el esquema `gmm`.
6. Inicia ambos servicios con `npm run dev`.

El frontend queda en `http://localhost:5173` y la API en `http://localhost:3001`. El dashboard y los pasos del análisis muestran una instantánea estática de `docs/informe.tex`; la bitácora sí necesita la API y PostgreSQL.

### API de datos

| Recurso | Endpoints |
| --- | --- |
| Observaciones laborales | `GET/POST /api/observations`, `GET/PATCH/DELETE /api/observations/:id` |
| Variables para los modelos | `GET /api/model-variables` |
| Bitácora | `GET/POST /api/logs`, `GET /api/logs/series`, `GET/PATCH/DELETE /api/logs/:id` |

Los listados aceptan `page` y `limit`; las observaciones también aceptan `dataset` y `anomalous=true|false`.
`GET /api/logs/series` devuelve las entradas cronológicamente para el gráfico de filas afectadas; al seleccionar un punto se abre el detalle de esa entrada.

### Perfilado R y bitácora

El script `apps/R/perfilado_inicial.R` carga `apps/R/cliente_api.R` y, al terminar el perfilado, registra en la bitácora los faltantes detectados por variable y los duplicados exactos. Requiere los paquetes R `httr2` y `jsonlite`, la API en ejecución y el esquema SQL aplicado.

En PowerShell:

```powershell
$env:GMM_API_URL = "http://localhost:3001"
$env:GMM_RESPONSABLE = "Marcelo Luque Tarqui"
Rscript apps/R/inicio.R
```

`GMM_API_URL` usa `http://localhost:3001` por defecto y `GMM_DATASET` usa `ECE_1T_2026`.

Para reutilizar `perfil_variables.csv` y enviar la bitácora sin esperar la regeneración de gráficos:

```powershell
Rscript apps/R/inicio.R --solo-api
```

También puede generarse únicamente el perfil y los gráficos con `--solo-perfilado`.

Las etapas 2.2 a 5.1 se ejecutan secuencialmente en la misma sesión R con:

```powershell
Rscript apps/R/inicio.R --hasta-05-01
```

El dataset de trabajo permanece como `data.frame`/`data.table` en R. `id_persona` mantiene la correspondencia entre etapas; no se carga el dataset completo al backend. Las puntuaciones individuales de GMM y LOF permanecen en R y se envían únicamente resúmenes verificables a la bitácora. Los archivos `resumen_*.csv` y las figuras de cada etapa son resultados agregados, no copias del dataset. Las respuestas verificadas de la API quedan en `apps/R/output/respuestas_api.csv`.

Puede detenerse en cualquier etapa con `--hasta-02-02`, `--hasta-02-03`, `--hasta-02-04`, `--hasta-02-05`, `--hasta-02-06`, `--hasta-03`, `--hasta-04-01`, `--hasta-04-02` o `--hasta-05`. Una falla detiene la secuencia y se registra en `apps/R/output/errores_sincronizacion.csv`. La sincronización consulta la bitácora y omite marcadores de entrada ya persistidos al reintentar. `mclust` y `dbscan` deben instalarse en `apps/R/library` para ejecutar los modelos.

Para conservar el dataframe final y las puntuaciones en una sesión R interactiva:

```r
Sys.setlocale("LC_CTYPE", "")
Sys.setenv(GMM_HASTA_ETAPA = "05-01")
source("apps/R/inicio.R", encoding = "UTF-8")
# datos_05_01 contiene id_persona, seis variables originales y resultados individuales.
```

## Variables de entorno

### Backend (`apps/backend/.env`)

| Variable | Requerida | Uso |
| --- | --- | --- |
| `DATABASE_URL` | Sí | Cadena de conexión PostgreSQL/Supabase |
| `DB_SSL` | Sí | Activa SSL para PostgreSQL |
| `DB_SSL_REJECT_UNAUTHORIZED` | Sí | Controla la validación del certificado |
| `DB_POOL_MAX` | Sí | Máximo de conexiones del pool serverless |
| `CORS_ORIGIN` | Recomendada | URL del frontend autorizada (varias separadas por coma) |
| `PORT` | Solo local | Puerto de Express; por defecto `3001` |

### Frontend (`apps/frontend/.env`)

| Variable | Requerida | Uso |
| --- | --- | --- |
| `VITE_API_URL` | Sí en Vercel | URL pública del backend, sin `/` final. En local: `http://localhost:3001` |

No se deben exponer variables de base de datos con el prefijo `VITE_`, porque ese prefijo las incluye en el bundle público del navegador.

## Despliegue en Vercel (dos proyectos)

Este repositorio se despliega como **dos proyectos independientes** que comparten el monorepo.

### 1. Backend

1. Importa el repositorio y crea un proyecto con **Root Directory**: `apps/backend`.
2. Framework preset: **Other**. No requiere build; Vercel publica `api/index.js` como función serverless.
3. Agrega en **Settings → Environment Variables** (Production, Preview y Development):
   `DATABASE_URL`, `DB_SSL`, `DB_SSL_REJECT_UNAUTHORIZED`, `DB_POOL_MAX` y `CORS_ORIGIN`.
4. `CORS_ORIGIN` debe ser la URL del frontend, por ejemplo `https://gmm-frontend.vercel.app`.
5. Despliega y verifica `https://tu-backend.vercel.app/api/health`.

### 2. Frontend

1. Crea otro proyecto con **Root Directory**: `apps/frontend`.
2. Framework preset: **Vite**; build `npm run build` y output `dist` (ya definidos en `apps/frontend/vercel.json`).
3. Define `VITE_API_URL` con la URL del backend, por ejemplo `https://tu-backend.vercel.app`.
4. Despliega. La variable se incrusta en el bundle durante el build, así que vuelve a desplegar si cambia.

También puedes configurar las variables mediante CLI sin escribir secretos en el repositorio:

```bash
vercel env add DATABASE_URL
vercel env add DB_SSL
vercel env add DB_SSL_REJECT_UNAUTHORIZED
vercel env add DB_POOL_MAX
vercel env add CORS_ORIGIN
vercel env add VITE_API_URL
```


## Comandos

- `npm run dev`: frontend y backend en paralelo.
- `npm run build`: genera el frontend para producción.
- `npm run check`: valida ESLint y la sintaxis del backend.
- `npm start`: ejecuta la API localmente.

