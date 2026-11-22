import {
  Activity,
  Bell,
  ChartNoAxesCombined,
  ChevronDown,
  CircleHelp,
  Database,
  Gauge,
  LayoutDashboard,
  MapPinned,
  Menu,
  MoreHorizontal,
  Settings,
  ShieldCheck,
  Wind,
  X,
} from 'lucide-react'
import { useEffect, useState } from 'react'
import { checkHealth } from './api.js'

const navigation = [
  { label: 'Resumen', icon: LayoutDashboard, active: true },
  { label: 'Monitoreo', icon: Activity },
  { label: 'Estaciones', icon: MapPinned },
  { label: 'Anomalías', icon: ChartNoAxesCombined },
]

const metrics = [
  { label: 'Estaciones activas', value: '—', detail: 'Sin datos conectados', icon: MapPinned, tone: 'violet' },
  { label: 'Calidad del aire', value: '—', detail: 'Esperando mediciones', icon: Wind, tone: 'cyan' },
  { label: 'Episodios detectados', value: '—', detail: 'Modelo pendiente', icon: Gauge, tone: 'amber' },
]

function Sidebar({ open, onClose }) {
  return (
    <>
      <button className={`sidebar-scrim ${open ? 'visible' : ''}`} onClick={onClose} aria-label="Cerrar navegación" />
      <aside className={`sidebar ${open ? 'open' : ''}`}>
        <div className="brand">
          <img src="/logo-umsa.png" alt="UMSA" />
          <div><strong>Aire Bolivia</strong><span>GMM · LOF</span></div>
          <button className="close-menu" onClick={onClose} aria-label="Cerrar menú"><X size={20} /></button>
        </div>
        <nav aria-label="Navegación principal">
          <p className="nav-label">PLATAFORMA</p>
          {navigation.map(({ label, icon: Icon, active }) => (
            <button className={`nav-item ${active ? 'active' : ''}`} key={label}>
              <Icon size={19} strokeWidth={1.8} />{label}
            </button>
          ))}
          <p className="nav-label nav-label-spaced">SISTEMA</p>
          <button className="nav-item"><Database size={19} />Base de datos</button>
          <button className="nav-item"><Settings size={19} />Configuración</button>
        </nav>
        <div className="sidebar-foot">
          <div className="system-card"><ShieldCheck size={20} /><div><strong>Configuración inicial</strong><span>Entorno preparado</span></div></div>
          <button className="help-link"><CircleHelp size={18} />Documentación</button>
        </div>
      </aside>
    </>
  )
}

function App() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [apiStatus, setApiStatus] = useState('checking')

  useEffect(() => {
    let active = true

    checkHealth()
      .then((health) => {
        if (active) setApiStatus(health?.status === 'ok' ? 'ready' : 'offline')
      })
      .catch(() => {
        if (active) setApiStatus('offline')
      })

    return () => {
      active = false
    }
  }, [])

  return (
    <div className="app-shell">
      <Sidebar open={menuOpen} onClose={() => setMenuOpen(false)} />
      <main>
        <header className="topbar">
          <button className="menu-button" onClick={() => setMenuOpen(true)} aria-label="Abrir menú"><Menu size={22} /></button>
          <div className="topbar-title"><span>Panel de monitoreo</span><small>Calidad del aire en Bolivia</small></div>
          <div className="topbar-actions">
            <button className="icon-button" aria-label="Notificaciones"><Bell size={20} /></button>
            <div className="divider" />
            <button className="profile"><span className="avatar">AD</span><span className="profile-copy"><strong>Administrador</strong><small>Proyecto GMM</small></span><ChevronDown size={16} /></button>
          </div>
        </header>

        <section className="content">
          <div className="page-heading">
            <div><p className="eyebrow">VISTA GENERAL</p><h1>Buenos días</h1><p>Este es el estado inicial de la plataforma de detección de anomalías.</p></div>
            <div className="period"><span>Periodo</span><button>Últimos 30 días <ChevronDown size={15} /></button></div>
          </div>

          <div className="metrics-grid">
            {metrics.map(({ label, value, detail, icon: Icon, tone }) => (
              <article className="metric-card" key={label}>
                <div className={`metric-icon ${tone}`}><Icon size={22} /></div>
                <button className="more" aria-label={`Opciones de ${label}`}><MoreHorizontal size={20} /></button>
                <p>{label}</p><strong>{value}</strong><span>{detail}</span>
              </article>
            ))}
          </div>

          <div className="dashboard-grid">
            <article className="panel chart-panel">
              <div className="panel-heading"><div><h2>Índice de calidad del aire</h2><p>Evolución de las mediciones registradas</p></div><span className="pending-badge">Pendiente de datos</span></div>
              <div className="chart-placeholder" aria-label="Gráfico pendiente de datos">
                <div className="axis-lines"><i /><i /><i /><i /></div>
                <div className="empty-state"><span><ChartNoAxesCombined size={28} /></span><strong>Aún no hay mediciones</strong><p>Los datos aparecerán aquí cuando se conecten las estaciones.</p></div>
                <div className="axis-labels"><span>Sem 1</span><span>Sem 2</span><span>Sem 3</span><span>Sem 4</span></div>
              </div>
            </article>

            <article className="panel status-panel">
              <div className="panel-heading"><div><h2>Estado del sistema</h2><p>Servicios configurados</p></div></div>
              <div className="service-list">
                <div className="service"><span className="service-icon purple"><Database size={19} /></span><div><strong>PostgreSQL</strong><small>Variables configuradas</small></div><span className="status configured">Preparado</span></div>
                <div className="service"><span className="service-icon blue"><Activity size={19} /></span><div><strong>API Express</strong><small>{apiStatus === 'ready' ? 'Conectada y respondiendo' : apiStatus === 'checking' ? 'Verificando conexión' : 'Sin conexión con la API'}</small></div><span className={`status ${apiStatus === 'ready' ? 'ready' : apiStatus === 'checking' ? 'configured' : 'pending'}`}>{apiStatus === 'ready' ? 'Lista' : apiStatus === 'checking' ? 'Verificando' : 'Sin conexión'}</span></div>
                <div className="service"><span className="service-icon orange"><Gauge size={19} /></span><div><strong>Modelos GMM / LOF</strong><small>Sin integrar todavía</small></div><span className="status pending">Pendiente</span></div>
              </div>
              <div className="next-step"><strong>Siguiente paso</strong><p>Define el esquema de datos y conecta las primeras mediciones de calidad del aire.</p></div>
            </article>
          </div>
        </section>
      </main>
    </div>
  )
}

export default App

