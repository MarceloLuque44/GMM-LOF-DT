import {
  BookOpenCheck, Check, ClipboardList, Database, FileSearch, FlaskConical,
  LayoutDashboard, Menu, RefreshCw, Sparkles, TableProperties, X,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { getLogSeries } from './api.js'
import EChart from './EChart.jsx'
import { analysisSteps, report, variables } from './reportData.js'

const tabs = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'analysis', label: 'Pasos del análisis', icon: FlaskConical },
  { id: 'logs', label: 'Bitácora', icon: ClipboardList },
]

const number = new Intl.NumberFormat('es-BO')
const decimal = new Intl.NumberFormat('es-BO', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const dateTime = new Intl.DateTimeFormat('es-BO', { dateStyle: 'medium', timeStyle: 'short' })
const formatDate = (value) => {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '—' : dateTime.format(date)
}

const chartBase = {
  textStyle: { fontFamily: 'DM Sans, sans-serif', color: '#5e667a' },
  grid: { left: 72, right: 26, top: 28, bottom: 55 },
  tooltip: { trigger: 'axis', valueFormatter: (value) => number.format(value) },
}

const missingOption = {
  ...chartBase,
  ariaLabel: 'Porcentaje de valores faltantes por variable',
  grid: { left: 78, right: 40, top: 20, bottom: 34 },
  xAxis: { type: 'value', max: 60, name: '%', axisLabel: { formatter: '{value} %' } },
  yAxis: { type: 'category', inverse: true, data: report.missing.map((item) => item.code), axisTick: { show: false } },
  series: [{ type: 'bar', data: report.missing.map((item) => item.percent), itemStyle: { color: '#7061db', borderRadius: [0, 5, 5, 0] }, barMaxWidth: 21,
    markLine: { silent: true, symbol: 'none', lineStyle: { color: '#d68d43', type: 'dashed' }, label: { formatter: '50 %' }, data: [{ xAxis: 50 }] },
  }],
}

const comparisonOption = {
  ...chartBase,
  ariaLabel: 'Candidatos exclusivos y compartidos entre GMM y LOF',
  legend: { bottom: 0 },
  grid: { left: 48, right: 20, top: 20, bottom: 65 },
  xAxis: { type: 'category', data: ['GMM', 'LOF'], axisTick: { show: false } },
  yAxis: { type: 'value', max: 260 },
  series: [
    { name: 'Compartidos', type: 'bar', stack: 'candidatos', data: [40, 40], itemStyle: { color: '#40a9a0' }, label: { show: true, position: 'inside', color: '#fff' }, barMaxWidth: 65 },
    { name: 'Exclusivos', type: 'bar', stack: 'candidatos', data: [203, 203], itemStyle: { color: '#7768df', borderRadius: [5, 5, 0, 0] }, label: { show: true, position: 'inside', color: '#fff' } },
  ],
}

const incomeOption = {
  ...chartBase,
  ariaLabel: 'Ingreso mediano de candidatos GMM, candidatos LOF y resto',
  grid: { left: 72, right: 22, top: 20, bottom: 55 },
  xAxis: { type: 'category', data: ['GMM', 'LOF', 'Resto'], axisLabel: { interval: 0 } },
  yAxis: { type: 'value', name: 'Bs/mes' },
  series: [{ type: 'bar', barMaxWidth: 54, data: [
    { value: 111.67, itemStyle: { color: '#7768df' } },
    { value: 3300, itemStyle: { color: '#40a9a0' } },
    { value: 2598, itemStyle: { color: '#e3a355' } },
  ], label: { show: true, position: 'top', formatter: ({ value }) => number.format(value) } }],
}

const extremesOption = {
  ...chartBase,
  ariaLabel: 'Candidatos extremos por IQR y valor absoluto de Z mayor que tres',
  legend: { bottom: 0 },
  grid: { left: 62, right: 22, top: 20, bottom: 75 },
  xAxis: { type: 'category', data: report.extremes.map((item) => item.code), axisLabel: { rotate: 30, interval: 0 } },
  yAxis: { type: 'value' },
  series: [
    { name: 'IQR', type: 'bar', data: report.extremes.map((item) => item.iqr), itemStyle: { color: '#7768df' } },
    { name: '|Z| > 3', type: 'bar', data: report.extremes.map((item) => item.z), itemStyle: { color: '#e3a355' } },
  ],
}

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
      <div className="sidebar-foot"><div className="system-card"><BookOpenCheck size={20} /><div><strong>ECE 1T 2026</strong><span>Resultados del informe</span></div></div></div>
    </aside>
  </>
}

function ChartPanel({ title, description, option, className = '' }) {
  return <article className={`panel chart-panel ${className}`}>
    <div className="panel-heading"><div><h2>{title}</h2><p>{description}</p></div></div>
    <EChart option={option} />
  </article>
}

function Dashboard() {
  const metrics = [
    { label: 'Registros auditados', value: report.audited, detail: 'ECE, primer trimestre de 2026', icon: Database, tone: 'violet' },
    { label: 'Casos completos', value: report.complete, detail: `${decimal.format(report.completePercent)} % del total`, icon: Check, tone: 'cyan' },
    { label: 'Candidatos distintos', value: report.union, detail: 'Señalados por GMM o LOF', icon: Sparkles, tone: 'amber' },
    { label: 'Coincidencia de modelos', value: report.sharedCandidates, detail: 'Candidatos señalados por ambos', icon: BookOpenCheck, tone: 'green' },
  ]

  return <>
    <div className="page-heading">
      <div><p className="eyebrow">RESULTADOS · ECE 1T 2026</p><h1>Dashboard del análisis</h1><p>Resultados descriptivos publicados en el informe de GMM y LOF.</p></div>
      <span className="count-badge">Datos estáticos del informe</span>
    </div>
    <div className="metrics-grid">{metrics.map(({ label, value, detail, icon: Icon, tone }) => <article className="metric-card" key={label}>
      <div className={`metric-icon ${tone}`}><Icon size={22} /></div><p>{label}</p><strong>{number.format(value)}</strong><span>{detail}</span>
    </article>)}</div>
    <div className="results-grid">
      <ChartPanel title="Valores faltantes" description="Porcentaje sobre los 52.061 registros; umbral de referencia del 50 %." option={missingOption} />
      <ChartPanel title="Comparación GMM y LOF" description="Cada modelo señaló 243 personas; 40 aparecen en ambos conjuntos." option={comparisonOption} />
      <ChartPanel title="Ingreso mediano mensual" description="Candidatos por modelo frente al resto de la muestra, en bolivianos." option={incomeOption} />
      <ChartPanel title="Candidatos extremos por variable" description="Etiquetas exploratorias por IQR y |Z| > 3; las filas se conservaron." option={extremesOption} />
    </div>
    <div className="dashboard-grid">
      <article className="panel variables-panel">
        <div className="panel-heading"><div><h2>Variables auditadas</h2><p>Seis columnas laborales; los modelos usan cuatro características no redundantes.</p></div><span className="count-badge">6 variables</span></div>
        <div className="variables-grid">{variables.map((variable, index) => <div className="variable" key={variable.code}>
          <span>{String(index + 1).padStart(2, '0')}</span><div><code>{variable.code}</code><strong>{variable.label}</strong></div><small>{variable.unit}</small>
        </div>)}</div>
      </article>
      <article className="panel findings-panel">
        <div className="panel-heading"><div><h2>Lectura de resultados</h2><p>Conclusiones descriptivas del informe</p></div></div>
        <ul>
          <li><strong>Selección:</strong> {number.format(report.complete)} personas ocupadas con datos completos; no se imputaron ingresos faltantes.</li>
          <li><strong>Modelos:</strong> GMM usó cuatro componentes VEI; LOF, minPts = 20. Cada uno señaló 243 candidatos (1,00 %).</li>
          <li><strong>Acuerdo:</strong> Jaccard {decimal.format(report.jaccard)} y acuerdo global {decimal.format(report.agreement * 100)} %. Los desacuerdos se conservaron.</li>
          <li><strong>Alcance:</strong> son candidatos exploratorios; no hay etiquetas externas para medir precisión o sensibilidad.</li>
        </ul>
      </article>
    </div>
  </>
}

function AnalysisSteps() {
  return <>
    <div className="page-heading"><div><p className="eyebrow">METODOLOGÍA KDD</p><h1>Pasos del análisis</h1><p>Proceso y resultados documentados en <code>docs/informe.tex</code>.</p></div></div>
    <div className="steps-layout">
      <section className="steps-list">{analysisSteps.map((step) => <article className="step-card done" key={step.number}>
        <div className="step-number"><Check size={18} /></div>
        <div><span>PASO {step.number}</span><h2>{step.title}</h2><p>{step.description}</p><strong className="step-result">{step.result}</strong></div>
      </article>)}</section>
      <aside className="analysis-aside"><div className="aside-icon"><FileSearch size={25} /></div><h2>Fuente del análisis</h2><p>Microdatos de la ECE, primer trimestre de 2026. El informe conserva los identificadores y los valores laborales originales durante el proceso.</p><div className="mini-list">{variables.map((item) => <code key={item.code}>{item.code}</code>)}</div></aside>
    </div>
  </>
}

function LogDetails({ entry, onClose }) {
  useEffect(() => {
    const onKeyDown = (event) => { if (event.key === 'Escape') onClose() }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  }, [onClose])

  const fields = [
    ['Fecha / hora', formatDate(entry.executedAt)], ['Responsable', entry.responsible],
    ['Dataset', entry.dataset], ['Variable', entry.variable], ['Tipo de problema', entry.problemType],
    ['Metodología', entry.methodology], ['Acción realizada', entry.action],
    ['Justificación', entry.justification], ['Filas afectadas', number.format(Number(entry.affectedRows) || 0)],
    ['Impacto en el dataset', entry.datasetImpact], ['Código / script', entry.script],
  ]
  return <div className="modal-backdrop" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose() }}>
    <section className="log-modal" role="dialog" aria-modal="true" aria-labelledby="log-modal-title">
      <div className="modal-header"><div><p className="eyebrow">BITÁCORA · PASO {entry.stepNumber}</p><h2 id="log-modal-title">Detalle del registro #{entry.id}</h2></div><button onClick={onClose} aria-label="Cerrar detalle"><X size={20} /></button></div>
      <dl className="log-details">{fields.map(([label, value]) => <div key={label}><dt>{label}</dt><dd>{value ?? '—'}</dd></div>)}</dl>
    </section>
  </div>
}

function Logbook({ entries, loading, error, onRefresh }) {
  const [selected, setSelected] = useState(null)
  const chronological = [...entries].sort((a, b) => new Date(a.executedAt) - new Date(b.executedAt) || a.id - b.id)
  const logOption = {
    ...chartBase,
    ariaLabel: 'Filas afectadas por registro de la bitácora; seleccione un punto para ver el detalle',
    grid: { left: 68, right: 24, top: 22, bottom: chronological.length > 12 ? 90 : 64 },
    tooltip: { trigger: 'item', valueFormatter: (value) => `${number.format(value)} filas` },
    xAxis: { type: 'category', data: chronological.map((entry, index) => `#${index + 1} · P${entry.stepNumber}`), axisLabel: { rotate: chronological.length > 8 ? 45 : 0 } },
    yAxis: { type: 'value', name: 'Filas', minInterval: 1 },
    dataZoom: chronological.length > 18 ? [{ type: 'slider', bottom: 12, height: 20, start: 0, end: Math.max(10, 1800 / chronological.length) }] : [],
    series: [{ name: 'Filas afectadas', type: 'line', data: chronological.map((entry) => Number(entry.affectedRows) || 0), symbolSize: 11, showSymbol: true, lineStyle: { width: 3, color: '#7061db' }, itemStyle: { color: '#7061db' }, areaStyle: { color: '#efedff' } }],
  }

  return <>
    <div className="page-heading log-heading">
      <div><p className="eyebrow">TRAZABILIDAD · POSTGRESQL</p><h1>Bitácora de cambios</h1><p>Filas afectadas por cada acción registrada, en orden cronológico.</p></div>
      <button className="refresh-button" onClick={onRefresh} disabled={loading}><RefreshCw size={16} />Actualizar</button>
    </div>
    <article className="panel chart-panel log-chart-panel">
      <div className="panel-heading"><div><h2>Cambio en las filas por registro</h2><p>Selecciona un punto para consultar la información completa de la bitácora.</p></div><span className="count-badge">{number.format(entries.length)} registros</span></div>
      {loading ? <div className="chart-empty"><RefreshCw className="spin" size={22} /> Cargando bitácora…</div>
        : error ? <div className="inline-alert">No se pudo consultar la bitácora. Verifica la API y la conexión a PostgreSQL.</div>
          : chronological.length === 0 ? <div className="chart-empty"><TableProperties size={24} /> Aún no hay registros para graficar.</div>
            : <EChart option={logOption} onPointClick={(event) => { if (event.componentType === 'series') setSelected(chronological[event.dataIndex]) }} />}
    </article>
    <article className="panel table-panel log-table-panel">
      <div className="table-title"><div><h2>Registros de la bitácora</h2><p>Datos obtenidos desde <code>gmm.bitacora</code></p></div></div>
      <div className="table-wrap"><table>
        <thead><tr><th>Paso</th><th>Fecha / hora</th><th>Responsable</th><th>Variable</th><th>Problema</th><th>Acción realizada</th><th>Filas</th><th>Impacto</th></tr></thead>
        <tbody>
          {!loading && [...entries].reverse().map((entry) => <tr key={entry.id}>
            <td><span className="step-pill">#{entry.stepNumber}</span></td><td>{formatDate(entry.executedAt)}</td><td>{entry.responsible}</td><td><code>{entry.variable}</code></td><td>{entry.problemType}</td><td className="action-cell"><strong>{entry.action}</strong><small>{entry.methodology}</small></td><td>{number.format(Number(entry.affectedRows) || 0)}</td><td>{entry.datasetImpact}</td>
          </tr>)}
          {!loading && !error && entries.length === 0 && <tr><td colSpan="8"><div className="table-empty"><TableProperties size={28} /><strong>La bitácora está vacía</strong><span>Las acciones registradas en PostgreSQL aparecerán aquí.</span></div></td></tr>}
          {loading && <tr><td colSpan="8"><div className="table-empty"><RefreshCw className="spin" size={26} /><strong>Cargando bitácora…</strong></div></td></tr>}
        </tbody>
      </table></div>
    </article>
    {selected && <LogDetails entry={selected} onClose={() => setSelected(null)} />}
  </>
}

function App() {
  const [activeTab, setActiveTab] = useState('dashboard')
  const [menuOpen, setMenuOpen] = useState(false)
  const [entries, setEntries] = useState([])
  const [logsLoading, setLogsLoading] = useState(true)
  const [logsError, setLogsError] = useState(false)
  const [refreshKey, setRefreshKey] = useState(0)

  useEffect(() => {
    if (activeTab !== 'logs') return undefined
    let active = true
    getLogSeries().then((result) => {
      if (active) { setEntries(result.entries); setLogsError(false); setLogsLoading(false) }
    }).catch(() => {
      if (active) { setLogsError(true); setLogsLoading(false) }
    })
    return () => { active = false }
  }, [activeTab, refreshKey])

  const refreshLogs = () => { setLogsLoading(true); setRefreshKey((key) => key + 1) }

  return <div className="app-shell">
    <Sidebar activeTab={activeTab} onSelect={setActiveTab} open={menuOpen} onClose={() => setMenuOpen(false)} />
    <main>
      <header className="topbar">
        <button className="menu-button" onClick={() => setMenuOpen(true)} aria-label="Abrir menú"><Menu size={22} /></button>
        <div className="topbar-title"><span>Proyecto GMM · LOF</span><small>Encuesta Continua de Empleo</small></div>
        <div className="topbar-actions"><div className="profile"><span className="avatar">ML</span><span className="profile-copy"><strong>Marcelo Luque Tarqui</strong><small>Responsable del análisis</small></span></div></div>
      </header>
      <section className="content">
        {activeTab === 'dashboard' && <Dashboard />}
        {activeTab === 'analysis' && <AnalysisSteps />}
        {activeTab === 'logs' && <Logbook entries={entries} loading={logsLoading} error={logsError} onRefresh={refreshLogs} />}
      </section>
    </main>
  </div>
}

export default App
