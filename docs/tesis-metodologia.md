# Sportify — Metodología de la Investigación y Detalle del Proyecto

**Última actualización:** 2026-06-10

---

## Metodología de la Investigación

### Área Temática

Informática aplicada al deporte amateur, con foco en inteligencia artificial y visión por computadora. Específicamente, la investigación se enmarca en la reconstrucción automática del estado de juego en partidos de fútbol amateur a partir de video, abordando los desafíos de eficiencia computacional y viabilidad económica a escala.

---

### Planteamiento del Problema

El fútbol amateur carece de herramientas objetivas y accesibles para medir el rendimiento de jugadores y equipos. La organización de partidos depende del conocimiento informal de capitanes y organizadores, y la evaluación del nivel de juego es subjetiva y no escalable. Jugadores nuevos no tienen forma confiable de encontrar partidos equilibrados.

Los sistemas académicos existentes de reconstrucción de estado de juego —como el pipeline de SoccerNet Game State Reconstruction (GSR)— demuestran que el problema es técnicamente abordable, pero presentan una barrera crítica: su pipeline de extremo a extremo corre a aproximadamente **1.1 FPS** en una GPU A100, lo que implica **~36 horas de tiempo de procesamiento por partido de 90 minutos**. Este costo computacional hace inviable cualquier producto que deba procesar múltiples partidos de forma económica y recurrente.

No existe una solución que combine reconstrucción precisa del estado de juego con infraestructura accesible (servidor privado virtual, sin dependencia de cloud gestionado) para el contexto amateur.

---

### Delimitación de la Investigación

La investigación se delimita de la siguiente manera:

- **Dominio:** fútbol amateur grabado con cámara fija elevada en vista lateral (DJI Osmo 360).
- **Problema central:** mejorar el throughput de reconstrucción de estado de juego respecto al baseline de SoccerNet GSR (~1.1 FPS), ejecutando el pipeline en un VPS con GPU.
- **Entregable principal:** pipeline de reconstrucción que produce, por cada fotograma o cada _k_ fotogramas, la posición y la identidad de cada jugador sobre el campo.
- **Fuera del alcance de esta investigación:**
  - Sistemas de puntuación y matchmaking (sistemas separados, parte de la tesis pero no de este pipeline).
  - Detección de eventos (pases, goles, posesión) — diferida, sin fecha.
  - Infraestructura de nube gestionada (AWS, GCP, etc.).
  - Calibración de cámara por fotograma (reemplazada por homografía precalculada por venue).

---

### Marco Teórico

La investigación se apoya en los siguientes pilares conceptuales y tecnológicos:

**Visión por computadora y detección de objetos**
Se utiliza YOLO (You Only Look Once) como detector de jugadores en tiempo real. YOLO es un modelo de detección de objetos de una sola pasada que ofrece alta velocidad sin sacrificar precisión de forma significativa, adecuado para procesamiento en batch de video deportivo.

**Seguimiento multiobjetivo (Multi-Object Tracking)**
ByteTrack (u algoritmos equivalentes como SORT/DeepSORT) mantiene la continuidad de identidad de cada jugador a lo largo de fotogramas consecutivos, asignando un _track ID_ estable antes de intentar la asociación con la identidad real del jugador.

**Re-identificación de personas (ReID)**
PRTReID se utiliza para asociar tracks no mapeados con jugadores conocidos a partir de descriptores visuales. Este paso es **condicional**: solo se ejecuta cuando un track no tiene aún una identidad asignada (_user\_id_), evitando el costo de correrlo en cada fotograma como hace SoccerNet.

**OCR de números de camiseta**
MMOCR permite leer el número de camiseta de un jugador, que luego se resuelve contra el roster del equipo (número → identidad de usuario). Al igual que ReID, se ejecuta de forma condicional.

**Homografía y calibración de cámara**
La transformación entre coordenadas de imagen y coordenadas del campo se realiza mediante una matriz de homografía calculada **una sola vez durante la configuración del venue**. Esto elimina los módulos TVCalib de SoccerNet (calibración y localización de campo por fotograma), que representan una fracción significativa del costo computacional del baseline.

**SoccerNet Game State Reconstruction (GSR)**
Benchmark académico de referencia. Propone un pipeline de seis módulos que corre a ~1.1 FPS end-to-end en una A100, con métricas de evaluación estándar (GS-HOTA). Es el punto de comparación central de esta investigación.

---

### Diseño Concreto de Investigación

La investigación adopta un enfoque **aplicado y experimental**:

1. Se diseña e implementa un pipeline de reconstrucción de estado de juego optimizado para el contexto amateur (cámara fija, homografía precalculada, pasos condicionales).
2. Se ejecuta el pipeline sobre video de partido real (DJI Osmo 360) y sobre el dataset SoccerNet-GS.
3. Se mide el throughput efectivo (FPS de pared) y se compara contra el baseline publicado de SoccerNet GSR (~1.1 FPS en A100).
4. Se analiza la viabilidad del sistema en términos de costo computacional y tiempo de procesamiento por partido.

El diseño no busca superar a SoccerNet en precisión (GS-HOTA), sino demostrar que la reconstrucción puede ser **suficientemente rápida y económica** para ser viable en fútbol amateur a escala.

---

### Indicadores

| Indicador | Descripción | Meta provisional |
|-----------|-------------|-----------------|
| Throughput efectivo (FPS) | Fotogramas procesados por segundo en condiciones reales | Significativamente > 1.1 FPS |
| Tiempo de pared por partido | Tiempo total para procesar un partido de ~90 minutos | Horas, no días |
| Costo computacional por partido | Horas de GPU × costo/hora del VPS | Viable económicamente a escala |
| Tasa de identificación | % de tracks correctamente asignados a un _user\_id_ | TBD al avanzar la implementación |

---

### Técnicas de Recolección de Datos

- **Benchmarking controlado:** ejecución del pipeline sobre clips de video de duración y condiciones conocidas, midiendo throughput y tiempo de pared.
- **Experimentación por ablación:** comparación de versiones del pipeline con y sin pasos condicionales para cuantificar el impacto de cada optimización.
- **Registro de métricas de sistema:** uso de herramientas de profiling de Python y CUDA para identificar cuellos de botella.

---

### Instrumentos de Recolección de Datos

- Harness de benchmark propio, versionado en el repositorio del proyecto.
- Dataset SoccerNet-GS (video de partidos con anotaciones de estado de juego).
- Video de partido amateur grabado con DJI Osmo 360.
- Herramientas de medición de tiempo de pared (`time`, profilers de Python/CUDA).
- Registro de logs del pipeline (throughput, frames procesados, activaciones de pasos condicionales).

---

### Datos

| Fuente | Descripción | Uso |
|--------|-------------|-----|
| SoccerNet-GS | Dataset público con video de partidos y anotaciones | Validación y comparación con baseline |
| Video amateur (DJI Osmo 360) | Partido real grabado en condiciones de uso previsto | Prueba en contexto real |
| Metadatos de venue | Homografía precalculada + dimensiones del campo | Entrada al pipeline de reconstrucción |
| Roster de equipos | Tabla número de camiseta → identidad de jugador | Resolución de identidades |

Los datos de video no se versionan en git; se gestionan via `SPORTIFY_DATA_ROOT` (por defecto `~/data/sportify`).

---

### Procesamiento de los Datos

El pipeline procesa el video en modo **batch** (partido completo tras la carga):

1. **Detección de jugadores** — YOLO genera bounding boxes por fotograma.
2. **Seguimiento multiobjetivo** — ByteTrack asigna y mantiene _track IDs_ entre fotogramas.
3. **Proyección al campo** — la homografía precalculada transforma posiciones de imagen a coordenadas del campo (metros).
4. **Asociación de identidades (condicional)** — para tracks sin _user\_id_ asignado: ReID + OCR de camiseta → lookup en roster.
5. **Emisión de artefactos** — serie temporal de posiciones e identidades, más métricas de throughput.

Los pasos de ReID y OCR se ejecutan **solo cuando un track no tiene identidad mapeada**, a diferencia de SoccerNet que los corre en cada fotograma.

---

### Análisis de los Datos

- Comparación cuantitativa del throughput medido (FPS de pared) contra el baseline de SoccerNet (~1.1 FPS en A100).
- Cálculo del tiempo estimado para procesar un partido completo de ~90 minutos bajo el nuevo pipeline.
- Análisis de la tasa de activación de pasos condicionales (ReID/OCR): qué proporción de frames los dispara y cuál es el impacto en throughput.
- Evaluación del costo económico por partido en el VPS elegido.

---

### Síntesis y Conclusiones

La hipótesis central es que eliminando la calibración de cámara por fotograma (reemplazada por homografía fija de venue) y condicionando los pasos costosos de ReID y OCR, es posible construir un pipeline de reconstrucción de estado de juego que sea **viable económicamente y lo suficientemente rápido** para procesar partidos de fútbol amateur a escala en un VPS, superando el throughput del baseline de SoccerNet GSR.

Las conclusiones evaluarán si esta hipótesis se verifica en la práctica, qué componentes representan los mayores cuellos de botella residuales, y qué tan aplicable es el sistema resultante en un contexto de producción real.

---

## Detalle del Proyecto

### Alcance

**El proyecto incluye:**
- Pipeline de reconstrucción de estado de juego (detección de jugadores, tracking multiobjetivo, proyección al campo, asociación de identidades).
- API de carga de video y cola de jobs en el VPS.
- Worker de GPU para procesamiento batch.
- Harness de benchmarking y comparación contra SoccerNet GSR.
- Documentación técnica del pipeline y resultados.

**El proyecto no incluye:**
- Sistema de puntuación de jugadores (en scope de la tesis como sistema separado; no parte de este pipeline).
- Sistema de matchmaking (ídem).
- Detección de eventos (pases, goles, posesión) — diferida sin fecha.
- Infraestructura de nube gestionada (AWS S3, Batch, etc.).
- Herramienta de cómputo de homografía de venue (puede vivir en otro repo; su output es input aquí).
- Inferencia en tiempo real o streaming (el pipeline es batch).

El alcance es **realista para los recursos disponibles** (un VPS con GPU, stack open-source, plazo hasta diciembre 2026).

---

### Tiempos

Cronograma provisional con cierre en diciembre 2026:

| Etapa | Período | Hitos clave |
|-------|---------|-------------|
| Revisión teórica y marco conceptual | Junio 2026 | Marco teórico completo, documentación de baseline SoccerNet |
| Diseño del pipeline y especificación técnica | Julio 2026 | Spec del pipeline aprobada, contratos de I/O definidos |
| Implementación: detección, tracking y proyección | Agosto – Septiembre 2026 | Pipeline base corriendo sobre video de prueba |
| Integración ReID + OCR + benchmarking | Octubre 2026 | Pipeline completo con pasos condicionales; primeras métricas de throughput |
| Validación, ajustes y redacción del informe | Noviembre 2026 | Benchmarks reproducibles; borrador del informe de tesis |
| Redacción final y defensa | Diciembre 2026 | Entrega final y presentación |

```
Jun     Jul     Ago     Sep     Oct     Nov     Dic
[Marco][Diseño][──Implementación──][Integr.][Valid.][Defensa]
```

> Las fechas son **provisorias**. Los plazos se ajustarán a medida que avance la implementación.

---

### Costos

Estimación provisional de recursos financieros necesarios:

| Ítem | Detalle | Costo estimado (USD) |
|------|---------|----------------------|
| VPS con GPU | ~USD 200–400/mes × 6 meses (ej. Hetzner GX2-120 o equivalente con RTX 4090) | 1.200 – 2.400 |
| Licencias de software | Stack 100% open-source (YOLO, ByteTrack, PRTReID, MMOCR, Python) | 0 |
| Cámara DJI Osmo 360 | Hardware para grabación de partidos reales (si no disponible) | ~500 |
| Acceso a dataset SoccerNet-GS | Descarga pública gratuita | 0 |
| Otros (electricidad, dominio, misceláneos) | — | ~100 |
| **Total estimado** | | **~1.800 – 3.000** |

> Los costos de VPS son los más variables y dependen del proveedor y la configuración elegidos. Se priorizan proveedores sin overhead de cloud (sin S3, sin Batch), para mantener el costo de experimentación bajo.

---

### Riesgos

| Riesgo | Probabilidad | Impacto | Estrategia de mitigación |
|--------|-------------|---------|--------------------------|
| Throughput insuficiente (pipeline no supera baseline) | Media | Alto | Diseño modular: cada componente puede sustituirse o ajustarse independientemente. Se pueden reducir resolución, stride de fotogramas o simplificar modelos. |
| Acceso limitado a video amateur real de calidad | Media | Medio | Uso del dataset SoccerNet-GS como proxy para validación técnica; el video propio es complementario. |
| Fallas de hardware o indisponibilidad del VPS | Baja | Alto | Backups periódicos de modelos, artefactos y código en git. Posibilidad de migrar a otro VPS con el mismo stack. |
| Tiempo de implementación subestimado | Media | Medio | El cronograma tiene margen explícito en noviembre para absorber desvíos sin comprometer la fecha de entrega. |
| Calidad insuficiente de OCR de camisetas en video amateur | Media | Medio | Combinación de ReID + OCR para asociación; el sistema puede funcionar parcialmente con solo ReID si OCR falla. |

---

### Calidad

Los mecanismos de aseguramiento de calidad incluyen:

- **Benchmarks reproducibles:** el harness de benchmark está versionado en git y puede ser re-ejecutado por cualquier evaluador con acceso al dataset y el VPS.
- **Comparación contra baseline publicado:** todas las afirmaciones de rendimiento se contrastan con el throughput documentado de SoccerNet GSR (~1.1 FPS en A100).
- **Métricas honestas:** se reporta tiempo de pared real (_wall-clock_), no throughput teórico ni medido en condiciones ideales no reproducibles.
- **Diseño modular:** cada componente del pipeline tiene contratos de entrada/salida documentados, lo que permite validarlos y reemplazarlos de forma independiente.
- **Revisión por el director de tesis:** avances y resultados son revisados periódicamente.
- **Cumplimiento ético:** el sistema no recopila datos biométricos sensibles; la identidad se resuelve únicamente a través del número de camiseta y el roster del equipo, con consentimiento implícito de los jugadores participantes.

---

### Recursos

**Humanos:**
- Autor de la tesis (desarrollador e investigador principal)
- Director de tesis (revisión, orientación académica)

**Tecnológicos:**
- VPS con GPU dedicada (Linux, CUDA)
- Python 3.x con stack de ML: YOLO (Ultralytics), ByteTrack, PRTReID, MMOCR
- Framework de inferencia: PyTorch
- Herramientas de benchmark y profiling
- Git para control de versiones del código y documentación

**Hardware:**
- VPS con GPU (modelo a confirmar, objetivo: RTX 4090 o equivalente)
- Cámara DJI Osmo 360 para grabación de partidos reales

**Datos:**
- Dataset SoccerNet-GS (descarga pública)
- Video de partido amateur propio

**Bibliográficos:**
- Cioppa et al., _SoccerNet Game State Reconstruction_ (2024)
- Papers de referencia: YOLO, ByteTrack, PRTReID, MMOCR, TVCalib
- Literatura sobre homografía y calibración de cámara en deportes

---

### Satisfacción

La satisfacción de los evaluadores y usuarios del sistema se medirá mediante los siguientes criterios:

- **Criterio técnico principal:** el throughput medido del pipeline propio supera el baseline de SoccerNet GSR (~1.1 FPS) de forma significativa, ejecutándose en un VPS sin infraestructura de cloud gestionado.
- **Criterio de viabilidad:** el tiempo de procesamiento para un partido de ~90 minutos se reduce de días a horas, demostrando que el sistema es práctico para uso recurrente.
- **Criterio de aplicabilidad:** demostración funcional sobre video real de partido amateur grabado con DJI Osmo 360, produciendo posiciones e identidades de jugadores como output.
- **Criterio académico:** evaluación positiva por parte del director y tribunal de tesis sobre la coherencia del diseño, la solidez del benchmark y la relevancia del problema abordado.
- **Criterio económico:** costo por partido procesado que sea razonablemente accesible para una plataforma amateur real, validando la hipótesis de escabilidad.
