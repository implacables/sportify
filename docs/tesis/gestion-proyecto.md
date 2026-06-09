# Gestión del Proyecto — Sportify (Prueba de Concepto)

**Proyecto Final de Ingeniería en Informática — Universidad del Salvador**

Dimensiones de la Metodología de Gestión de Proyectos: Alcance, Tiempos, Costos, Riesgos, Calidad, Recursos y Satisfacción.

---

## 1. Alcance

**Objetivo.** Demostrar la viabilidad técnica de una plataforma de análisis y emparejamiento para **fútbol amateur**, integrando como mínimo **tres subsistemas**:

1. **Reconstrucción del estado de juego.** A partir del video del partido, reconstruir las posiciones e identidades de los jugadores en la cancha. *Requisito central:* **superar el throughput del baseline SoccerNet GSR (~1,1 FPS end-to-end sobre GPU A100)**, apuntando a procesar un partido de ~90 minutos en **horas y no días**, ejecutando sobre un **VPS** (sin nube gestionada).
2. **Analítica.** A partir del tracking reconstruido, derivar métricas espaciales y un **score de dominancia** que cuantifique el rendimiento de cada equipo más allá del resultado.
3. **Emparejamiento (matchmaking).** Un sistema de rating de jugadores y equipos que se alimenta de la analítica (no solo de la diferencia de goles) y genera partidos parejos.

**Incluido en el alcance:** pipeline de reconstrucción optimizado; capa de datos por niveles (bronze/silver/gold); motor de rating y leaderboard; sistema de identidad jugador↔usuario; aplicación móvil de consumo.

**Fuera del alcance (del POC):** detección de eventos (pases, tiros, goles); infraestructura de nube gestionada a escala; precisión de nivel broadcast/profesional.

**Criterios de aceptación:** los tres subsistemas funcionando de forma integrada sobre footage real; throughput de reconstrucción medido **superior a 1,1 FPS** en hardware de referencia documentado; matchmaking que produce emparejamientos coherentes con un rating que converge; demostración del **puente analítica → rating** (la contribución original).

## 2. Tiempos

*Estructura por fases; las fechas concretas quedan a anclar al cronograma de la materia.*

| Fase | Contenido |
|------|-----------|
| F0 — Fundaciones | Entorno, modelo de datos, datos de muestra |
| F1 — Reconstrucción | Pipeline + benchmark de throughput vs SoccerNet |
| F2 — Analítica | Limpieza (silver) + métricas + score de dominancia |
| F3 — Matchmaking | Rating + emparejamiento |
| F4 — Integración | Los tres subsistemas + app + identidad |
| F5 — Validación | Mediciones, evaluaciones, documentación |

**Hito crítico temprano:** medir el throughput de reconstrucción cuanto antes, ya que es lo que define la viabilidad del proyecto. Se recomienda formalizar el cronograma con un diagrama de Gantt.

## 3. Costos

| Categoría | Detalle | Tipo | Monto |
|-----------|---------|------|-------|
| Infraestructura GPU/VPS | VPS con GPU rentada (reconstrucción y workers) | Recurrente | A calcular ($/mes × meses) |
| Almacenamiento | Videos de partidos y datos por-frame (parquet) | Recurrente | A calcular |
| Suscripciones a agentes de IA | Herramientas de desarrollo asistido | Recurrente | A calcular ($/mes) |
| Datasets | SoccerNet-GS, Metrica (abiertos) | — | $0 (abiertos) |

**Nota de diseño que reduce costos:** el uso de un VPS en lugar de nube gestionada (AWS Batch/S3) evita el overhead de facturación durante los experimentos.

## 4. Riesgos

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|--------|-------|---------|------------|
| R1 | La reconstrucción es más rápida que SoccerNet pero **no lo suficiente** para tener impacto real. | Media | Alto | Eliminar la calibración por-frame (homografía fija por venue); condicionar ReID/OCR; medir el throughput temprano; fijar un umbral objetivo de FPS. |
| R2 | El **matchmaking** no cumple las expectativas de emparejamiento (partidos desparejos). | Media | Alto | Usar un motor probado (OpenSkill / Plackett-Luce); validar con simulaciones; calibrar el peso de la dominancia. |
| R3 | El **sistema de identidad** no es lo bastante confiable para asociar jugador↔usuario. | Media | Alto | Política de identidad provisional/invitado; correr ReID y OCR en conjunto; umbral de confianza; usar los datos del árbitro como ground-truth. |
| R4 | **Tiempos:** el cronograma es largo y existe el riesgo de no terminar en plazo. | Media-Alta | Alto | Priorizar el núcleo (los tres subsistemas mínimos); construir incrementalmente; desacoplar las ramas para avanzar en paralelo. |
| R5 | El POC funciona para un partido aislado, pero **no se logra argumentar que sea viable a escala real** (muchos partidos y usuarios, a un costo por partido sostenible), por lo que la tesis no demuestra utilidad práctica. | Media | Medio | Arquitectura modular (monolito → microservicios) que habilita el crecimiento; modelo de costo por partido; documentar explícitamente el camino a escala. |
| R6 | La **calidad del tracking amateur** (ruido, oclusiones) degrada las métricas. | Media | Medio | Capa de limpieza (silver) robusta; priorizar métricas robustas independientes de la dirección de ataque; validar con ruido inyectado. |

## 5. Calidad

| Subsistema | Criterio de calidad | Cómo se verifica |
|------------|---------------------|------------------|
| Reconstrucción | El throughput supera el baseline; precisión mínima suficiente para alimentar la analítica | FPS medido vs SoccerNet (~1,1), en corridas reales (sin maquillar) |
| Analítica | Métricas válidas y robustas al tracking ruidoso | Contraste con implementaciones de referencia; validación con degradación sintética |
| Matchmaking | El rating converge; emparejamientos balanceados; margen justo | Simulaciones y métricas de balance |

**Calidad metodológica (transversal):** reproducibilidad (entornos fijados, datos versionados); trazabilidad (registro de decisiones y fuentes/papers); modularidad y pruebas (tests).

## 6. Recursos

- **Equipo:** Julián (analítica y matchmaking), Valentín (reconstrucción) y tutores.
- **Infraestructura:** VPS con GPU; almacenamiento.
- **Herramientas:** stack Go / Python / MongoDB; agentes de IA para el desarrollo.
- **Datos:** SoccerNet-GS y Metrica (abiertos); footage amateur propio.

## 7. Satisfacción

**Propuesta de valor diferencial:** emparejar usando **visión por computadora** — medir el skill a partir de cómo jugó realmente cada persona en el video, en lugar de la evaluación subjetiva y manual (capitanes que "conocen" a los jugadores). Esto es lo que hace única a la solución.

- **Jugadores:** skill medido **objetivamente** desde su juego real, no por opiniones, generando confianza en el emparejamiento.
- **Organizadores:** partidos parejos **sin depender** del conocimiento informal de nadie.
- **Evaluadores de tesis:** el aporte original es **usar visión por computadora para alimentar el matchmaking**, algo que hoy no existe en el fútbol amateur.
