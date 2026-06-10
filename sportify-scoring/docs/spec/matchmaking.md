# Especificación — Matchmaking y rating

**Status:** Decisiones tomadas
**Version:** 0.1
**Last updated:** 2026-06-09
**Stage:** Thesis scope

Define la **Rama A** de `sportify-scoring`: el motor de rating (OpenSkill / Plackett-Luce), cómo el margen escala el swing, **el puente** que alimenta ese margen con dominancia derivada de analytics (no con diferencia de goles — contribución de la tesis), el reparto del resultado a jugadores por contribución (partial-play), el emparejamiento on-demand y el cold-start de jugadores nuevos/invitados. La parte **normativa** vive acá; el porqué de cada elección, en los ADR; el desarrollo factual de los métodos, en la investigación. **No** define el cómputo de la dominancia ni de la contribución (eso es Rama B / analytics): acá entran ya computados vía `scoring.json`.

> **Cross-refs:** [overview.md](overview.md) §3.3 (las dos ramas + el puente) · [contratos.md](contratos.md) §3.3 (`scoring.json`) · [datos-medallon.md](datos-medallon.md) (gold) · [../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md) (fundamento factual) · [../decisions/log.md](../decisions/log.md) (ADRs) · [../research/references.md](../research/references.md) (bibliografía).

---

## 1. Propósito y alcance

Esta rama convierte el **resultado de cada partido** en un **update de rating** por jugador, y usa esos ratings para armar equipos parejos on-demand. El rating mide skill individual; el matchmaking lo aprovecha para balancear.

La **condición que distingue a la tesis** es de dónde sale la señal de margen: en vez de diferencia de goles (ruidosa en amateur), el margen lo fija un **score de dominancia** derivado del tracking [ADR-002] [ref: `openskill`, `epv`]. Como Rama A, funciona sola con un margen simple desde el día 1 y mejora a margen-por-dominancia cuando analytics está disponible, sin reescribir el motor.

Tres sub-problemas encadenados ([../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md)):

| # | Sub-problema | Quién lo resuelve |
|---|--------------|-------------------|
| 1 | Señal de margen del partido | El **puente** (§3.2): dominancia de analytics; fallback simple sin analytics [ref: `openskill`] |
| 2 | Update del rating de equipo escalado por margen | El motor OpenSkill (§3.1) [ref: `openskill`] |
| 3 | Reparto del resultado a jugadores individuales | Partial-play ponderado por contribución (§3.3) [ref: `epv`] |

**Condición de éxito:** dado el resultado de un partido, el sistema produce un nuevo rating por jugador (registrado o invitado) de forma atómica y reproducible, y puede armar equipos parejos a pedido (FR-B1, FR-B2 de [overview.md](overview.md) §3.3).

---

## 2. Contexto y definiciones

| Término | Significado |
|---------|-------------|
| **Rating** | Estado de skill de un `user_id`. Vector multidimensional `(μ, σ)` del motor OpenSkill [ref: `openskill`]. |
| **`μ` (mu)** | Media estimada de la habilidad de un jugador. |
| **`σ` (sigma)** | Desvío estándar / incertidumbre sobre `μ`; alta en jugadores nuevos, baja con historial. |
| **Rating conservador** | Valor servible y ordenable del rating: `μ − 3σ` [ref: `openskill`]. Lo que ve el leaderboard; penaliza la incertidumbre. |
| **Motor (OpenSkill)** | Motor de rating Bayesiano basado en el modelo Plackett-Luce; nativo multi-equipo/multi-jugador, con `margin` y reparto [ref: `openskill`]. **Elegido como base** [ADR-002]. |
| **`margin`** | Magnitud del resultado que el motor usa para escalar el swing del update. **No** es la diferencia de goles (§3.2). |
| **Swing** | Cuánto se mueve el rating de un equipo tras un partido. |
| **`P(A gana)`** | Predicción de victoria entre lados: `1 / (1 + Σ exp(μ_B − μ_A))` [ref: `openskill`]. |
| **Dominancia** | Score por equipo que mide cuánto **mereció** ganar, derivado de analytics (Rama B). Entra como `margin` por el puente. Producida en `scoring.json` ([contratos.md](contratos.md) §3.3). |
| **Contribución** | Aporte de un jugador a la dominancia de su equipo, derivado del tracking (VAEP/EPV por jugador) [ref: `epv`, `socceraction`]. Producida en `scoring.json` ([contratos.md](contratos.md) §3.3). |
| **Partial-play** | Mecanismo de OpenSkill que pondera cuánto del resultado de equipo se reparte a cada jugador [ref: `openskill`]. Acá se pondera por contribución. |
| **El puente** | Que el `margin` del rating se alimente de **dominancia** y no de goles. Contribución original de la tesis [ADR-002]. |
| **Margen simple** | Señal de margen del día 1, sin analytics: diferencia de goles del árbitro u otra señal trivial. Reemplazable por dominancia sin tocar el motor. |
| **Cold-start** | Rating inicial de un jugador sin historial (nuevo o invitado): σ alta, μ por defecto. |
| **Registrado** | `user_id` con cuenta, perfil, rating y presencia en leaderboard ([overview.md](overview.md) §2). |
| **Invitado** | `user_id` con slot en el roster sin cuenta; rating "en la sombra" reclamable al registrarse ([overview.md](overview.md) §2). |
| **Emparejamiento (matchmaking)** | Armado on-demand de dos equipos parejos a partir de un pool de `user_id`, según rating. |
| **On-demand** | Disparado por pedido del usuario; se resuelve en Go, no como worker batch (FR-S5 de [overview.md](overview.md) §3.1). |
| **`scoring.json`** | Artefacto de salida de analytics: dominancia del partido + contribución por jugador. Esquema exacto 🟡 abierto ([contratos.md](contratos.md) §7 #2). |

---

## 3. Requisitos funcionales

### 3.1 Motor de rating (`R` — Rating engine)

| ID | Requisito |
|----|-----------|
| **FR-R1** | El sistema **deberá** representar el rating de cada `user_id` como un par `(μ, σ)` y persistirlo en su documento `user`, para update atómico por documento (FR-D5 de [overview.md](overview.md) §3.4) [ref: `openskill`]. |
| **FR-R2** | El sistema **deberá** usar OpenSkill (Plackett-Luce) como motor de update, nativo multi-equipo y multi-jugador [ADR-002] [ref: `openskill`]. |
| **FR-R3** | El valor **servible/ordenable** del rating (leaderboard, balanceo) **deberá** ser el conservador `μ − 3σ` [ref: `openskill`]. |
| **FR-R4** | El motor **deberá** aceptar un `margin` por partido que escale el swing del update (§3.2) [ref: `openskill`]. |
| **FR-R5** | El motor **deberá** poder predecir el resultado de un enfrentamiento vía `P(A gana) = 1 / (1 + Σ exp(μ_B − μ_A))` [ref: `openskill`]. |
| **FR-R6** | El update del rating **deberá** correr en el worker Python; el emparejamiento on-demand, en Go (FR-S5 de [overview.md](overview.md) §3.1) [ADR-005]. |
| **FR-R7** | Un partido sin update aplicado **no deberá** mover ningún rating; el update **deberá** ser idempotente por `match_id` (re-aplicar no acumula) [ADR-003]. |
| **FR-R8** | La elección concreta de implementación de OpenSkill (modelo PL específico, hiperparámetros β/τ, valores iniciales de μ/σ) **no** se fija en esta versión — 🟡 abierto: ver §7 #1. |

> Glicko-2 [ref: `glicko2`] queda como **referencia** para incertidumbre/inactividad amateur (§3.5), no como motor. Elo-MOV [ref: `elo-mov`] queda como referencia del mecanismo de margen (§3.2). Ninguno es normativo acá.

### 3.2 Señal de margen y puente (`B` — Bridge)

El `margin` que escala el swing **no** sale de la diferencia de goles: sale de la **dominancia** derivada de analytics. Un equipo que mereció ganar (dominó espacio/peligro) sube fuerte aunque gane 1-0; un 3-0 con suerte no infla tanto ([../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md) §"El puente").

| ID | Requisito |
|----|-----------|
| **FR-B1** | El sistema **deberá** funcionar con un `margin` **simple** (diferencia de goles del árbitro o señal binaria victoria/empate/derrota) desde el día 1, sin depender de analytics (FR-B2 de [overview.md](overview.md) §3.3). |
| **FR-B2** | Cuando analytics esté disponible, el sistema **deberá** alimentar el `margin` con la **dominancia** por equipo de `scoring.json`, **no** con la diferencia de goles [ADR-002] (FR-B3 de [overview.md](overview.md) §3.3) [ref: `openskill`, `epv`]. |
| **FR-B3** | El cambio de fuente de margen (simple → dominancia) **no deberá** requerir reescribir el motor ni el esquema del rating; solo cambia el valor de entrada `margin` (FR-R1–FR-R4). |
| **FR-B4** | El sistema **deberá** registrar, por update, **qué fuente de margen** se usó (simple vs dominancia) para trazabilidad de tesis (NFR-7 de [overview.md](overview.md) §4). |
| **FR-B5** | La normalización de la dominancia al `margin` que espera el motor (escala, mapeo, clipping) y la forma exacta del margen simple de fallback **no** se fijan — 🟡 abierto: ver §7 #2. |

> La composición de la dominancia (`w1·ΔxG + w2·Δpitch_control + w3·ΔEPV + …`) y la calibración de pesos **no** son parte de este spec: viven en analytics ([contratos.md](contratos.md) §7 #4) y acá la dominancia entra ya computada. Elo-MOV incluye una corrección de autocorrelación (`corr`) que evita que el margen infle el sistema [ref: `elo-mov`]; si OpenSkill necesitara un equivalente, es 🟡 abierto: ver §7 #3.

### 3.3 Reparto a jugadores (`P` — Player split)

OpenSkill reparte el resultado de equipo a individuos; se afina con partial-play ponderado por la **contribución** de cada jugador ([../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md) §"Reparto a jugadores").

| ID | Requisito |
|----|-----------|
| **FR-P1** | El resultado de equipo **deberá** repartirse a cada `user_id` vía partial-play de OpenSkill [ref: `openskill`]. |
| **FR-P2** | El peso de partial-play de cada jugador **debería** derivar de su `contribution` en `scoring.json`, no ser uniforme, cuando analytics está disponible [ref: `epv`, `socceraction`]. |
| **FR-P3** | El reparto ponderado **deberá** cumplir: un jugador destacado en un equipo que pierde pierde menos rating; un pasajero en un equipo que gana gana menos. |
| **FR-P4** | Sin `contribution` (sin analytics, o jugador sin contribución resuelta), el reparto **deberá** degradar a peso **uniforme** entre los jugadores del equipo. |
| **FR-P5** | Solo los `user_id` presentes en el roster del partido **deberán** recibir update; un jugador no rosterizado **no deberá** moverse. |
| **FR-P6** | El mapeo de `contribution` (escala/normalización) al peso de partial-play **no** se fija — 🟡 abierto: ver §7 #4. |

### 3.4 Emparejamiento on-demand (`M` — Matchmaking)

| ID | Requisito |
|----|-----------|
| **FR-M1** | El sistema **deberá** repartir un pool de `user_id` en dos equipos **balanceados** por rating conservador (`μ − 3σ`, FR-R3), minimizando la diferencia esperada de skill entre lados. |
| **FR-M2** | El emparejamiento **deberá** usar la predicción `P(A gana)` (FR-R5) como criterio de paridad [ref: `openskill`]. |
| **FR-M3** | El emparejamiento **deberá** resolverse **on-demand en Go** (FR-S5 de [overview.md](overview.md) §3.1); **no** corre como worker batch ni toca el worker Python. |
| **FR-M4** | El emparejamiento **deberá** poder operar con un pool mixto de registrados e invitados, usando el rating en la sombra del invitado (§3.5). |
| **FR-M5** | El objetivo y algoritmo de partición (umbral de `P(A gana)`, tamaño de equipo para fútbol 5/7/11, balance de roles/posiciones) **no** se fijan — 🟡 abierto: ver §7 #5. |

### 3.5 Cold-start, invitados e inactividad (`C` — Cold-start)

| ID | Requisito |
|----|-----------|
| **FR-C1** | Un jugador **nuevo** (registrado sin historial) **deberá** inicializarse con μ por defecto y σ **alta** (máxima incertidumbre), de modo que sus primeros partidos muevan su rating con más fuerza [ref: `openskill`, `glicko2`]. |
| **FR-C2** | Un **invitado** **deberá** acumular rating "en la sombra" sobre su `user_id` desde su primer partido, con el mismo motor y cold-start que un registrado (FR-I3 de [overview.md](overview.md) §3.5). |
| **FR-C3** | Al **reclamar** un invitado (registro), su rating en la sombra e historial **deberán** activarse y transferirse al usuario registrado sin recomputar (FR-I4 de [overview.md](overview.md) §3.5); el flujo de merge es 🟡 abierto ([overview.md](overview.md) §7 #7, este §7 #6). |
| **FR-C4** | El sistema **debería** elevar la σ de un jugador por **inactividad** prolongada, para reflejar mayor incertidumbre tras tiempo sin jugar [ref: `glicko2`]. (Mecanismo y umbral — 🟡 abierto: ver §7 #7.) |
| **FR-C5** | Los valores concretos de cold-start (μ/σ iniciales) y la curva de inactividad **no** se fijan en esta versión — 🟡 abierto: ver §7 #1, §7 #7. |

---

## 4. Requisitos no-funcionales

| ID | Requirement |
|----|-------------|
| **NFR-1** | **VPS-only:** todo el I/O del rating y del matchmaking **deberá** ocurrir en storage local o adjunto al VPS, sin egress a cloud (alineado con [overview.md](overview.md) §4 NFR-1). |
| **NFR-2** | **Atomicidad:** el update de rating de cada `user_id` **deberá** ser atómico a nivel de su documento `user` (FR-D5, NFR-6 de [overview.md](overview.md) §4). |
| **NFR-3** | **Idempotencia:** re-aplicar el update de un `match_id` **no deberá** acumular ni divergir (FR-R7) [ADR-003]. |
| **NFR-4** | **Reproducibilidad:** dado el mismo `scoring.json`, el mismo estado previo de ratings y los mismos hiperparámetros, el update **deberá** producir el mismo resultado (determinista). |
| **NFR-5** | **Desacople:** el motor de rating **no deberá** depender de que analytics exista; el margen y la contribución entran por contrato (`scoring.json`) y degradan a simple/uniforme si faltan (FR-B1, FR-P4) [ADR-002]. |
| **NFR-6** | **Una fuente de verdad:** el rating vigente se define en `users` (FR-R1); el resto lo referencia, no lo duplica (NFR-4 de [overview.md](overview.md) §4). |
| **NFR-7** | **Observabilidad:** el worker de rating **debería** loguear partido, `margin` usado (simple vs dominancia, FR-B4) y delta de rating por jugador, para trazabilidad de tesis (NFR-7 de [overview.md](overview.md) §4). |
| **NFR-8** | **Latencia on-demand:** el emparejamiento en Go **debería** responder en tiempo interactivo (sin batch) para un pool de tamaño amateur; umbral exacto 🟡 abierto: ver §7 #5. |
| **NFR-9** | **Honestidad de validación:** la evaluación del sistema de rating **debería** usar métricas de forecasting (calibración/log-loss del `P(A gana)`) [ref: `forecasting`]; sin partidos amateur reales todavía, el protocolo es 🟡 abierto: ver §7 #8. |

---

## 5. Interfaces / contratos

Los esquemas de campo se definen en [contratos.md](contratos.md); acá se fija la **topología** de entradas/salidas de la rama.

### 5.1 Entrada — `scoring.json` (analytics → rating)

El rating consume `scoring.json`: `dominance` por equipo alimenta el `margin` (puente, §3.2); `players[].contribution` pondera el partial-play (§3.3). Tabla de campos completa y esquema en [contratos.md](contratos.md) §3.3 / §5.4.

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

| Campo consumido | Tipo | Requerido | Uso en rating | Requisito |
|-----------------|------|-----------|---------------|-----------|
| `dominance.team_a` / `.team_b` | number | sí | Fuente del `margin` (puente) | FR-B2 |
| `players[].user_id` | string | sí | A quién se le aplica el update | FR-P1, FR-P5 |
| `players[].team` | string | sí | Lado del jugador en el partido | FR-P1 |
| `players[].contribution` | number | no | Peso de partial-play | FR-P2 |

> Cuando `scoring.json` no existe (sin analytics), la fuente de margen es el **margen simple** (FR-B1) y el reparto es **uniforme** (FR-P4). El esquema completo de `scoring.json` está 🟡 abierto ([contratos.md](contratos.md) §7 #2); cómo se persiste la contribución de un invitado, 🟡 abierto ([contratos.md](contratos.md) §7 #5).

### 5.2 Entrada (fallback) — margen simple

Cuando no hay `scoring.json`, el update toma una señal de margen trivial (p. ej. score del árbitro, [contratos.md](contratos.md) §3.2). Forma exacta 🟡 abierta: ver §7 #2.

```yaml
# illustrative — fallback del día 1, no es esquema normativo
match_id: match_789
result: { team_a: 2, team_b: 1 }   # diferencia de goles como margen simple
```

### 5.3 Estado — rating en el documento `user` (gold)

El rating vive embebido en `users` (FR-R1); es la capa gold servible. Tabla de colecciones en [overview.md](overview.md) §3.4 y [datos-medallon.md](datos-medallon.md).

```json
// illustrative — schema exacto de colecciones 🟡 abierto (overview §7 #6)
{
  "user_id": "usr_abc123",
  "registered": true,
  "rating": { "mu": 25.3, "sigma": 4.1, "conservative": 13.0 },
  "matches_played": 12,
  "last_played_ms": 1717900000000
}
```

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `rating.mu` | number | sí | Media de habilidad (FR-R1). |
| `rating.sigma` | number | sí | Incertidumbre (FR-R1, FR-C1). |
| `rating.conservative` | number | sí | `μ − 3σ`, valor servible/ordenable (FR-R3). |
| `registered` | bool | sí | `false` = invitado, rating en la sombra (FR-C2). |
| `matches_played` | integer | recomendado | Soporta cold-start/inactividad (FR-C1, FR-C4). |
| `last_played_ms` | integer | recomendado | Base para inflar σ por inactividad (FR-C4). |

> El esquema exacto de `users` (índices, embebido vs ref) es 🟡 abierto ([overview.md](overview.md) §7 #6).

### 5.4 Salida — emparejamiento (Go → app)

Respuesta on-demand del módulo `matchmaking` a la app. Forma mínima ilustrativa; objetivo de balance y algoritmo 🟡 abiertos: ver §7 #5.

```json
{
  "pool": ["usr_abc123", "usr_def456", "usr_ghi789", "usr_jkl012"],
  "teams": {
    "team_a": ["usr_abc123", "usr_jkl012"],
    "team_b": ["usr_def456", "usr_ghi789"]
  },
  "predicted_win_prob": { "team_a": 0.52, "team_b": 0.48 }
}
```

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `teams.team_a` / `.team_b` | list | sí | Partición balanceada del pool (FR-M1). |
| `predicted_win_prob` | object | recomendado | `P(A gana)` por lado vía Plackett-Luce (FR-M2, FR-R5) [ref: `openskill`]. |

| Gap | Por qué |
|-----|---------|
| Esquema de `scoring.json` (dominancia + contribución) | Sin él, el puente (FR-B2) y el reparto por contribución (FR-P2) corren en modo degradado (FR-B1, FR-P4). Se le pide a analytics — [contratos.md](contratos.md) §5.4, §7 #2. |

> Frontera: upstream de este artefacto son `scoring.json` ([contratos.md](contratos.md) §5.4) y los ratings en `users`; downstream lo consume la app vía el backend Go ([overview.md](overview.md) §3.1).

---

## 6. Criterios de aceptación

1. Cada `user_id` tiene un rating `(μ, σ)` persistido en su documento `user`, y el leaderboard ordena por `μ − 3σ` (FR-R1, FR-R3).
2. Un partido procesado aplica un update OpenSkill que mueve los ratings de los jugadores rosterizados y de nadie más (FR-R2, FR-P5).
3. Re-aplicar el update del mismo `match_id` no cambia los ratings respecto de la primera aplicación (FR-R7, NFR-3).
4. Dado un resultado con margen simple, el sistema produce un rating `(μ, σ)` nuevo por jugador sin que analytics esté implementado, y registra que usó margen simple (FR-B1, FR-B3, FR-B4, NFR-5).
5. Con analytics disponible, el `margin` del update proviene de `dominance` de `scoring.json` y **no** de la diferencia de goles, sin cambiar el motor (FR-B2, FR-B3).
6. Dos partidos con la misma diferencia de goles pero distinta dominancia producen swings distintos cuando se usa el puente (FR-B2).
7. Con `contribution` disponible, el reparto no es uniforme: un jugador destacado en el equipo perdedor pierde menos rating que un jugador promedio del mismo equipo (FR-P2, FR-P3).
8. Sin `contribution`, el reparto del equipo es uniforme (FR-P4).
9. El emparejamiento devuelve, on-demand en Go, una partición del pool con su `P(A gana)` por lado cercano a 0.5 para un pool parejo, balanceada por rating conservador (FR-M1, FR-M2, FR-M3).
10. Un jugador nuevo arranca con σ alta y su primer partido mueve su rating más que el de un jugador consolidado (FR-C1).
11. Un invitado acumula rating en la sombra desde su primer partido y, al registrarse, conserva ese rating e historial (FR-C2, FR-C3).
12. Dado el mismo `scoring.json`, el mismo estado previo y los mismos hiperparámetros, el update produce el mismo resultado (NFR-4).

---

## 7. Open design items

| # | Topic | Notes |
|---|-------|-------|
| 1 | Hiperparámetros y valores iniciales | Modelo PL concreto de OpenSkill, β/τ, μ/σ por defecto y curva de cold-start. Referenciado por FR-R8, FR-C5 [ref: `openskill`]. |
| 2 | Normalización dominancia → `margin` | Escala/mapeo/clipping de la dominancia al `margin` del motor; y forma exacta del margen simple de fallback. Referenciado por FR-B5, §5.2. |
| 3 | Corrección de autocorrelación del margen | Si OpenSkill necesita un equivalente al `corr` de Elo-MOV para que el margen no infle el sistema (FR-B2) [ref: `elo-mov`]. |
| 4 | Mapeo contribución → partial-play | Cómo `contribution` se normaliza a pesos de partial-play (¿suma 1 por equipo?, ¿piso/techo?). Referenciado por FR-P6 [ref: `epv`]. |
| 5 | Objetivo y algoritmo de emparejamiento | Función de balance (min Δrating vs `P(A gana)`≈0.5), tamaño de equipo (fútbol 5/7/11), balance de roles, algoritmo de partición y umbral de latencia. Referenciado por FR-M5, NFR-8. |
| 6 | Merge invitado → registrado | Flujo de reclamo y merge de identidad + rating en la sombra (FR-C3); coordinar con [overview.md](overview.md) §7 #7 y [contratos.md](contratos.md) §7 #5. |
| 7 | Inflado de σ por inactividad | Mecanismo y umbral temporal; Glicko-2 RD/volatilidad como referencia, no como motor (FR-C4, FR-C5) [ref: `glicko2`]. |
| 8 | Validación del sistema de rating | Métricas de forecasting/calibración del `P(A gana)` y dataset de evaluación sin partidos amateur reales (NFR-9) [ref: `forecasting`]. |

---

## 8. Trazabilidad y scope por etapa

### 8.1 Scope por product stage

| Stage | ¿En este spec? |
|-------|----------------|
| **POC** — reconstrucción | **No** — upstream; este spec consume `scoring.json`, no la reconstrucción [ADR-001]. |
| **Thesis scope** — matchmaking + rating | **Sí** — esta es la Rama A (rating + puente + reparto + emparejamiento + cold-start) (§3). |
| **Thesis scope** — analytics / dominancia | **Parcial** — se referencia como entrada (`scoring.json`); su método vive en analytics [contratos.md](contratos.md). |
| **Deferred** — event detection | **No** — el rating no depende de eventos; opera sobre dominancia/contribución de `scoring.json`. |
| **Production** — Redis, multi-VPS, leaderboard a escala, anti-cheat | **No** — el diseño no lo bloquea pero no lo implementa. |

**Out of scope (este spec):**

- El **cómputo** de la dominancia y de la contribución (pesos `w1..w4`, VAEP/EPV) — Rama B / analytics, [contratos.md](contratos.md) §7 #4 y [../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md).
- El esquema completo de `scoring.json` y de `users` — [contratos.md](contratos.md) §7 #2, [overview.md](overview.md) §7 #6.
- La arquitectura de software (Go/Python/store) — [overview.md](overview.md).
- El flujo de merge de identidad invitado → registrado — [overview.md](overview.md) §7 #7.
- La app móvil (UI) y el referee app — productos aparte.

### 8.2 Trazabilidad

| Requisito | → AC | → ADR / ref |
|-----------|------|-------------|
| FR-R1, FR-R2 | AC #1, #2 | [ADR-002] [ref: `openskill`] |
| FR-R3 | AC #1, #9 | [ref: `openskill`] |
| FR-R4 | AC #5 | [ref: `openskill`] |
| FR-R5 | AC #9 | [ref: `openskill`] |
| FR-R6 | AC #2, #9 | [ADR-005] |
| FR-R7 | AC #3 | [ADR-003] |
| FR-R8 | — | §7 #1 (abierto) |
| FR-B1 | AC #4 | [overview.md](overview.md) FR-B2 |
| FR-B2 | AC #5, #6 | [ADR-002] [ref: `openskill`, `epv`] |
| FR-B3 | AC #4, #5 | [ADR-002] |
| FR-B4 | AC #4 | [overview.md](overview.md) NFR-7 |
| FR-B5 | — | §7 #2 (abierto) |
| FR-P1, FR-P2, FR-P3 | AC #7 | [ref: `openskill`, `epv`] |
| FR-P4 | AC #8 | desacople (NFR-5) |
| FR-P5 | AC #2 | — |
| FR-P6 | — | §7 #4 (abierto) |
| FR-M1, FR-M2, FR-M3 | AC #9 | [overview.md](overview.md) FR-S5 [ref: `openskill`] |
| FR-M4 | AC #11 | identidad de plataforma |
| FR-M5 | — | §7 #5 (abierto) |
| FR-C1 | AC #10 | [ref: `openskill`, `glicko2`] |
| FR-C2, FR-C3 | AC #11 | [overview.md](overview.md) FR-I3, FR-I4 |
| FR-C4 | — | §7 #7 (abierto) [ref: `glicko2`] |
| FR-C5 | — | §7 #1, #7 (abierto) |
| NFR-2 | AC #2 | [overview.md](overview.md) NFR-6 |
| NFR-3 | AC #3 | [ADR-003] |
| NFR-4 | AC #12 | — |
| NFR-5 | AC #4, #8 | [ADR-002] |

> Cada requisito traza a ≥1 criterio de aceptación o a un open item de §7. NFR-1, NFR-6, NFR-7, NFR-8, NFR-9 son restricciones estructurales o decisiones diferidas verificadas por inspección de diseño/infra, no por corrida única.

---

## 9. Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-06-09 | Spec inicial de la Rama A según rúbrica de specs: motor OpenSkill (§3.1), puente de dominancia (§3.2), reparto por contribución/partial-play (§3.3), emparejamiento on-demand (§3.4), cold-start/invitados/inactividad (§3.5); contratos de entrada (`scoring.json` + fallback simple) y salida (emparejamiento), criterios de aceptación, open items y trazabilidad a ADRs y research. |
