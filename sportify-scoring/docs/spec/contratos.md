# Especificación — Contratos de datos

**Status:** Decisiones tomadas
**Version:** 0.5
**Last updated:** 2026-06-09
**Stage:** Thesis scope

Define el contrato de **entrada** que `sportify-scoring` consume (de reconstrucción: `reconstruction.json` + los 2 gaps que se le piden; del árbitro: datos que la visión no ve) y el contrato de **salida** (`scoring.json`) hacia matchmaking y la app. La **dirección de ataque NO** se pide al contrato (ver §2 y [ADR-009](../decisions/log.md)).

> **Cross-refs:** [overview.md](overview.md) (arquitectura) · [datos-medallon.md](datos-medallon.md) (capas de datos) · [spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5 (outputs) · [decisions/log.md](../decisions/log.md) (ADR) · [research/references.md](../research/references.md) (fuentes).

---

## 1. Propósito y alcance

`sportify-scoring` recibe la reconstrucción per-frame del partido y produce un artefacto de scoring (dominancia + contribución por jugador) que alimenta el rating y el reporte de la app. Este doc fija **solo los contratos de datos en las fronteras**: lo que entra de reconstrucción (upstream, sistema de Valentín) y del árbitro (app de arbitraje), y lo que sale hacia matchmaking/app (downstream).

| Frontera | Artefacto | Dirección |
|----------|-----------|-----------|
| Upstream — reconstrucción | `reconstruction.json` + `job.meta.json` | entrada (se consume) |
| Upstream — app de arbitraje | datos del árbitro | entrada (se consume) |
| Downstream | `scoring.json` | salida (se produce) |

**Condición de éxito:** la calidad del scoring depende de que estos contratos estén completos; el sistema cumple cuando puede derivar dominancia y contribución sin pedirle a upstream más de lo acordado en §3.1.

---

## 2. Contexto y definiciones

| Término | Significado |
|---------|-------------|
| **Reconstrucción** | Sistema upstream que convierte el video en posiciones e identidades per-frame [ref: `soccernet-gsr`]. |
| **`reconstruction.json`** | Artefacto primario de la reconstrucción: serie temporal per-frame ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.1). |
| **`job.meta.json`** | Metadata del job de reconstrucción; ahí viven `venue_id` y dimensiones del venue ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.2). |
| **Datos del árbitro** | Lo que la visión no captura (cartones, score, tiempo), provisto por la app de arbitraje; entra a bronze junto a `reconstruction.json` ([datos-medallon.md](datos-medallon.md)). |
| **Gap** | Dato que el contrato actual de upstream no entrega y que scoring necesita; se le **pide** a upstream (§3.1). |
| **Frame** | Una muestra del estado del juego: `timestamp` + pelota + `players[]`, en metros del venue [ref: `kloppy`]. |
| **Jugador identificado** | Entry con `user_id` resuelto contra el roster. |
| **Jugador no-identificado** | Detección con posición pero sin `user_id` resuelto (gap 2). |
| **`user_id`** | Identidad de plataforma (registrado o invitado); la afiliación de equipo está implícita por el match del roster ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §4.3, FR-R2). |
| **Dominancia** | Score que mide cuánto mereció ganar un equipo, derivado de analytics (no de goles). |
| **Contribución** | Reparto de la dominancia/resultado a cada jugador, vía tracking [ref: `openskill`]. |
| **Dirección de ataque** | A qué arco ataca cada equipo. **No** entra al contrato [ADR-009]. |
| **Coordenadas de campo** | Metros en el plano de la cancha, según dimensiones del venue [ADR-008]. |

---

## 3. Requisitos funcionales

### 3.1 Contrato de entrada — `reconstruction.json` + gaps

`reconstruction.json` es una serie temporal per-frame ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.1). Por muestra entrega `frame_index`, `timestamp_ms` y `players[]` con `user_id`, `x`, `y`, `z`, `confidence` (metros sobre la cancha).

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `frame_index` | integer | sí | Índice de la muestra; agnóstico al `frame_stride`. |
| `timestamp_ms` | integer | sí | Instante de la muestra en ms. |
| `players[].user_id` | string | cuando identificado | Identidad de roster; ausente/provisional si no se resolvió (gap 2). |
| `players[].x`, `players[].y` | number | sí | Plano de campo, metros, origen por convención del venue. |
| `players[].z` | number | opcional | Default 0 para POC de plano de suelo. |
| `players[].confidence` | number | recomendado | Confianza de identidad o detección. |

- **FR-I1:** El sistema **deberá** consumir `reconstruction.json` tal cual lo emite upstream, sin pedir cambios de forma sobre los campos ya especificados en [spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.1.
- **FR-I2:** El sistema **deberá** leer `venue_id` y las dimensiones del venue desde `job.meta.json`, **no** desde cada frame ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.2; FR-O3 upstream).
- **FR-I3:** El sistema **no deberá** requerir la dirección de ataque en el contrato; las métricas base son direction-agnostic y las que la necesitan se parkean [ADR-009].

**Gaps que se le piden a upstream:**

| Gap | ID | Por qué |
|-----|-----|---------|
| **Posición de la pelota** por frame | FR-I4 | Sin pelota no hay SPADL, ni valor on-ball (xT/VAEP), ni término de transición de OBSO [ref: `socceraction`, `obso`]. |
| **Jugadores no-identificados** con posición | FR-I5 | Las métricas de equipo (centroide, hull, pitch control) necesitan los jugadores de campo aunque no estén identificados individualmente [ref: `compactness`, `pitch-control`]. |

- **FR-I4:** Upstream **deberá** agregar, por frame, la posición de la pelota como `Point3D` (`x`, `y`, `z` en metros del venue) cuando esté disponible.
- **FR-I5:** Upstream **deberá** emitir las detecciones de jugadores **no** resueltas a `user_id` con su posición de campo, distinguibles de las identificadas. El esquema de marca (`user_id: null` vs flag) es 🟡 Abierto: ver §7 #1, coordinado con [spec upstream §9 #3](../../../sportify-game-reconstruction/docs/spec/overview.md).

### 3.2 Contrato de entrada — datos del árbitro

Provenientes de la app de arbitraje; capturan lo que la visión no ve (cartones, score, tiempo). Entran a bronze junto a `reconstruction.json` y se sincronizan con el tracking por tiempo compartido ([datos-medallon.md](datos-medallon.md)).

- **FR-A1:** Los datos del árbitro **deberán** traer una base temporal (`timestamp_ms` o reloj de partido) sincronizable con `reconstruction.json` sobre la misma muestra.
- **FR-A2:** El sistema **deberá** ingerir estos datos a bronze sin fusionarlos con el tracking; la unión por tiempo ocurre en silver/gold.
- **FR-A3:** El esquema exacto (campos de cartones, score, períodos) **no** está congelado en esta versión — 🟡 Abierto: §7 #6.

### 3.3 Contrato de salida — `scoring.json`

Artefacto que produce la rama de analytics; insumo del rating y del reporte de la app. Es la capa servible (gold) del medallón [ref: ADR-003].

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `match_id` | string | sí | Partido al que pertenece el scoring. |
| `dominance.team_a`, `dominance.team_b` | number | sí | Score de dominancia por equipo (cuánto mereció ganar). |
| `players[].user_id` | string | sí | Identidad a la que se reparte la contribución. |
| `players[].team` | string | sí | `team_a` \| `team_b`. |
| `players[].contribution` | number | sí | Aporte del jugador a la dominancia de su equipo [ref: `openskill`]. |
| `metrics` | object | recomendado | Métricas agregadas por partido que respaldan la dominancia (Δpitch-control, ΔEPV, etc. [ref: `pitch-control`, `epv`]); composición y pesos exactos 🟡 Abierto: §7 #2, §7 #4. |

- **FR-O1:** El sistema **deberá** emitir, como mínimo, un score de dominancia del partido por equipo y una contribución por jugador identificado.
- **FR-O2:** La dominancia **deberá** derivarse de analytics y **no** de la diferencia de goles; es la señal que alimenta el margen del rating ("el puente") [ADR-002, ref: `openskill`, `epv`].
- **FR-O3:** La salida **deberá** referenciar identidades por `user_id` (registrado o invitado), consistente con el contrato de entrada y con la identidad de plataforma.
- **FR-O4:** El esquema completo de `scoring.json` (campos de `metrics`, normalización del score, escala) **no** está congelado en esta versión — 🟡 Abierto: §7 #2.

---

## 4. Requisitos no-funcionales

| ID | Requirement |
|----|-------------|
| NFR-1 | **VPS-only:** lectura de `reconstruction.json`/`job.meta.json` y escritura de `scoring.json` sobre filesystem local o VPS-attached, sin cloud egress (alineado con upstream NFR-P1). |
| NFR-2 | **Una fuente de verdad:** dimensiones del venue y homografía **no** se duplican en `scoring.json`; viven en `job.meta.json` upstream (FR-I2). |
| NFR-3 | **Trazabilidad:** cada método aplicado para producir `scoring.json` cita su entrada de [references.md](../research/references.md) (`[ref: ...]`) en código/issue. |
| NFR-4 | **Idempotencia:** la generación de `scoring.json` para un `match_id` **deberá** ser reproducible (overwrite o versionado por `match_id`). |
| NFR-5 | **Agnóstico al stride:** el consumo del contrato de entrada **no deberá** asumir un `frame_stride` ni un fps fijo (FR-O1 upstream). |
| NFR-6 | **Robustez al ruido:** el contrato de entrada se trata como bronze (crudo, con huecos/IDs parciales); la limpieza es etapa propia (silver) **antes** de cualquier métrica, no un requisito sobre upstream [ADR-003]. |

---

## 5. Interfaces / contratos

### 5.1 Entrada — `reconstruction.json` (ilustrativo)

Tabla de campos en §3.1. Ejemplo de una muestra con los 2 gaps incorporados (`ball` y un jugador no-identificado):

```json
{
  "frame_index": 1200,
  "timestamp_ms": 40000,
  "ball": { "x": 52.5, "y": 34.0, "z": 0.3 },
  "players": [
    { "user_id": "usr_abc123", "x": 34.2, "y": 12.8, "z": 0.0, "confidence": 0.91 },
    { "user_id": null, "x": 61.7, "y": 40.1, "z": 0.0, "confidence": 0.74 }
  ]
}
```

> `ball` (FR-I4) y la entry con `user_id: null` (FR-I5) son los 2 gaps. La marca exacta del no-identificado es 🟡 Abierto: §7 #1. La dirección de ataque **no** aparece (FR-I3, [ADR-009]).

### 5.2 Entrada — `job.meta.json` (ilustrativo)

De este artefacto se leen `venue_id` y dimensiones; tabla completa en [spec upstream §5.2](../../../sportify-game-reconstruction/docs/spec/overview.md).

```json
{
  "job_id": "job_20260524_001",
  "input": { "venue_id": "venue_001" },
  "output": { "reconstruction": { "path": "/data/artifacts/jobs/job_20260524_001/reconstruction.json" } }
}
```

> Las **dimensiones del venue** (`field_length_m`, `field_width_m`, …) se obtienen vía `venue_id` contra el venue ([spec upstream §4.2](../../../sportify-game-reconstruction/docs/spec/overview.md)); se usan para normalizar a metros [ADR-008].

### 5.3 Entrada — datos del árbitro (ilustrativo)

Tabla normativa pendiente (§3.2, esquema abierto §7 #6). Forma mínima esperable, sincronizable por tiempo:

```json
{
  "match_id": "match_789",
  "score": { "team_a": 2, "team_b": 1 },
  "events": [
    { "timestamp_ms": 612000, "type": "yellow_card", "user_id": "usr_def456" }
  ]
}
```

> Se ingiere a bronze sin fusionar con el tracking (FR-A2); la unión por `timestamp_ms` ocurre en silver/gold.

### 5.4 Salida — `scoring.json` (ilustrativo)

Tabla de campos en §3.3. Esquema mínimo; campos más allá de este mínimo son 🟡 Abierto: §7 #2.

```json
{
  "match_id": "match_789",
  "dominance": { "team_a": 0.63, "team_b": 0.37 },
  "players": [
    { "user_id": "usr_abc123", "team": "team_a", "contribution": 0.21 },
    { "user_id": "usr_def456", "team": "team_b", "contribution": 0.14 }
  ],
  "metrics": {}
}
```

> Enlaces de frontera: upstream [spec §5](../../../sportify-game-reconstruction/docs/spec/overview.md); downstream consumen `scoring.json` el módulo `ratings` (margen del rating) y `analytics_reports` (reporte de la app) ([overview.md](overview.md)).

---

## 6. Criterios de aceptación

1. El sistema lee un `reconstruction.json` real y obtiene `frame_index`, `timestamp_ms` y `players[]` con posición en metros sin pedir cambios de forma a upstream (FR-I1).
2. `venue_id` y dimensiones del venue se resuelven desde `job.meta.json` / venue, no desde frames (FR-I2, NFR-2).
3. El sistema procesa el contrato sin consumir ni requerir dirección de ataque (FR-I3).
4. Cuando upstream entrega `ball` por frame, el sistema lo ingiere como `Point3D` en metros (FR-I4).
5. Las detecciones no-identificadas con posición se ingieren y se distinguen de las identificadas (FR-I5).
6. El `scoring.json` emitido contiene `match_id`, `dominance` por equipo y `contribution` por jugador identificado (FR-O1, FR-O3).
7. La dominancia de `scoring.json` se deriva de analytics y no de la diferencia de goles (FR-O2).
8. Regenerar `scoring.json` para un mismo `match_id` produce un artefacto reproducible (NFR-4).
9. Los datos del árbitro se ingieren a bronze y se sincronizan con `reconstruction.json` por `timestamp_ms` sobre la misma muestra, sin fusión previa (FR-A1, FR-A2).

---

## 7. Open design items

| # | Topic | Notes |
|---|-------|-------|
| 1 | Marca de no-identificado | `user_id: null` vs flag de provisionalidad; coordinar con [spec upstream §9 #3](../../../sportify-game-reconstruction/docs/spec/overview.md). Referenciado por FR-I5. |
| 2 | Esquema completo de `scoring.json` | Campos de `metrics`, normalización/escala del score de dominancia, formato del reporte. Referenciado por FR-O4. |
| 3 | Disponibilidad real de la pelota | FR-I4 dice "cuando esté disponible"; upstream no compromete pipeline de pelota como POC ([spec upstream §12](../../../sportify-game-reconstruction/docs/spec/overview.md)). Definir fallback de scoring sin pelota. |
| 4 | Pesos de dominancia | Composición y pesos `w1..w4` del score compuesto a calibrar empíricamente (research §5). |
| 5 | Reparto a invitados | Cómo se persiste la contribución de un `user_id` invitado (rating en la sombra) en `scoring.json`. |
| 6 | Esquema de datos del árbitro | Campos exactos de cartones, score y períodos, y su base temporal. Referenciado por FR-A3. |

---

## 8. Trazabilidad y scope por etapa

### 8.1 Scope por product stage

| Stage | ¿En este spec? |
|-------|----------------|
| **POC** — reconstrucción | No — es upstream; este spec solo consume su contrato ([ADR-001]). |
| **Thesis scope** — scoring, matchmaking | Sí — define las fronteras de datos: 2 entradas (reconstrucción, árbitro) + 1 salida (§3, §5). |
| **Deferred** — event detection | No — se deriva internamente (SPADL) si hace falta; no entra al contrato. |

**Out of scope (este spec):**

- El pipeline interno de métricas (pitch control, OBSO, EPV, PPDA) — vive en [investigations/](../investigations/) y en el medallón ([datos-medallon.md](datos-medallon.md)).
- El motor de rating y el reparto a individuos — [investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md).
- La generación interna de la reconstrucción — [spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md).
- Dirección de ataque y las métricas que la requieren (PPDA, line-breaking, field tilt) — parkeadas [ADR-009].

### 8.2 Trazabilidad

| Requisito | → AC | → ADR / ref |
|-----------|------|-------------|
| FR-I1 | AC #1 | [ADR-001] |
| FR-I2 | AC #2 | spec upstream §5.2 / FR-O3 upstream |
| FR-I3 | AC #3 | [ADR-009] |
| FR-I4 | AC #4 | [ref: `socceraction`, `obso`] |
| FR-I5 | AC #5 | [ref: `compactness`, `pitch-control`]; §7 #1 |
| FR-A1 | AC #9 | [datos-medallon.md](datos-medallon.md) |
| FR-A2 | AC #9 | [ADR-003] |
| FR-A3 | — | §7 #6 (abierto) |
| FR-O1 | AC #6 | [ref: `openskill`] |
| FR-O2 | AC #7 | [ADR-002], [ref: `epv`] |
| FR-O3 | AC #6 | identidad de plataforma |
| FR-O4 | — | §7 #2 (abierto) |
| NFR-4 | AC #8 | — |
| NFR-2 | AC #2 | [ADR-008] |

---

## 9. Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.5 | 2026-06-09 | Agrega la 2ª entrada (datos del árbitro): FR-A1–A3, §5.3, AC #9, open item #6; Status → Decisiones tomadas; aterriza composición de dominancia [ref: `pitch-control`, `epv`]. |
| 0.4 | 2026-06-09 | Reescritura formal según rúbrica: encabezado, 9 secciones, FR-I/FR-O/NFR con IDs, AC trazables, open items, esquemas JSON de entrada/salida y trazabilidad a research/ADR. |
| 0.3 | 2026-06-09 | Esbozo inicial: gaps de entrada (pelota, no-identificados), salida `scoring.json` a definir, dirección de ataque fuera del contrato. |
