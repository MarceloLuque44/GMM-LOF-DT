import { useEffect, useRef } from 'react'
import * as echarts from 'echarts/core'
import { BarChart, LineChart } from 'echarts/charts'
import { GridComponent, LegendComponent, TooltipComponent, DataZoomComponent, MarkLineComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'

echarts.use([BarChart, LineChart, GridComponent, LegendComponent, TooltipComponent, DataZoomComponent, MarkLineComponent, CanvasRenderer])

export default function EChart({ option, onPointClick, className = '' }) {
  const element = useRef(null)
  const clickHandler = useRef(onPointClick)

  useEffect(() => { clickHandler.current = onPointClick }, [onPointClick])

  useEffect(() => {
    const chart = echarts.init(element.current)
    const observer = new ResizeObserver(() => chart.resize())
    observer.observe(element.current)
    chart.on('click', (event) => clickHandler.current?.(event))
    return () => { observer.disconnect(); chart.dispose() }
  }, [])

  useEffect(() => {
    const chart = echarts.getInstanceByDom(element.current)
    chart?.setOption(option, true)
  }, [option])

  return <div ref={element} className={`echart ${className}`} role="img" aria-label={option.ariaLabel ?? 'Gráfico de resultados'} />
}
