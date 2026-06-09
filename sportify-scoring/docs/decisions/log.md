# Log de decisiones (ADR)

Registro de decisiones de arquitectura, una por entrada: **qué** se decidió, **por qué**, y **de dónde salió**. Para una tesis esto es la trazabilidad de cada elección.

> Formato: `ADR-NNN — Título` · Estado · Decisión · Por qué · Alternativas descartadas.

---

## ADR-001 — Sistema separado del POC de reconstrucción
**Estado:** aceptada (2026-06-09).
**Decisión:** scoring + matchmaking es un sistema propio (`sportify-scoring/`), separado de `sportify-game-reconstruction/`; consume su contrato per-frame.
**Por qué:** product-stages los define como sistemas de tesis separados. Acoplarlos mezclaría ciclos de vida y deploys distintos.

## ADR-002 — Dos ramas + puente de dominancia
**Estado:** aceptada.
**Decisión:** matchmaking (base, funciona solo) y analytics (medallón) como ramas desacopladas; el puente = dominancia derivada de analytics alimenta el margen del rating.
**Por qué:** el puente es la contribución original de la tesis [ref: `openskill`, `epv`]. Desacoplar permite construir en paralelo y que matchmaking ande con señal simple desde el día 1.

## ADR-003 — Arquitectura de datos: medallón
**Estado:** aceptada.
**Decisión:** bronze (crudo) → silver (limpio) → gold (features), como capas **lógicas** (no lakehouse). Silver es etapa propia antes de cualquier métrica.
**Por qué:** separa la limpieza (mayor riesgo: tracking amateur ruidoso) de las métricas; permite reprocesar sin molestar a upstream; da lineage/defendibilidad.
**Alternativas:** pipeline sin capas (pierde reprocesamiento y trazabilidad).

## ADR-004 — Backend en Go
**Estado:** aceptada.
**Decisión:** la API que sirve a la app móvil se hace en Go.
**Por qué:** binario único sin runtime → ideal VPS-first; rápido y concurrente.

## ADR-005 — Workers de analytics en Python
**Estado:** aceptada.
**Decisión:** el medallón de analytics + el update del rating corren en Python.
**Por qué:** el ecosistema de football analytics es Python-only [ref: `kloppy`, `socceraction`, `friends-of-tracking`]. Reimplementarlo en Go (sobre todo VAEP/xT, que son ML) sería reescribir librerías maduras sin referencia. **Abierto:** portar a Go partes estables (geometría, rating) más adelante.

## ADR-006 — Base de datos: MongoDB sola (NoSQL)
**Estado:** aceptada.
**Decisión:** una única base NoSQL (MongoDB) para identidad, ratings, partidos, reportes y leaderboard. Frames crudos en parquet (archivos), no en la base.
**Por qué:** preferencia firme por NoSQL. A escala amateur/tesis Mongo cubre leaderboard (sort+index), realtime (change streams) y jobs (colección). Redis = add-on futuro si la escala lo pide (YAGNI).
**Alternativas:** Postgres (mejor para lo relacional, descartado por preferencia NoSQL); Redis como única base (descartado: en-memoria, no es system-of-record); Mongo + Redis (descartado por ahora: dos bases para mantener).

## ADR-007 — Monolito modular (microservices-ready)
**Estado:** aceptada.
**Decisión:** un servicio Go + un pipeline Python, internamente modulares por dominio/etapa; cada módulo dueño de sus datos, hablando por interfaces. No microservicios todavía.
**Por qué:** monolito-primero evita complejidad prematura; las fronteras limpias permiten extraer servicios después.

## ADR-008 — Coordenadas en metros del venue real
**Estado:** aceptada.
**Decisión:** modelo `Frame` en metros con dimensiones reales del venue; helper a `[0,1]` on-demand.
**Por qué:** las canchas amateur varían (fútbol 5/7/11); las velocidades físicas (pitch control) necesitan metros reales.

## ADR-009 — Dirección de ataque fuera del contrato
**Estado:** aceptada.
**Decisión:** no pedirle al contrato de reconstrucción la dirección de juego. Quedan 2 gaps: pelota + jugadores no-identificados.
**Por qué:** no es confiable determinarla del posicionamiento amateur; las métricas espaciales robustas son direction-agnostic. Las métricas que la necesitan (PPDA, line-breaking, field tilt) se parkean.
