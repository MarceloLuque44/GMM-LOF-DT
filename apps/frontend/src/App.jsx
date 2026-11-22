import {
  Activity, Bell, BookOpenCheck, Check, ChevronRight, CircleDot,
  ClipboardList, Database, FileSearch, FlaskConical, LayoutDashboard,
  Menu, Network, RefreshCw, ShieldCheck, Sparkles, TableProperties, X,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { checkHealth, getAnalysisSteps, getDashboard, getLogs } from './api.js'

const tabs = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'analysis', label: 'Pasos del análisis', icon: FlaskConical },
  { id: 'logs', label: 'Bitácora', icon: ClipboardList },
]

const variables = [
  { code: 'ylab', label: 'Ingreso laboral total', unit: 'Bs/mes' },
  { code: 'tothrs', label: 'Horas semanales totales', unit: 'horas' },
  { code: 'aestudio', label: 'Años de escolaridad', unit: 'años' },
  { code: 's1_03a', label: 'Edad cumplida', unit: 'años' },
  { code: 'yprilab', label: 'Ingreso ocupación principal', unit: 'Bs/mes' },
  { code: 'phrs', label: 'Horas ocupación principal', unit: 'horas' },
]

const fallbackSteps = [
  { number: 1, title: 'Selección de datos', description: 'Filtrar la población ocupada y conservar las seis variables laborales.', status: 'ready' },
  { number: 2, title: 'Preprocesamiento y limpieza', description: 'Auditar faltantes, duplicados, tipos y valores fuera de dominio.', status: 'pending' },
  { number: 3, title: 'Transformación', description: 'Imputar, transformar distribuciones asimétricas y estandarizar.', status: 'pending' },
  { number: 4, title: 'Minería con GMM', description: 'Estimar mezclas gaussianas e identificar observaciones de baja probabilidad.', status: 'pending' },
  { number: 5, title: 'Minería con LOF', description: 'Calcular densidad local y detectar perfiles poco frecuentes.', status: 'pending' },
  { number: 6, title: 'Evaluación e interpretación', description: 'Comparar resultados y caracterizar los perfiles laborales atípicos.', status: 'pending' },
]

const number = new Intl.NumberFormat('es-BO')
const dateTime = new Intl.DateTimeFormat('es-BO', { dateStyle: 'medium', timeStyle: 'short' })

function Sidebar({ activeTab, onSelect, open, onClose }) {
  return <>
    <button className={`sidebar-scrim ${open ? 'visible' : ''}`} onClick={onClose} aria-label="Cerrar navegación" />
    <aside className={`sidebar ${open ? 'open' : ''}`}>
      <div className="brand">
        <img src="/logo-umsa.png" alt="UMSA" />
        <div><strong>Perfiles laborales</strong><span>GMM · LOF</span></div>
        <button className="close-menu" onClick={onClose} aria-label="Cerrar menú"><X size={20} /></button>
      </div>
      <nav aria-label="Navegación principal">
        <p className="nav-label">ANÁLISIS ECE</p>
        {tabs.map(({ id, label, icon: Icon }) => <button
          className={`nav-item ${activeTab === id ? 'active' : ''}`} key={id}
          onClick={() => { onSelect(id); onClose() }}
        ><Icon size={19} strokeWidth={1.8} />{label}</button>)}
      </nav>
      <div className="sidebar-foot"><div className="system-card"><ShieldCheck size={20} /><div><strong>ECE 1T 2026</strong><span>6 variables seleccionadas</span></div></div></div>
    </aside>
  </>
}

function Dashboard({ data, loading, apiStatus }) {
  const metrics = [
    { label: 'Registros analizados', value: data?.totalRecords ?? 0, detail: 'Observaciones en PostgreSQL', icon: Database, tone: 'violet' },
    { label: 'Registros completos', value: data?.completeRecords ?? 0, detail: 'Sin faltantes en las 6 variables', icon: Check, tone: 'cyan' },
    { label: 'Perfiles atípicos', value: data?.anomalousRecords ?? 0, detail: 'Detectados por GMM o LOF', icon: Sparkles, tone: 'amber' },
    { label: 'Cambios documentados', value: data?.logEntries ?? 0, detail: 'Entradas en la bitácora', icon: BookOpenCheck, tone: 'green' },
  ]

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">VISTA GENERAL</p><h1>Dashboard del análisis</h1><p>Seguimiento del procesamiento de microdatos de la Encuesta Continua de Empleo.</p></div>
      <span className={`connection ${apiStatus}`}><CircleDot size={15} />{apiStatus === 'ready' ? 'API conectada' : apiStatus === 'checking' ? 'Conectando' : 'API sin conexión'}</span>
    </div>
    <div className="metrics-grid four">{metrics.map(({ label, value, detail, icon: Icon, tone }) => <article className="metric-card" key={label}>
      <div className={`metric-icon ${tone}`}><Icon size={22} /></div><p>{label}</p><strong>{loading ? '—' : number.format(value)}</strong><span>{detail}</span>
    </article>)}</div>
    <div className="dashboard-grid">
      <article className="panel variables-panel">
        <div className="panel-heading"><div><h2>Variables del modelo</h2><p>Selección definida en informe.tex</p></div><span className="count-badge">6 variables</span></div>
        <div className="variables-grid">{variables.map((variable, index) => <div className="variable" key={variable.code}>
          <span>{String(index + 1).padStart(2, '0')}</span><div><code>{variable.code}</code><strong>{variable.label}</strong></div><small>{variable.unit}</small>
        </div>)}</div>
      </article>
      <article className="panel status-panel">
        <div className="panel-heading"><div><h2>Estado del proyecto</h2><p>Integraciones y modelos</p></div></div>
        <div className="service-list">
          <div className="service"><span className="service-icon purple"><Database size={19} /></span><div><strong>PostgreSQL</strong><small>{data?.databaseConfigured ? 'Conexión configurada' : 'Configura DATABASE_URL'}</small></div><span className={`status ${data?.databaseConfigured ? 'ready' : 'pending'}`}>{data?.databaseConfigured ? 'Lista' : 'Pendiente'}</span></div>
          <div className="service"><span className="service-icon blue"><Activity size={19} /></span><div><strong>API Express</strong><small>Dashboard, pasos y bitácora</small></div><span className={`status ${apiStatus === 'ready' ? 'ready' : 'pending'}`}>{apiStatus === 'ready' ? 'Lista' : 'Revisar'}</span></div>
          <div className="service"><span className="service-icon orange"><Network size={19} /></span><div><strong>Modelos GMM / LOF</strong><small>Resultados almacenables en el esquema</small></div><span className="status configured">Preparado</span></div>
        </div>
      </article>
    </div>
  </>
}

function AnalysisSteps({ steps }) {
  return <>
    <div className="page-heading"><div><p className="eyebrow">METODOLOGÍA KDD</p><h1>Pasos del análisis</h1><p>Flujo reproducible para detectar y caracterizar perfiles laborales atípicos.</p></div></div>
    <div className="steps-layout">
      <section className="steps-list">{steps.map((step, index) => <article className={`step-card ${step.status}`} key={step.number}>
        <div className="step-number">{step.status === 'done' ? <Check size={18} /> : step.number}</div>
        <div><span>PASO {step.number}</span><h2>{step.title}</h2><p>{step.description}</p></div>
        {index < steps.length - 1 && <ChevronRight className="step-arrow" size={20} />}
      </article>)}</section>
      <aside className="analysis-aside"><div className="aside-icon"><FileSearch size={25} /></div><h2>Fuente del análisis</h2><p>Microdatos ECE, primer trimestre de 2026. El flujo aplica la metodología KDD descrita en el informe.</p><div className="mini-list">{variables.map((item) => <code key={item.code}>{item.code}</code>)}</div></aside>
    </div>
  </>
}

function Logbook({ entries, loading, error, onRefresh }) {
  return <>
    <div className="page-heading log-heading">
      <div><p className="eyebrow">TRAZABILIDAD</p><h1>Bitácora de cambios</h1><p>Registro de las reglas y acciones aplicadas durante la limpieza de datos.</p></div>
      <button className="refresh-button" onClick={onRefresh} disabled={loading}><RefreshCw size={16} />Actualizar</button>
    </div>
    <article className="panel table-panel">
      {error && <div className="inline-alert">No se pudo consultar la bitácora. Verifica la API y ejecuta el esquema SQL.</div>}
      <div className="table-wrap"><table>
        <thead><tr><th>Paso</th><th>Fecha / hora</th><th>Responsable</th><th>Variable</th><th>Problema</th><th>Acción realizada</th><th>Filas</th><th>Impacto</th></tr></thead>
        <tbody>
          {!loading && entries.map((entry) => <tr key={entry.id}>
            <td><span className="step-pill">#{entry.stepNumber}</span></td><td>{dateTime.format(new Date(entry.executedAt))}</td><td>{entry.responsible}</td><td><code>{entry.variable}</code></td><td>{entry.problemType}</td><td className="action-cell"><strong>{entry.action}</strong><small>{entry.methodology}</small></td><td>{number.format(entry.affectedRows)}</td><td>{entry.datasetImpact}</td>
          </tr>)}
          {!loading && !error && entries.length === 0 && <tr><td colSpan="8"><div className="table-empty"><TableProperties size={28} /><strong>La bitácora está vacía</strong><span>Las acciones registradas en PostgreSQL aparecerán aquí.</span></div></td></tr>}
          {loading && <tr><td colSpan="8"><div className="table-empty"><RefreshCw className="spin" size={26} /><strong>Cargando bitácora…</strong></div></td></tr>}
        </tbody>
      </table></div>
    </article>
  </>
}

function App() {
  const [activeTab, setActiveTab] = useState('dashboard')
  const [menuOpen, setMenuOpen] = useState(false)
  const [apiStatus, setApiStatus] = useState('checking')
  const [dashboard, setDashboard] = useState(null)
  const [steps, setSteps] = useState(fallbackSteps)
  const [logs, setLogs] = useState([])
  const [loading, setLoading] = useState(true)
  const [logsError, setLogsError] = useState(false)

  const loadData = async () => {
    setLoading(true); setLogsError(false)
    const [healthResult, dashboardResult, stepsResult, logsResult] = await Promise.allSettled([checkHealth(), getDashboard(), getAnalysisSteps(), getLogs()])
    setApiStatus(healthResult.status === 'fulfilled' && healthResult.value?.status === 'ok' ? 'ready' : 'offline')
    if (dashboardResult.status === 'fulfilled') setDashboard(dashboardResult.value)
    if (stepsResult.status === 'fulfilled') setSteps(stepsResult.value.steps)
    if (logsResult.status === 'fulfilled') setLogs(logsResult.value.entries)
    else setLogsError(true)
    setLoading(false)
  }

  useEffect(() => { loadData() }, [])

  return <div className="app-shell">
    <Sidebar activeTab={activeTab} onSelect={setActiveTab} open={menuOpen} onClose={() => setMenuOpen(false)} />
    <main>
      <header className="topbar">
        <button className="menu-button" onClick={() => setMenuOpen(true)} aria-label="Abrir menú"><Menu size={22} /></button>
        <div className="topbar-title"><span>Proyecto GMM · LOF</span><small>Encuesta Continua de Empleo</small></div>
        <div className="topbar-actions"><button className="icon-button" aria-label="Notificaciones"><Bell size={20} /></button><div className="divider" /><div className="profile"><span className="avatar">ML</span><span className="profile-copy"><strong>Marcelo Luque Tarqui</strong><small>Responsable del análisis</small></span></div></div>
      </header>
      <section className="content">
        {activeTab === 'dashboard' && <Dashboard data={dashboard} loading={loading} apiStatus={apiStatus} />}
        {activeTab === 'analysis' && <AnalysisSteps steps={steps} />}
        {activeTab === 'logs' && <Logbook entries={logs} loading={loading} error={logsError} onRefresh={loadData} />}
      </section>
    </main>
  </div>
}

export default App
