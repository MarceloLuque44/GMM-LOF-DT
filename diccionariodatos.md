A continuación se presenta el **diccionario de datos detallado** para la base de datos procesada de la **Encuesta Continua de Empleo (ECE)** del Instituto Nacional de Estadística (INE) de Bolivia, estructurado por bloques temáticos.

---

### **1. Identificación, Geografía y Diseño Muestral**

| Variable | Descripción | Tipo de Dato | Valores / Dominio |
| :--- | :--- | :--- | :--- |
| **`id_hog_panel`** | Identificador único del hogar en el panel longitudinal | Texto / Numérico | Código compuesto de seguimiento longitudinal |
| **`id_hogar`** | Identificador del hogar en la muestra transversal | Texto / Numérico | Código de hogar dentro de la UPM/Vivienda |
| **`id_per_panel`** | Identificador único de la persona en el panel longitudinal | Texto / Numérico | Código de seguimiento de la persona en olas de panel |
| **`id_persona`** | Identificador único de la persona en la encuesta | Texto / Numérico | Identificador individual a nivel de registro |
| **`nro`** | Número de orden de la persona en el hogar | Numérico entero | `01`, `02`, `03`... (posición en el listado del hogar) |
| **`gestion`** | Año de levamiento de la encuesta | Numérico entero | Año correspondiente (ej. `2021`, `2022`, `2023`) |
| **`trimestre`** / **`trim`** | Trimestre de recolección de datos | Numérico entero | `1` = Trimestre 1, `2` = Trimestre 2, `3` = Trimestre 3, `4` = Trimestre 4 |
| **`panel`** | Identificador de la rotación del panel muestral | Numérico / Texto | Número o código del grupo de rotación muestral |
| **`meses`** | Mes de ejecución del levantamiento | Numérico entero | `1` a `12` (Enero a Diciembre) |
| **`semana`** | Semana de entrevista dentro del trimestre/mes | Numérico entero | Semana del trimestre (`1` a `13`) |
| **`depto`** | Departamento geográfico | Categórico | `1` Chuquisaca, `2` La Paz, `3` Cochabamba, `4` Oruro, `5` Potosí, `6` Tarija, `7` Santa Cruz, `8` Beni, `9` Pando |
| **`area`** | Área de residencia | Categórico | `1` = Urbana, `2` = Rural |
| **`estrato`** | Estrato de muestreo estadístico | Categórico | Código de estratificación geográfica y poblacional del INE |
| **`upm`** | Unidad Primaria de Muestreo | Numérico entero | Código del conglomerado muestral seleccionado |
| **`fact_mes_act`** | Factor de expansión mensual actualizado | Numérico continuo | Ponderador poblacional ajustado a proyecciones mensuales |
| **`fact_trim_act`** | Factor de expansión trimestral actualizado | Numérico continuo | Ponderador poblacional ajustado a proyecciones trimestrales |
| **`tipohogar`** | Tipología de la estructura del hogar | Categórico | `1` Unipersonal, `2` Nuclear, `3` Extenso, `4` Compuesto, `5` Sin núcleo |

---

### **2. Sección 1: Características Sociodemográficas y Educativas (`s1_xx`)**

| Variable | Descripción de la Variable | Tipo / Escala | Categorías / Valores de Respuesta |
| :--- | :--- | :--- | :--- |
| **`s1_02`** | Sexo del miembro del hogar | Categórico | `1` = Hombre, `2` = Mujer |
| **`s1_03a`** | Edad cumplida en años | Numérico entero | `00` = Menor de 1 año, `01` a `97` años, `98` = 98 años o más |
| **`s1_03ba`** | Día de nacimiento | Numérico entero | `1` a `31` |
| **`s1_03bb`** | Mes de nacimiento | Numérico entero | `1` a `12` |
| **`s1_03bc`** | Año de nacimiento | Numérico entero | Año de nacimiento (cuatro dígitos) |
| **`s1_05`** | Parentesco con la jefa o jefe de hogar | Categórico | `1` Jefe/a, `2` Cónyuge/Concubino, `3` Hijo/a, `4` Hijastro/a, `5` Nuera/Yerno, `6` Nieto/a, `7` Hermano/a, `8` Cuñado/a, `9` Padre/Madre, `10` Suegro/a, `11` Abuelo/a, `12` Otro pariente, `13` No pariente, `14` Empleada del hogar cama adentro |
| **`s1_07a`** | Nivel de instrucción más alto aprobado | Categórico | `10` Ninguno y no sabe leer, `11` Ninguno pero sabe leer, `12` Alfabetización, `13` Inicial, `21-23` Antiguo (Básico/Intermedio/Medio), `31-32` Anterior (Primaria/Secundaria), `41-42` Actual (Primaria/Secundaria), `51-52` Adultos, `61-65` Alternativa/Especial, `71` Normal/Magisterio, `72` Universidad Pública, `73` Universidad Privada, `74-76` Posgrado, `77-80` Técnico/Militar |
| **`s1_07b`** | Último curso o grado aprobado en el nivel | Numérico entero | Grado numérico aprobado en el nivel asignado en `s1_07a` |
| **`s1_08a`** | Nivel de educación anterior aprobado | Categórico | Mismas categorías de nivel educativo previa (`11-82`) |
| **`s1_08b`** | Curso o grado aprobado en el nivel anterior | Numérico entero | Grado numérico alcanzado en el nivel anterior |
| **`s1_09`** | Matriculación escolar o universitaria este año | Categórico | `1` = Sí, `2` = No |
| **`s1_13`** | Modalidad de asistencia a clases este año | Categórico | `1` = Sí, presencial; `2` = No asiste; `3` = Sí, en otra modalidad |
| **`s1_14`** | Razón principal de inasistencia a clases | Categórico | `1` Vacación, `2` Culminó estudios, `3` Enfermedad/Discapacidad, `4` Falta dinero, `5` Falta interés, `6` Labores del hogar/cuidado, `7` Ayuda en negocio familiar, `8` Trabajo, `9` Busca trabajo, `10` Tesis/Proyecto de grado, `11` Otro |
| **`s1_14esp`** | Especificación de otra razón de inasistencia | Texto libre | Texto declarado si eligió opción `11` en `s1_14` |
| **`s1_16`** | Estado civil o conyugal actual (12 años o más) | Categórico | `1` Soltera/o, `2` Casada/o, `3` Conviviente/Concubina/o, `4` Separada/o, `5` Divorciada/o, `6` Viuda/o |
| **`s1_17`** | Autoidentificación con pueblo indígena/afro | Categórico | `1` = Sí, `2` = No |
| **`s1_17ecod`** | Código de la nación o pueblo indígena (NPIOC) | Categórico | Código oficial de pertenencia a NPIOC (ej. Quechua, Aymara, Guaraní) |

---

### **3. Sección 2: Empleo - Condición de Actividad y Desocupación (`s2_01` a `s2_14`)**

| Variable | Descripción de la Variable | Tipo / Escala | Categorías / Valores de Respuesta |
| :--- | :--- | :--- | :--- |
| **`s2_01`** | Trabajos al menos una hora la semana pasada | Categórico | `1` = Sí, `2` = No |
| **`s2_02`** | Dedicación a actividades marginales/secundarias | Categórico | `1` Cultivo/crianza, `2` Negocio propio/familiar, `3` Venta ambulante, `4` Alimentos/artesanías para venta, `5` Servicios remunerados, `6` Otra actividad remunerada, `7` Ninguna actividad |
| **`s2_03`** | Ausencia temporal de un trabajo la semana pasada | Categórico | `1` Vacaciones, `2` Enfermedad, `3` Falta de materiales/clientes, `4` Huelga/paro, `5` Mal tiempo, `6` Suspensión, `7` Problemas personales, `8` Ninguno |
| **`s2_04`** | Disponibilidad inmediata para trabajar | Categórico | `1` = Sí, `2` = No |
| **`s2_05`** | Búsqueda activa de empleo en últimas 4 semanas | Categórico | `1` = Sí, `2` = No |
| **`s2_06`** | Razón principal por la que no buscó trabajo | Categórico | `1` Trabajo asegurado en <4 semanas, `2` Espera respuesta, `3` No cree encontrar, `4` Se cansó, `5` Espera mayor actividad, `6` Estudia/vacación, `7` Vejez/jubilación, `8` Corta edad, `9` Enfermedad/discapacidad, `10` No necesita, `11` Cuidado del hogar, `12` Otra causa |
| **`s2_06e`** | Especificación de otra razón de no búsqueda | Texto libre | Texto declarado si eligió opción `12` en `s2_06` |
| **`s2_07`** | Condición de inactividad declarada | Categórico | `1` Estudiante, `2` Ama de casa/cuidador, `3` Jubilado/Benemérito, `4` Enfermo/discapacidad, `5` Edad avanzada, `6` Otro |
| **`s2_07e`** | Especificación de otra condición de inactividad | Texto libre | Texto escrito si eligió opción `6` en `s2_07` |
| **`s2_08a`** | Gestión principal para buscar trabajo o negocio | Categórico | `1` Consultó empleadores, `2` Anuncios, `3` Bolsa de trabajo, `4` Amigos/parientes, `5` Capital/clientes, `6` Periódicos, `7` Plan de empleo, `8` Internet/redes sociales, `9` Otro |
| **`s2_08e`** | Especificación de otra gestión de búsqueda | Texto libre | Texto escrito si eligió opción `9` en `s2_08a` |
| **`s2_08b_a`**| Tiempo acumulado buscando trabajo (Monto) | Numérico entero | Valor numérico de duración de búsqueda |
| **`s2_08b_b`**| Unidad de tiempo de la búsqueda activa | Categórico | `2` = Semanas, `4` = Meses, `8` = Años |
| **`s2_09`** | ¿Ha trabajado alguna vez anteriormente? | Categórico | `1` = Sí, `2` = No |
| **`s2_09c`** | Categoría laboral en su última ocupación | Categórico | `1` Obrero/Empleado, `2` Cuenta propia, `3` Empleador sin salario, `4` Cooperativista, `5` Familiar no remunerado, `6` Aprendiz, `7` Empleada del hogar |
| **`s2_10cod`** | Código de su última ocupación (CNO) | Categórico | Código numérico del Clasificador Nacional de Ocupaciones |
| **`s2_11cod`** | Código de actividad económica anterior (CAEB) | Categórico | Código numérico del Clasificador de Actividades Económicas |
| **`s2_12a`** | Tiempo trabajado en la ocupación anterior (Monto)| Numérico entero | Valor numérico de duración de trabajo |
| **`s2_12b`** | Unidad del tiempo trabajado en empleo anterior | Categórico | `2` = Semanas, `4` = Meses, `8` = Años |
| **`s2_13a`** | Tiempo transcurrido desde que dejó de trabajar | Numérico entero | Valor numérico de inactividad laboral |
| **`s2_13b`** | Unidad del tiempo transcurrido sin trabajar | Categórico | `2` = Semanas, `4` = Meses, `8` = Años |
| **`s2_13a_a`**| Razón principal por la que dejó de trabajar | Categórico | `1` Despedido, `2` Fin de contrato, `3` Término de obra, `4` Mal negocio, `5` Salud, `6` Hogar/cuidado, `7` Edad avanzada, `8` Pandemia COVID-19, `9` Otro, `10` Estudio |
| **`s2_13a_ae`**| Especificación de otra razón de retiro | Texto libre | Texto ingresado si eligió opción `9` en `s2_13a_a` |

---

### **4. Sección 2: Ocupación Principal, Características del Establecimiento e Ingresos (`s2_15` a `s2_38`)**

| Variable | Descripción de la Variable | Tipo / Escala | Categorías / Valores de Respuesta |
| :--- | :--- | :--- | :--- |
| **`s2_15acod`**| Código de la ocupación u oficio principal (CNO) | Categórico | Código oficial de ocupación principal |
| **`s2_16acod`**| Código de actividad económica del lugar (CAEB)| Categórico | Código oficial de la rama de actividad económica |
| **`s2_17`** | Nombre o razón social del establecimiento | Texto libre | Nombre de la empresa, negocio o lugar de trabajo |
| **`s2_18`** | Categoría ocupacional en el trabajo principal | Categórico | `1` Obrero/Empleado, `2` Cuenta propia, `3` Empleador, `4` Cooperativista, `5` Familiar no remunerado, `6` Aprendiz, `7` Empleada del hogar |
| **`s2_21`** | Tipo de contrato laboral | Categórico | `1` Contrato a plazo fijo, `2` Compromiso por obra/trabajo, `3` Acuerdo verbal, `4` Planta/Ítem indefinido, `5` Sin contrato |
| **`s2_22`** | Administración del establecimiento | Categórico | `1` Administración Pública, `2` Empresa Pública, `3` Privada (Mediana/Grande), `4` Privada (Micro/Pyme/Familiar), `5` ONG, `6` Org. Internacionales |
| **`s2_23`** | Tenencia de Registro Tributario (NIT) | Categórico | `1` Régimen General, `2` Régimen Simplificado, `3` No tiene / En proceso, `4` No sabe |
| **`s2_24`** | Registros contables del negocio o establecimiento| Categórico | `1` Libros contables con contador, `2` Cuaderno personal de cuentas, `3` Sin registro contable, `4` No sabe/No responde |
| **`s2_25`** | Lugar físico donde realiza sus labores | Categórico | `1` Vivienda, `2A` Local exclusivo propio, `2B` Local del empleador, `2C` Predio agrícola/minero, `3` Puesto móvil, `4` Puesto fijo/quiosco, `5` Vehículo, `6` A domicilio, `7` Ambulante, `8` Ambulante de preventa, `9` Otro |
| **`s2_25e`** | Especificación de otro lugar de trabajo | Texto libre | Texto ingresado si respondió `9` en `s2_25` |
| **`s2_26`** | Número de trabajadores en la empresa/negocio | Numérico entero | Cantidad directa reportada de trabajadores |
| **`s2_26a`** | Rango de trabajadores a nivel país | Categórico | `1` 1 persona, `2` 2-5, `3` 6-10, `4` 11-20, `5` 21-30, `6` 31-50, `7` 51-100, `8` 101 o más personas |
| **`s2_28`** | Días regularmente trabajados por semana | Numérico entero | `1` a `7` días por semana |
| **`s2_29_h`** | Horas promedio trabajadas al día (Horas) | Numérico entero | Horas por día habituales |
| **`s2_29_m`** | Horas promedio trabajadas al día (Minutos) | Categórico | `00`, `15`, `30`, `45` minutos |
| **`s2_29a`** | Horas efectivas trabajadas la semana pasada | Categórico | `1` Menos horas que lo habitual, `2` Más horas, `3` Mismas horas |
| **`s2_29a_n`**| Número exacto de horas efectivas la semana pasada| Numérico entero | Cantidad numérica total de horas trabajadas |
| **`s2_33_v`** | Salario líquido de asalariados (Monto en Bs) | Numérico continuo | Ingreso neto en Bolivianos sin descuentos de ley |
| **`s2_33_f`** | Frecuencia de cobro del salario líquido | Categórico | `1` Diario, `2` Semanal, `3` Quincenal, `4` Mensual, `5` Bimestral, `6` Trimestral, `7` Semestral, `8` Anual |
| **`s2_36a`** | Seguro de Salud | Categórico | `1` = Sí tiene, `2` = No tiene |
| **`s2_36b`** | Vacaciones pagadas | Categórico | `1` = Sí tiene, `2` = No tiene |
| **`s2_36c`** | Aguinaldo de Navidad | Categórico | `1` = Sí recibe, `2` = No recibe |
| **`s2_36d`** | Otros beneficios laborales | Categórico | `1` = Sí recibe, `2` = No recibe |
| **`s2_37_v`** | Ingreso total bruto de trabajadores independientes| Numérico continuo | Monto en Bolivianos de ingresos brutos |
| **`s2_37_f`** | Frecuencia del ingreso independiente bruto | Categórico | `1` Diario a `8` Anual (Mismas frecuencias) |
| **`s2_38_v`** | Ingreso neto disponible para el hogar (Independ.)| Numérico continuo | Remanente en Bs tras deducir costos de producción |
| **`s2_38_f`** | Frecuencia del ingreso neto disponible | Categórico | `1` Diario a `8` Anual |

---

### **5. Sección 2: Ocupación Secundaria, Subutilización y Previsión Social (`s2_42` a `s2_64a`)**

| Variable | Descripción de la Variable | Tipo / Escala | Categorías / Valores de Respuesta |
| :--- | :--- | :--- | :--- |
| **`s2_42`** | Realización de un segundo trabajo/ocupación | Categórico | `1` = Sí, `2` = No |
| **`s2_57`** | Deseo de trabajar más horas a la semana | Categórico | `1` = Sí, `2` = No |
| **`s2_58`** | Disponibilidad inmediata para trabajar más horas | Categórico | `1` = Sí, `2` = No |
| **`s2_58b`** | Búsqueda activa de otro trabajo secundario | Categórico | `1` = Sí, `2` = No |
| **`s2_59`** | Gestiones hechas para trabajar más horas o buscar trabajo | Categórico | `1` Consultó empleadores, `2` Anuncios/CV, `3` Bolsa de trabajo, `4` Amigos/parientes, `5` Capital/clientes, `6` Periódicos, `7` Internet/redes, `8` Otro, `9` Ninguna |
| **`s2_59e`** | Especificación de otra gestión | Texto libre | Texto libre si eligió `8` en `s2_59` |
| **`s2_60`** | Razón principal por la que no trabajó más horas | Categórico | `1` No encuentra trabajo, `2` Falta clientes/financiamiento, `3` Falta insumos/tierra, `4` Enfermedad, `5` Motivos personales, `6` Labores de casa/cuidado, `7` Otros |
| **`s2_60e`** | Especificación de otro motivo | Texto libre | Texto libre si eligió `7` en `s2_60` |
| **`s2_64`** | Afiliación al sistema de pensiones (Gestora/AFP) | Categórico | `1` = Sí, `2` = No |
| **`s2_64a`** | Aporte efectivo actual a la Gestora / AFP | Categórico | `1` Sí, aporta el empleador; `2` Sí, aporta independiente; `3` Ya está jubilado/pensionista; `4` No aporta |

---

### **6. Variables Derivadas, Clasificadores e Indicadores Laborales (INE / OIT)**

| Variable | Descripción del Indicador | Tipo de Dato | Definición y Categorías |
| :--- | :--- | :--- | :--- |
| **`cmasi`** | Condición de asistencia escolar imputada | Categórico | `1` Asiste a educación formal, `2` No asiste |
| **`educ_prev`**| Nivel educativo previo estandarizado | Categórico | Nivel educativo codificado de forma comparativa |
| **`aestudio`** | Años de escolaridad acumulados | Numérico entero | Variable continua (`0` a `18` o más años de estudio) |
| **`niv_ed`** | Nivel educativo estandarizado alcanzado | Categórico | `0` Ninguno/Alfabetización, `1` Primaria, `2` Secundaria, `3` Técnico, `4` Superior/Universitario |
| **`niv_ed_g`** | Nivel educativo agrupado para econometría | Categórico | Recodificación de `niv_ed` en agregados de capital humano |
| **`pet`** | Población en Edad de Trabajar | Binario | `1` = En edad de trabajar (10 años o más en Bolivia), `0` = Menor de 10 años |
| **`pea`** | Población Económicamente Activa (Fuerza de Trabajo)| Binario | `1` = Pertenece a la PEA (Ocupado o Desocupado), `0` = Inactivo |
| **`pei`** | Población Económicamente Inactiva | Binario | `1` = Inactivo temporal o permanente, `0` = Activo (PEA) |
| **`peao`** | Población Ocupada | Binario | `1` = Ocupado (Trabajó \\(\ge 1\\) hora o estuvo ausente temporalmente), `0` = No ocupado |
| **`pead`** | Población Desocupada (Desempleo Abierto) | Binario | `1` = Desocupado (Buscó trabajo y está disponible), `0` = No desocupado |
| **`peadces`** | Desocupados Cesantes | Binario | `1` = Desocupado con experiencia laboral previa, `0` = Otro |
| **`peadasp`** | Desocupados Aspirantes | Binario | `1` = Desocupado que busca trabajo por primera vez, `0` = Otro |
| **`peit`** | Inactivos Típicos | Binario | `1` = Inactivo sin deseo ni disponibilidad de trabajo |
| **`peip`** | Inactivos Potenciales (Desocupación Oculta) | Binario | `1` = Inactivo disponible que no buscó por desánimo u otras causas |
| **`condact`** | Condición de Actividad Estandarizada | Categórico | `1` Ocupado, `2` Desocupado Cesante, `3` Desocupado Aspirante, `4` Inactivo |
| **`cob_uo`** | Código de Ocupación Principal (CNO estandarizado) | Categórico | Clasificador de ocupación armonizado a nivel de grandes grupos |
| **`caeb_uo`** | Código de Actividad Económica (CAEB estandarizado)| Categórico | Clasificador de sector económico armonizado |
| **`cob_op`** | Ocupación principal recodificada | Categórico | Categorías agregadas de ocupación |
| **`caeb_op`** | Actividad económica recodificada | Categórico | Sectores económicos agregados (Primario, Secundario, Terciario) |
| **`psubocup`** | Condición de Subempleo visible | Binario | `1` = Subempleado por insuficiencia de horas (trabaja < 38 hrs y desea/puede trabajar más), `0` = No subempleado |
| **`phrs`** | Horas semanales habituales en ocupación principal| Numérico continuo | `phrs = s2_28 * (s2_29_h + s2_29_m/60)` |
| **`tothrs`** | Total horas semanales habituales (todas las ocupaciones)| Numérico continuo | Suma de horas habituales de ocupación principal y secundaria |
| **`phrs_ef`** | Horas semanales efectivas en ocupación principal | Numérico continuo | Horas efectivamente trabajadas la semana de referencia |
| **`tothrs_ef`**| Total horas efectivas semanales (todas ocupaciones)| Numérico continuo | Suma de horas efectivas en todos los trabajos |
| **`yprilab`** | Ingreso laboral mensualizado de ocupación principal| Numérico continuo | Ingreso mensual estandarizado en Bolivianos (Bs) |
| **`ylab`** | Ingreso laboral mensualizado total | Numérico continuo | Suma del ingreso mensualizado de todas las ocupaciones (Bs) |

---

📊 Si lo requieres, podemos redactar un script en Python (`pandas`) para construir automáticamente la variable dependiente de **Informalidad Laboral** (Sector Informal vs. Empleo Informal) cruzando las variables `s2_18`, `s2_23`, `s2_24`, `s2_26a`, `s2_36a` y `s2_64a`.