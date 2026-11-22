// Cifras transcritas de docs/informe.tex (ECE, primer trimestre de 2026).
// El dashboard es una instantánea del informe; la bitácora consulta PostgreSQL.
export const report = {
  audited: 52061,
  employed: 28907,
  complete: 24275,
  completePercent: 46.63,
  excluded: 27786,
  candidatesPerModel: 243,
  sharedCandidates: 40,
  onlyGmm: 203,
  onlyLof: 203,
  neither: 23829,
  union: 446,
  jaccard: 0.0897,
  agreement: 0.9833,
  missing: [
    { code: 'ylab', count: 27786, percent: 53.37 },
    { code: 'tothrs', count: 23154, percent: 44.47 },
    { code: 'aestudio', count: 9055, percent: 17.39 },
    { code: 's1_03a', count: 0, percent: 0 },
    { code: 'yprilab', count: 27786, percent: 53.37 },
    { code: 'phrs', count: 23154, percent: 44.47 },
  ],
  extremes: [
    { code: 'ylab', iqr: 1208, z: 412 },
    { code: 'tothrs', iqr: 488, z: 0 },
    { code: 'aestudio', iqr: 0, z: 0 },
    { code: 's1_03a', iqr: 23, z: 12 },
    { code: 'yprilab', iqr: 1208, z: 412 },
    { code: 'phrs', iqr: 488, z: 0 },
  ],
  models: [
    { name: 'GMM', candidates: 243, threshold: 10.7690, medianIncome: 111.67, medianHours: 24 },
    { name: 'LOF', candidates: 243, threshold: 1.4156, medianIncome: 3300, medianHours: 44 },
  ],
  remainderMedianIncome: 2598,
}

export const variables = [
  { code: 'ylab', label: 'Ingreso laboral total', unit: 'Bs/mes' },
  { code: 'tothrs', label: 'Horas semanales totales', unit: 'horas' },
  { code: 'aestudio', label: 'Años de escolaridad', unit: 'años' },
  { code: 's1_03a', label: 'Edad cumplida', unit: 'años' },
  { code: 'yprilab', label: 'Ingreso ocupación principal', unit: 'Bs/mes' },
  { code: 'phrs', label: 'Horas ocupación principal', unit: 'horas' },
]

export const analysisSteps = [
  { number: 1, title: 'Selección y perfilado', description: 'Se auditaron 52.061 registros y seis variables laborales. Se identificaron faltantes estructurales en ingresos y horas.', result: '52.061 registros revisados' },
  { number: 2, title: 'Normalización y duplicados', description: 'Se validaron tipos e identificadores. No hubo conversiones ni identificadores duplicados; los perfiles coincidentes pertenecen a personas distintas.', result: '0 duplicados por identificador' },
  { number: 3, title: 'Faltantes y casos completos', description: 'Se seleccionaron 24.275 personas ocupadas con las seis variables completas. No se imputaron los 4.632 ingresos faltantes entre ocupados.', result: '24.275 casos · 46,63 % del total' },
  { number: 4, title: 'Extremos y consistencia', description: 'IQR y |Z| > 3 señalaron candidatos extremos, conservados para el análisis. Ninguna variable quedó fuera de los dominios comprobados.', result: '24.275 filas conservadas' },
  { number: 5, title: 'Transformación', description: 'Se aplicó log(1 + x) al ingreso y luego puntuación z a ingreso, horas, escolaridad y edad. Las seis variables originales permanecieron intactas.', result: '4 características no redundantes' },
  { number: 6, title: 'Minería con GMM', description: 'BIC seleccionó cuatro componentes VEI. La baja densidad con umbral P99 = 10,7690 señaló 243 perfiles.', result: '243 candidatos · 1,00 %' },
  { number: 7, title: 'Minería con LOF', description: 'Con minPts = 20 y umbral exploratorio P99 = 1,4156, LOF señaló 243 perfiles sobre los mismos casos.', result: '243 candidatos · 1,00 %' },
  { number: 8, title: 'Evaluación y comparación', description: 'Los modelos coincidieron en 40 candidatos; 203 fueron exclusivos de cada uno. Sin etiquetas externas, la interpretación es exploratoria.', result: 'Jaccard 0,0897 · acuerdo 98,33 %' },
]
