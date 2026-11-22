METODOLOGIA KDD
1. Selección de datos: Se eligen y recopilan los datos relevantes desde las fuentes o bases de datos según el objetivo del análisis.
Tema “Detección y caracterización de perfiles laborales atípicos en Bolivia mediante Modelos de Mezclas Gaussianas (GMM) y Factor de Valores Atípicos Locales (LOF), utilizando microdatos de la Encuesta Continua de Empleo (ECE)”.

Este tema es apropiado porque permite aplicar ambos algoritmos sobre las mismas variables y comparar cómo identifican personas con características laborales poco habituales.
1.1. Planteamiento del problema
En el mercado laboral boliviano existen trabajadores con distintas condiciones de empleo, ingresos, jornadas laborales, edades y niveles educativos.

Algunas combinaciones pueden resultar estadísticamente inusuales. Por ejemplo:
- Personas que trabajan muchas horas, pero reciben ingresos muy bajos.
- Trabajadores jóvenes con ingresos excepcionalmente altos respecto a perfiles similares.
- Personas con jornadas laborales reducidas e ingresos elevados.
- Trabajadores cuyos ingresos y horas laborales difieren considerablemente de otros dentro de la misma actividad económica.
El objetivo no sería identificar trabajadores problemáticos, sino detectar perfiles estadísticamente atípicos y comprender sus características.
1.2. Objetivos de investigación
Objetivo general

Detectar y caracterizar perfiles laborales atípicos en la población ocupada de Bolivia mediante la aplicación y comparación de los algoritmos GMM y LOF sobre los microdatos de la Encuesta Continua de Empleo.

Objetivos específicos
1.2.1. Realizar una auditoría y perfilado inicial de las variables laborales seleccionadas.
1.2.2. Preparar los datos mediante tratamiento de valores faltantes, transformaciones y estandarización.
1.2.3. Aplicar GMM para identificar observaciones de baja probabilidad según una mezcla de distribuciones gaussianas.
1.2.4. Aplicar LOF para detectar trabajadores con características poco frecuentes respecto a sus vecinos.
1.2.5. Comparar los resultados de ambos algoritmos e interpretar los perfiles laborales detectados.
1.3. Variables a utilizar
El diccionario oficial de la ECE contiene variables derivadas que facilitan este estudio, como ingresos laborales mensuales, horas trabajadas y años de estudio. 
anda.ine.gob.bo+1

Variable	Código de referencia	Utilidad
Ingreso laboral mensual	ylab	Detectar ingresos inusuales
Horas trabajadas semanales	tothrs	Identificar jornadas atípicas
Años de estudio	aestudio	Relacionar educación e ingresos
Edad	s1_03a	Identificar perfiles por etapa laboral
Ingreso ocupación principal	yprilab	Comparar ingresos de la ocupación principal
Horas ocupación principal	phrs	Analizar jornadas en la actividad principal

Para empezar, utilizaría únicamente ingreso mensual, horas semanales, edad y años de estudio. Posteriormente incorporaría la actividad económica o categoría ocupacional para analizar los resultados por grupos.




2. Preprocesamiento y limpieza: Se eliminan duplicados, se corrigen inconsistencias, se tratan valores faltantes y se filtra el ruido o datos atípicos.
- 2.1. Auditoría y perfilado inicial (Data Profiling)
    
    Antes de modificar cualquier dato, se evalúa el estado general del conjunto de datos (dataset) para identificar posibles anomalías.
    
    Acciones:
    
    - Inspección de tipos de datos: identificación de variables numéricas, de texto, fechas y valores booleanos.
    - Estadísticas descriptivas: cálculo de valores mínimos, máximos, medias y cantidad de valores faltantes por columna.
    - Cardinalidad: verificación de la cantidad de valores distintos que presentan las variables categóricas.
    
    Resultado: una lista inicial de anomalías que deben corregirse o analizarse.
    
- 2.2. Normalización de estructura y formatos
    
    Se homogenizan los formatos de las columnas para evitar errores de interpretación sintáctica y garantizar la uniformidad de los datos.
    
    Acciones:
    
    - Cadenas de texto: conversión a mayúsculas o minúsculas de manera coherente, eliminación de espacios en blanco al inicio y al final (trimming) y tratamiento de caracteres especiales o acentos inconsistentes.
    - Fechas y horas: conversión al estándar ISO 8601 (`YYYY-MM-DD`).
    - Tipos de datos: conversión explícita de columnas numéricas almacenadas como texto. Por ejemplo, transformar `"100.50"` en `100.50`.
- 2.3. Gestión de duplicados
    
    Consiste en identificar registros repetidos que pueden distorsionar los algoritmos de minería de datos o producir sesgos en los conteos y análisis.
    
    Acciones:
    
    - Identificación de duplicados exactos: detección de filas completamente idénticas.
    - Identificación de duplicados parciales: detección de registros que comparten un mismo identificador único, pero presentan algunas diferencias.
    - Regla de decisión: determinar si se debe conservar el primer registro, el más reciente o fusionar los campos faltantes antes de eliminar los duplicados.
- 2.4. Tratamiento de valores faltantes (Missing Data)
    
    Consiste en gestionar los valores vacíos (`NULL`, `NaN`, `N/A` o espacios en blanco), considerando su proporción y el patrón de pérdida de información.
    
    Estrategias:
    
    - Eliminación: eliminar una columna cuando presenta más del 50 % de valores faltantes o eliminar filas cuando contienen ausencias críticas que no pueden recuperarse.
    - Imputación estadística: reemplazar los valores faltantes por la media, cuando la distribución es aproximadamente normal y no presenta valores extremos importantes, o por la mediana cuando la distribución es sesgada.
    - Imputación categórica: crear una categoría denominada `"Desconocido"` o reemplazar los valores faltantes por la moda.
    - Imputación avanzada: utilizar algoritmos de vecinos más cercanos (K-Nearest Neighbors, KNN) o modelos de regresión para estimar los valores faltantes.
- 2.5. Detección y tratamiento de valores atípicos (Outliers)
    
    Consiste en identificar valores extremos que se alejan considerablemente del comportamiento general de una variable y que podrían afectar los análisis estadísticos o los modelos de minería de datos.
    
    Técnicas de detección:
    
    - Rango intercuartílico (IQR): identifica valores que se encuentran fuera de los límites establecidos por la siguiente expresión:
    
    \[
    [Q_1 - 1.5 \times IQR,\ Q_3 + 1.5 \times IQR]
    \]
    
    Donde:
    
    - \(Q_1\): primer cuartil.
    - \(Q_3\): tercer cuartil.
    - \(IQR = Q_3 - Q_1\): rango intercuartílico.
    - Z-Score: identifica valores cuya puntuación estandarizada cumple la siguiente condición:
    
    \[
    |Z| > 3
    \]
    
    Estrategias de tratamiento:
    
    - Capado (Winsorization): reemplazar los valores atípicos por los límites máximos o mínimos aceptables.
    - Transformación: aplicar transformaciones logarítmicas para reducir la escala de los valores extremos y suavizar la distribución.
    - Eliminación: eliminar los valores atípicos únicamente cuando se confirma que son consecuencia de errores de digitación o medición y no representan observaciones válidas.
- 2.6. Validación de consistencia y reglas de negocio
    
    Consiste en realizar una comprobación final para garantizar que los datos limpios tengan sentido lógico y sean coherentes con el contexto del dominio analizado.
    
    Ejemplos de validación:
    
    - Edad: no puede ser un número negativo ni mayor a 120 años.
    - Fechas: la fecha de alta debe ser posterior a la fecha de nacimiento.
    - Precios: el precio total debe ser igual al precio unitario multiplicado por la cantidad.
    
    \[
    Precio\_Total = Precio\_Unitario \times Cantidad
    \]



3. Transformación: Los datos se adaptan al formato adecuado mediante normalización, discretización, selección de características o reducción de dimensionalidad.
4. Minería de datos: Se aplican algoritmos (clasificación, regresión, clustering, reglas de asociación, detección de anomalías) para encontrar patrones y relaciones ocultas.
5. Evaluación e interpretación: Se validan los modelos y patrones obtenidos, se visualizan y se traducen en conocimiento accionable para la toma de decisiones.



