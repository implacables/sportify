# Especificación — Analítica (gold)

**Status:** Draft
**Version:** 0.1
**Last updated:** 2026-06-09
**Stage:** Thesis scope

Define **qué computa** la capa gold del medallón sobre el `Frame` silver: métricas espaciales direction-agnostic, superficies de valor (pitch control, OBSO, valor de posesión) y el **score de dominancia** que alimenta el puente del rating. Fija el **orden de dependencia**, la **robustez al tracking amateur** y la **salida servible**. **No** redefine el modelo `Frame`, la limpieza de silver ni la persistencia ([datos-medallon.md](datos-medallon.md)); **no** congela el esquema de `scoring.json` ([contratos.md](contratos.md)); **no** cubre rating ni matchmaking ([overview.md](overview.md)); **no** duplica las fórmulas de cada método (viven en las investigaciones).

> **Cross-refs:** [datos-medallon.md](datos-medallon.md) §3.4 (gold como capa, modelo `Frame`, silver) · [contratos.md](contratos.md) §3.3 (`scoring.json`) · [overview.md](overview.md) §3.3–§3.4 (ramas, puente, persistencia) · [../investigations/datos-y-metricas.md](../investigations/datos-y-metricas.md) (métricas) · [../investigations/superficies-de-valor.md](../investigations/superficies-de-valor.md) (superficies) · [../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md) (dominancia / "el puente") · [../research/references.md](../research/references.md) (fuentes) · [../decisions/log.md](../decisions/log.md) (ADRs).

---

## 1. Propósito y alcance

Transformar la serie de `Frame` **silver** (limpia, en metros del venue, con velocidades y equipo derivados) en las **features servibles** de gold: un documento de analytics por partido con métricas espaciales, superficies de valor y un **score de dominancia** por equipo con **contribución por jugador**. La capa gold es la Rama B del sistema [ADR-002]; su salida es el insumo del rating (vía dominancia, "el puente") y del reporte de la app.

El método se ordena por **confiabilidad sobre tracking amateur**: primero lo que **no** depende de la dirección de ataque ni de la pelota, después lo que sí. La capa se diseña al patrón **EPV: modular, descompuesto, interpretable** [ref: `epv`].

| Tier | Qué incluye | Depende de | Confiabilidad |
|------|-------------|------------|---------------|
| **Estructura** | centroide, stretch, surface area, team spread, length/width, EPS [ref: `compactness`] | solo posición de los jugadores de campo | 🟢 alta — direction-agnostic |
| **Superficies de valor** | pitch control, Wide Open Spaces, OBSO, EPV/VAEP/xT [ref: `pitch-control`, `wide-open-spaces`, `obso`, `epv`, `socceraction`] | + velocidad (silver) + pelota (gap upstream) | 🟡 media — sensible a ruido y a la pelota |
| **Dominancia** | score compuesto `w1·ΔxG + w2·Δpitch_control + w3·ΔEPV + w4·Δfield_tilt` [ref: `epv`, `openskill`] | tiers anteriores; field-tilt requiere dirección de ataque | 🟡 media — un término parkeado |

**Éxito:** gold emite, por partido, las métricas de estructura **sin** necesitar dirección de ataque, las superficies de valor disponibles, y un score de dominancia (sobre los términos disponibles) con contribución por jugador, servible al rating y al reporte, **sin pedirle a upstream más que los dos gaps acordados** (pelota + no-identificados, [contratos.md](contratos.md) §3.1).

---

## 2. Contexto y definiciones

| Término | Significado |
|---------|-------------|
| **Gold** | Capa servible del medallón: features derivadas del `Frame` silver [ADR-003]; se persiste en MongoDB (`analytics_reports`, [overview.md](overview.md) §3.4). |
| **`Frame` silver** | Muestra limpia: `timestamp` + `ball` + `players[]` con `position`, `velocity`, `team`, `id` en metros del venue ([datos-medallon.md](datos-medallon.md) §5.2). Insumo único de gold. |
| **Direction-agnostic** | Métrica que **no** necesita saber a qué arco ataca cada equipo. |
| **Centroide** | Media `(x, y)` de los jugadores de campo de un equipo [ref: `compactness`]. |
| **Stretch index** | Media de la distancia euclídea de cada jugador al centroide de su equipo [ref: `compactness`]. |
| **Surface area** | Área del convex hull de los jugadores de un equipo [ref: `compactness`]. |
| **Team spread** | Media de la matriz de distancias entre todos los pares de un equipo [ref: `compactness`]. |
| **Length / width** | Rango ocupado sobre el eje largo / corto de la cancha, por equipo [ref: `compactness`]. |
| **EPS** | *Effective Playing Space*: convex hull de **ambos** equipos a la vez [ref: `compactness`]. |
| **Pitch control** | Campo de probabilidad `[0,1]` de qué equipo controla cada zona; cada jugador = proceso de Poisson sobre posición + velocidad [ref: `pitch-control`]. Impl. de referencia: modelo de Spearman [ref: `friends-of-tracking`]. |
| **Wide Open Spaces** | Valor de espacio creado/ocupado a nivel equipo y jugador, con y sin pelota [ref: `wide-open-spaces`]. |
| **OBSO** | *Off-Ball Scoring Opportunity* = `control × transición × score` — peligro del espacio ocupado **sin** la pelota [ref: `obso`]. |
| **xT / VAEP** | Valor de posesión por acción; convierten event streams a **SPADL** primero; modelos ML [ref: `socceraction`]. |
| **EPV** | *Expected Possession Value*: valor del estado espacio-temporal completo (22 + pelota), descompuesto en componentes interpretables (pase/conducción/tiro/pérdida) [ref: `epv`]. |
| **SPADL** | Representación de acciones on-ball; se **deriva** internamente de tracking + pelota, no se recibe [ref: `socceraction`]. |
| **Field tilt** | Cuota de posesión/peligro de un equipo en el tercio de ataque rival; **requiere** dirección de ataque → término parkeado [ADR-009]. |
| **Dominancia** | Score que mide cuánto **mereció** ganar un equipo, derivado de analytics y **no** de la diferencia de goles; alimenta el `margin` del rating ("el puente") [ADR-002, ref: `openskill`, `epv`]. |
| **Contribución** | Reparto de la dominancia del equipo a cada jugador identificado vía tracking [ref: `epv`, `openskill`]. |
| **Δ (delta)** | Diferencia A−B de un término entre equipos (`ΔxG`, `Δpitch_control`, `ΔEPV`, `Δfield_tilt`), agregada al nivel de partido. |
| **`w1..w4`** | Pesos del score de dominancia; calibración empírica diferida ([contratos.md](contratos.md) §7 #4). |
| **Dirección de ataque** | A qué arco ataca cada equipo. **Fuera del contrato** de entrada [ADR-009]; los términos que la requieren se parkean. |

---

## 3. Requisitos funcionales

### 3.1 Insumo y orden de dependencia

Gold consume **solo** silver y produce features en un **DAG por tier**: estructura → superficies de valor → dominancia. Cada etapa lee únicamente lo que sus dependencias ya dejaron; las métricas direction-agnostic se computan primero por ser las más confiables con tracking amateur ([datos-medallon.md](datos-medallon.md) FR-G1).

| Etapa | Método | Disposición | Disparador / nota |
|-------|--------|-------------|-------------------|
| 1 — Estructura | centroide, stretch, surface area, team spread, length/width, EPS | **Siempre** | Solo `position` + `team`; sin pelota ni dirección [ref: `compactness`]. |
| 2 — Velocidad-dependiente | pitch control, Wide Open Spaces | **Siempre** que silver tenga `velocity` | Posición + velocidad [ref: `pitch-control`, `wide-open-spaces`]. |
| 2 — Pelota-dependiente | OBSO | **Condicional** | Solo con `ball` por frame (gap FR-I4 upstream); sin pelota no hay término de transición [ref: `obso`]. |
| 2 — SPADL-dependiente | xT, VAEP / Atomic-VAEP, EPV | **Condicional** | Requiere derivar SPADL (tracking + pelota); modelos ML en worker Python [ref: `socceraction`, `epv`; ADR-005]. |
| 3 — Dominancia | score compuesto `w1..w4` | **Siempre** sobre términos disponibles | Cada Δ ausente se omite del score; ver §3.5–§3.6. |

| ID | Requisito |
|----|-----------|
| **FR-A1** | Gold **deberá** consumir únicamente frames **silver** validados; **no** leerá bronze ni recalculará limpieza ([datos-medallon.md](datos-medallon.md) FR-B2, FR-S9; [ADR-003]). |
| **FR-A2** | Gold **deberá** computar el tier de **estructura** (§3.2) antes que cualquier superficie de valor, por ser el más confiable con tracking amateur [ref: `compactness`]. |
| **FR-A3** | Gold **deberá** computar las **superficies de valor** (§3.3) antes del **score de dominancia** (§3.5), que las agrega. |
| **FR-A4** | Una etapa **no deberá** ejecutarse si falta su insumo: las superficies pelota-dependientes (OBSO) y SPADL-dependientes (xT/VAEP/EPV) se **omiten** cuando la pelota no está por frame (gap FR-I4 [contratos.md](contratos.md)), sin abortar el resto del cómputo (fallback sin pelota 🟡 Abierto: §7 #2). |
| **FR-A5** | El pipeline **deberá** emitir las features de un tier aunque un tier posterior no pueda completarse (degradación parcial, §3.6). |

### 3.2 Tier de estructura (direction-agnostic) [ref: `compactness`]

Primer tier, el más robusto: solo requiere `position` por jugador y `team`. No necesita dirección de ataque ni la pelota. Fórmulas en [../investigations/datos-y-metricas.md](../investigations/datos-y-metricas.md).

| ID | Feature | Nivel | Insumo |
|----|---------|-------|--------|
| **FR-E1** | `centroid` (`x`, `y`) | por equipo, por frame | `players[].position`, `team` |
| **FR-E2** | `stretch_index` | por equipo, por frame | posiciones + centroide |
| **FR-E3** | `surface_area` (convex hull) | por equipo, por frame | posiciones del equipo |
| **FR-E4** | `team_spread` | por equipo, por frame | matriz de distancias intra-equipo |
| **FR-E5** | `length` / `width` | por equipo, por frame | rango sobre eje largo / corto |
| **FR-E6** | `eps` (Effective Playing Space) | por frame (ambos equipos) | convex hull de los 22 |

| ID | Requisito |
|----|-----------|
| **FR-E7** | Las features FR-E1…FR-E6 **deberán** computarse **sin** dirección de ataque y **sin** la pelota, e incluir a los jugadores de campo **aunque no estén identificados** individualmente: las métricas de equipo necesitan los jugadores en cancha, no su `user_id` (gap FR-I5 [contratos.md](contratos.md)) [ref: `compactness`]. |
| **FR-E8** | Cada feature de estructura **deberá** producirse como serie por frame y como agregado por partido/equipo (media, y curva temporal cuando aporte al reporte). |
| **FR-E9** | Las métricas de estructura **deberían** ser robustas a un jugador faltante por frame (oclusión/missed-detection ya tratada en silver); la política exacta ante recuento incompleto es 🟡 Abierto: §7 #1. |

### 3.3 Tier de superficies de valor

Campos continuos sobre la cancha en cada instante. Dependen de `velocity` (derivada en silver) y, los on-ball, de la **posición de la pelota** (gap upstream). Implementación de referencia: Friends of Tracking (modelo de Spearman) [ref: `friends-of-tracking`]; corren en worker Python [ADR-005].

| ID | Superficie | Requiere | Salida |
|----|-----------|----------|--------|
| **FR-V1** | Pitch control [ref: `pitch-control`] | `position` + `velocity` | campo `[0,1]` por zona, por frame |
| **FR-V2** | Wide Open Spaces [ref: `wide-open-spaces`] | pitch control + modelo de recepción | valor de espacio, equipo y jugador |
| **FR-V3** | OBSO [ref: `obso`] | pitch control + pelota | `control × transición × score`, por zona |
| **FR-V4** | xT / VAEP / Atomic-VAEP [ref: `socceraction`] | SPADL derivado | valor por acción on-ball |
| **FR-V5** | EPV [ref: `epv`] | estado espacio-temporal (22 + pelota) | valor descompuesto por componente |

| ID | Requisito |
|----|-----------|
| **FR-V6** | `pitch_control` **deberá** computarse con **posición + velocidad** en metros del venue [ADR-008]; la velocidad se toma de silver, **no** se recibe ([datos-medallon.md](datos-medallon.md) FR-S6). Es la superficie de valor de menor riesgo: computable **sin** pelota ni dirección. |
| **FR-V7** | La implementación de `pitch_control` **debería** seguir el modelo de Spearman de referencia [ref: `friends-of-tracking`]; la elección concreta (parámetros `λ`, grilla, tiempo de integración) no está fijada en esta versión (🟡 Abierto: §7 #3). |
| **FR-V8** | Las superficies pelota-dependientes (FR-V3) y SPADL-dependientes (FR-V4, FR-V5) **deberán** ejecutarse solo cuando su insumo existe (FR-A4); su ausencia se **registra** en la salida, no se silencia (🟡 derivación de SPADL Abierto: §7 #6). |
| **FR-V9** | EPV **deberá** mantenerse **modular y descompuesto** en componentes interpretables (pase/conducción/tiro/pérdida) en lugar de un único modelo opaco [ref: `epv`]. *Razón: interpretabilidad para la tesis y trazabilidad de la contribución por jugador.* |

*Las fórmulas detalladas viven en [../investigations/superficies-de-valor.md](../investigations/superficies-de-valor.md); este spec no las duplica (NFR-A4).*

### 3.4 Robustez al tracking amateur

El tracking amateur es ruidoso, con huecos e identidades parciales. Gold se diseña para que **el grado de confiabilidad de cada feature sea explícito** y para degradar de forma controlada.

| ID | Requisito |
|----|-----------|
| **FR-R1** | Gold **deberá** asumir que la limpieza ya ocurrió en silver (suavizado, interpolación, continuidad de IDs, outliers) y **no** repetirla ([datos-medallon.md](datos-medallon.md) §3.3, [ref: `metrica-data`]). |
| **FR-R2** | Las features que **no** requieren dirección de ataque (todo el tier de estructura + `pitch_control`) **deberán** computarse primero y marcarse como el núcleo confiable. |
| **FR-R3** | Toda feature **deberá** llevar un indicador de confiabilidad/tier (🟢 estructura · 🟡 valor · término parkeado), para que el consumidor sepa cuánto pesarla. |
| **FR-R4** | El score de dominancia (§3.5) **deberá** poder calcularse con un subconjunto de términos cuando alguno no esté disponible, reponderando o anulando su peso (§3.6). |
| **FR-R5** | Gold **deberá** validarse sobre **Metrica degradado** (mismo banco que silver): se compara la feature sobre el tracking limpio vs sobre el degradado-y-recuperado y se reporta la sensibilidad al ruido por feature ([datos-medallon.md](datos-medallon.md) §3.5; umbrales 🟡 Abierto: §7 #4). |
| **FR-R6** | Gold **no deberá** presentar resultados de validación sintética como evidencia sobre tracking amateur real; se rotulan como sintéticos ([overview.md](overview.md) NFR-8). |

### 3.5 Score de dominancia [ref: `openskill`, `epv`]

El puente de la tesis: la dominancia (no la diferencia de goles) alimenta el `margin` del rating [ADR-002]. Forma canónica ([../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md)):

```text
dominancia = w1·ΔxG  +  w2·Δpitch_control  +  w3·ΔEPV  +  w4·Δfield_tilt
```

ilustrativa — los pesos `w1..w4` y la normalización son 🟡 Abierto: §7 #5.

| ID | Término | Δ a partir de | Disponibilidad |
|----|---------|---------------|----------------|
| **FR-D1** | `w1·ΔxG` | xG/xT del equipo [ref: `socceraction`] | condicional (pelota/SPADL) |
| **FR-D2** | `w2·Δpitch_control` | agregado de pitch control (FR-V1) | siempre que haya `velocity` |
| **FR-D3** | `w3·ΔEPV` | EPV del equipo (FR-V5) | condicional (pelota/SPADL) |
| **FR-D4** | `w4·Δfield_tilt` | cuota de peligro en tercio rival | **parkeado** — requiere dirección de ataque [ADR-009] |

| ID | Requisito |
|----|-----------|
| **FR-D5** | Gold **deberá** producir un **score de dominancia por equipo** (cuánto mereció ganar) como combinación lineal ponderada de los términos Δ **disponibles**, omitiendo aquellos cuyo insumo no exista y dejando registro de cuáles entraron ([contratos.md](contratos.md) FR-O1). |
| **FR-D6** | La dominancia **deberá** derivarse de analytics y **no** de la diferencia de goles [ADR-002, ref: `openskill`, `epv`] ([contratos.md](contratos.md) FR-O2). |
| **FR-D7** | El término `Δfield_tilt` (FR-D4) **no deberá** computarse mientras la dirección de ataque esté fuera del contrato: el score **deberá** poder calcularse con `w4 = 0` hasta que la dirección sea confiable [ADR-009] (🟡 Abierto: §7 #4). *Razón: field tilt necesita el tercio de ataque, que depende de la dirección no provista.* |
| **FR-D8** | Los términos `ΔxG` y `ΔEPV` **deberán** diferirse junto con sus insumos (pelota + SPADL, FR-V8); con tracking amateur de día 1, la dominancia **debería** poder sostenerse sobre `Δpitch_control` (disponible sin pelota ni dirección, FR-V6) más estructura. |
| **FR-D9** | Los pesos `w1..w4` **deberán** calibrarse empíricamente, **no** fijarse a priori; no se fijan valores en esta versión ([contratos.md](contratos.md) §7 #4; 🟡 Abierto: §7 #5). |
| **FR-D10** | El score **deberá** ser interpretable: cada término y su peso **deberán** poder reportarse por separado (patrón descompuesto de EPV) [ref: `epv`]. |

### 3.6 Contribución por jugador y degradación parcial

| ID | Requisito |
|----|-----------|
| **FR-C1** | Gold **deberá** repartir la dominancia del equipo a cada jugador **identificado** vía contribución derivada del tracking (VAEP/EPV por jugador) [ref: `epv`, `openskill`]; el método de reparto no está fijado en esta versión (🟡 Abierto: §7 #7). |
| **FR-C2** | La contribución **deberá** referenciar al jugador por `user_id` (registrado o invitado), consistente con [contratos.md](contratos.md) FR-O3. |
| **FR-C3** | Un jugador **no** identificado **deberá** aportar a las métricas de equipo (FR-E7) pero **no** recibir contribución individual (sin `user_id` no hay a quién repartir); el reparto a invitados es 🟡 Abierto: §7 #8. |
| **FR-P1** | Cuando un término de dominancia no tenga insumos (sin pelota → sin `ΔxG`/`ΔEPV`; sin dirección → sin `Δfield_tilt`), el score **deberá** computarse con los términos disponibles, dejando registro de qué términos se omitieron y con qué peso efectivo (FR-R4). |
| **FR-P2** | El documento de gold **deberá** registrar qué tier/términos/superficies se computaron y cuáles se difirieron (presencia de pelota, de SPADL, de field-tilt), para honestidad del dato y para que el rating y el reporte sepan sobre qué base se computó la dominancia (FR-R3, FR-R6). |
| **FR-P3** | Reejecutar gold sobre el mismo silver **deberá** producir el mismo artefacto (idempotencia, [overview.md](overview.md) NFR-5). |

### 3.7 Agregación y salida

| ID | Requisito |
|----|-----------|
| **FR-O1** | Gold **deberá** agregar las features por-frame a **un documento por partido** servible desde MongoDB (colección `analytics_reports`, [overview.md](overview.md) §3.4) [ADR-006]. |
| **FR-O2** | El documento de gold **deberá** contener, como mínimo, la dominancia por equipo (FR-D5) y la contribución por jugador identificado (FR-C1), conforme al contrato `scoring.json` ([contratos.md](contratos.md) §3.3). |
| **FR-O3** | Gold **deberá** producir también agregados por jugador y por equipo, no solo el score de partido ([datos-medallon.md](datos-medallon.md) FR-G2). |
| **FR-O4** | El esquema exacto de los campos `metrics` de `scoring.json` (qué agregados, normalización, escala) **no** está congelado — 🟡 Abierto: §7 #9, alineado con [contratos.md](contratos.md) §7 #2. |

---

## 4. Requisitos no-funcionales

| ID | Requirement |
|----|-------------|
| NFR-A1 | **Orden de dependencia explícito:** el pipeline de gold **deberá** materializar el DAG estructura → valor → dominancia; ningún tier lee salidas de un tier posterior (FR-A2–FR-A5). |
| NFR-A2 | **Robustez al tracking amateur:** las métricas de estructura (§3.2) **deberán** producirse sin dirección de ataque y tolerar identidades parciales; son el piso confiable cuando lo demás falla (FR-R1, FR-R2). |
| NFR-A3 | **Degradación elegante:** la ausencia de pelota o SPADL **deberá** reducir el conjunto de superficies/términos disponibles, **no** abortar el documento de gold (FR-A4, FR-V8, FR-P1). |
| NFR-A4 | **Una fuente de verdad:** las fórmulas viven en las investigaciones; gold las implementa, este spec no las duplica. Las dimensiones del venue se leen de `job.meta.json`, no por frame ([contratos.md](contratos.md) FR-I2). |
| NFR-A5 | **Interpretabilidad:** toda superficie/score **deberá** descomponerse en términos reportables por separado, no como caja negra [ref: `epv`]. |
| NFR-A6 | **Trazabilidad de método:** cada feature/superficie/término **deberá** citar su `[ref: ...]` de [references.md](../research/references.md) en código/issue ([datos-medallon.md](datos-medallon.md) NFR-D5). |
| NFR-A7 | **Idempotencia:** recomputar gold desde el mismo silver **deberá** producir el mismo documento (overwrite o versión por `match_id`) ([overview.md](overview.md) NFR-5). |
| NFR-A8 | **VPS-only:** todo el I/O, las superficies y los modelos ML **deberán** correr en storage local o adjunto al VPS y en el worker Python del VPS, sin egress a cloud [ADR-005]. |
| NFR-A9 | **Agnóstico al stride:** ningún cómputo de gold **deberá** asumir 25 fps ni un `frame_stride` fijo; se trabaja sobre `timestamp` canónico y velocidades en m/s de silver [ADR-008] ([datos-medallon.md](datos-medallon.md) NFR-D2). |
| NFR-A10 | **Honestidad de datos:** los valores computados sobre Metrica degradado sintéticamente **no deberán** rotularse como evidencia sobre tracking amateur real ([overview.md](overview.md) NFR-8, [ref: `metrica-data`]). |

---

## 5. Interfaces / contratos

Gold consume el **`Frame` silver** y produce el documento **gold** (insumo de `scoring.json` y del reporte). El esquema exacto de salida se fija en [contratos.md](contratos.md); acá, la forma de las features.

### 5.1 Entrada — `Frame` silver

Modelo `Frame` limpio producido por la etapa silver del medallón; esquema normativo en [datos-medallon.md](datos-medallon.md) §5.2. Campos usados por gold:

| Campo | Tipo | Usado por |
|-------|------|-----------|
| `timestamp` | number/index | agregación temporal, todas las etapas |
| `ball` | Point3D | OBSO, SPADL, EPV (condicional) |
| `players[].position` | Point3D (m) | estructura, pitch control |
| `players[].velocity` | Point2D (m/s) | pitch control, Wide Open Spaces |
| `players[].team` | enum (`a`\|`b`) | todas las métricas por equipo |
| `players[].id` | string | contribución por jugador |

### 5.2 Salida — documento gold / `scoring.json` (ilustrativo)

Un documento por partido en `analytics_reports`; es la capa servible y respalda `scoring.json`. Esquema de frontera en [contratos.md](contratos.md) §3.3 y §5.4. Ejemplo mínimo (illustrative; `metrics` por encima del mínimo es 🟡 Abierto: §7 #9):

```json
{
  "match_id": "match_789",
  "structure": {
    "team_a": { "centroid": [52.1, 30.0], "stretch_index": 9.4, "surface_area": 612.0, "team_spread": 18.2, "length": 41.0, "width": 28.5 },
    "team_b": { "centroid": [48.7, 31.2], "stretch_index": 10.1, "surface_area": 640.5, "team_spread": 19.0, "length": 43.2, "width": 30.1 },
    "eps": 1180.0
  },
  "value_surfaces": {
    "pitch_control": { "team_a_share": 0.54, "available": true },
    "obso":  { "available": false, "deferred_reason": "ball_missing" },
    "epv":   { "available": false, "deferred_reason": "spadl_missing" }
  },
  "dominance": {
    "team_a": 0.61, "team_b": 0.39,
    "terms": { "xg": null, "pitch_control": 0.08, "epv": null, "field_tilt": null },
    "weights": { "w1": 0.0, "w2": 1.0, "w3": 0.0, "w4": 0.0 },
    "deferred_terms": ["xg", "epv", "field_tilt"],
    "field_tilt_included": false
  },
  "players": [
    { "user_id": "usr_abc123", "team": "team_a", "contribution": 0.14 }
  ]
}
```

> Ilustrativo, **no** normativo: el esquema congelado vive en [contratos.md](contratos.md) (🟡 Abierto: §7 #2 de ese doc).

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `match_id` | string | sí | Partido (FR-O1). |
| `structure` | object | sí | Tier de estructura por equipo + `eps` (FR-E1–FR-E6). |
| `value_surfaces` | object | recomendado | Superficies disponibles + flag `available`/`deferred_reason` por superficie (FR-V1–FR-V9, FR-P2). |
| `dominance.team_a/.team_b` | number | sí | Score de dominancia por equipo (FR-D5). |
| `dominance.terms` | object | sí | `xg`, `pitch_control`, `epv`, `field_tilt`; `null` si diferido (FR-D1–FR-D4, FR-P1). |
| `dominance.weights` | object | sí | `w1..w4` aplicados (calibración diferida, FR-D9). |
| `dominance.field_tilt_included` | boolean | recomendado | Si `Δfield_tilt` se computó (FR-D7); hoy `false` [ADR-009]. |
| `players[].user_id` | string | sí (identificado) | Identidad a la que se reparte (FR-C2). |
| `players[].contribution` | number | sí (identificado) | Aporte del jugador a la dominancia de su equipo (FR-C1). |

> Frontera downstream: el módulo `ratings` consume `dominance` como `margin` del rating; `analytics_reports` alimenta el reporte de la app ([overview.md](overview.md) §3.4, [contratos.md](contratos.md) §5.4).

### 5.3 Gaps que gold hereda de upstream

Gold no le pide nada nuevo a upstream más allá de los dos gaps ya acordados en [contratos.md](contratos.md) §3.1; se repiten acá por trazabilidad de qué feature los necesita.

| Gap | Feature bloqueada | Por qué |
|-----|-------------------|---------|
| **Posición de la pelota** por frame ([contratos.md](contratos.md) FR-I4) | OBSO, EPV, xT/VAEP, `ΔxG`, `ΔEPV` (FR-V3–V5, FR-D1, FR-D3) | sin pelota no hay SPADL ni valor on-ball ni término de transición de OBSO [ref: `socceraction`, `obso`]. |
| **Jugadores no-identificados** con posición ([contratos.md](contratos.md) FR-I5) | tier de estructura, `pitch_control` (FR-E7, FR-V1) | las métricas de equipo necesitan los jugadores de campo aunque no estén identificados [ref: `compactness`, `pitch-control`]. |

> La **dirección de ataque** **no** se pide [ADR-009]; por eso `Δfield_tilt` queda parkeado (FR-D7).

---

## 6. Criterios de aceptación

1. Gold lee únicamente frames silver validados y nunca parquet de bronze (FR-A1).
2. El tier de estructura se computa antes que las superficies de valor, y la dominancia después de ellas; el orden del DAG es observable (FR-A2, FR-A3, NFR-A1).
3. Centroide, stretch, surface area, team spread, length/width y EPS se computan **sin** dirección de ataque ni pelota, incluyendo jugadores de campo sin `user_id` por su `position`/`team` (FR-E1–FR-E7).
4. Cada feature de estructura sale como serie por frame y como agregado por partido/equipo (FR-E8).
5. `pitch_control` se computa con posición + velocidad en metros del venue, sin pelota ni dirección (FR-V1, FR-V6).
6. Cuando el frame no trae `ball`, OBSO/xT/VAEP/EPV se omiten con su `deferred_reason` y el resto del documento se produce igual (FR-A4, FR-V8, FR-P1, FR-P2, NFR-A3).
7. EPV se entrega descompuesto en componentes interpretables, no como un único score opaco (FR-V9).
8. Cada feature lleva su indicador de tier/confiabilidad en la salida (FR-R3).
9. El score de dominancia se compone de `ΔxG`, `Δpitch_control`, `ΔEPV`, `Δfield_tilt` con pesos `w1..w4` reportados por separado, y se deriva de analytics, no de la diferencia de goles (FR-D5, FR-D6, FR-D10).
10. El término `Δfield_tilt` **no** se computa (`field_tilt_included: false`, `w4 = 0`) y, si faltan pelota/SPADL, el score se calcula sobre `Δpitch_control` + estructura dejando registro de los términos omitidos (FR-D7, FR-D8, FR-P1).
11. Cada jugador identificado recibe una `contribution`; los no-identificados aportan a equipo pero no reciben contribución individual (FR-C1, FR-C3).
12. Existe un documento de gold por partido en `analytics_reports`, servible al rating y al reporte (FR-O1, FR-O2, FR-O3).
13. La validación sobre Metrica degradado reporta sensibilidad al ruido por feature y queda rotulada como sintética (FR-R5, FR-R6, NFR-A10).
14. Recomputar gold desde el mismo silver produce un documento idéntico (FR-P3, NFR-A7).

---

## 7. Open design items

| # | Topic | Notes |
|---|-------|-------|
| 1 | Recuento incompleto de jugadores (FR-E9) | Política de estructura ante un equipo con <11 en cancha por frame: imputar, ponderar o marcar baja confianza. |
| 2 | Fallback de scoring sin pelota (FR-A4) | Qué dominancia se reporta cuando upstream no entrega pelota; coordinado con [contratos.md](contratos.md) §7 #3. |
| 3 | Implementación de `pitch_control` (FR-V7) | Modelo de Spearman de referencia [ref: `friends-of-tracking`] vs variante propia; parámetros (`λ`, grilla, tiempo de integración). |
| 4 | Field tilt / dirección de ataque (FR-D7) | Field tilt requiere dirección de ataque, hoy parkeada [ADR-009]; si/cuándo estimar dirección confiable para reintroducir `Δfield_tilt`, o si se reemplaza el término. |
| 5 | Pesos `w1..w4` (FR-D9) | Composición, normalización y calibración empírica del score compuesto; coincide con [contratos.md](contratos.md) §7 #4. |
| 6 | Derivación de SPADL (FR-V8) | Cómo derivar acciones on-ball sin event stream upstream: detección on-ball desde tracking + pelota; habilita xT/VAEP y la descomposición de EPV. Es interno, no entra al contrato [ADR-009]. |
| 7 | Reparto de contribución (FR-C1) | Método para atribuir la dominancia del equipo a jugadores vía tracking (VAEP/EPV por jugador). |
| 8 | Contribución a invitados (FR-C3) | Cómo se persiste la contribución de un `user_id` invitado (rating en la sombra); coordina con [contratos.md](contratos.md) §7 #5. |
| 9 | Esquema de `metrics`/salida congelado (FR-O4) | Campos exactos de `structure`/`value_surfaces`/`dominance`, normalización y escala; se fija en [contratos.md](contratos.md) §7 #2, no acá. |
| 10 | Agregación temporal de deltas | Cómo integrar los `Δ` sobre el partido (media, integral ponderada por posesión/tiempo, percentiles). |

---

## 8. Trazabilidad y scope por etapa

### 8.1 Scope por product stage

| Stage | ¿En este spec? |
|-------|----------------|
| **POC** — reconstrucción | No — sistema separado upstream; produce el silver indirectamente vía bronze [ADR-001]. |
| **Thesis scope** — analytics (gold) | **Sí** (§3–§6): estructura, superficies de valor, dominancia, contribución. |
| **Deferred** — métricas tácticas / SPADL real | No — PPDA, line-breaking, packing y field-tilt requieren dirección/SPADL y se difieren [ADR-009; FR-D7] ([datos-medallon.md](datos-medallon.md) FR-G3). |
| **Production** | No — calibración a escala, multi-VPS, índices/particionado y optimización de cómputo quedan fuera. |

**Out of scope (este spec):**

- Modelo `Frame`, limpieza/calidad de silver, validación sintética y persistencia ([datos-medallon.md](datos-medallon.md) §3.1, §3.3, §3.5).
- Esquema congelado de `scoring.json` y de las colecciones ([contratos.md](contratos.md) §7, [overview.md](overview.md) §7).
- Rating OpenSkill y matchmaking; el puente consume la dominancia pero su lógica vive en la Rama A ([overview.md](overview.md), [../investigations/rating-y-matchmaking.md](../investigations/rating-y-matchmaking.md)).
- Métricas tácticas dirección-dependientes (PPDA, line-breaking, packing, field tilt como entregable) — parkeadas [ADR-009].
- Fórmulas matemáticas de cada método — investigaciones.

### 8.2 Trazabilidad

| Requisito | → AC | → ADR / ref |
|-----------|------|-------------|
| FR-A1 | AC #1 | [ADR-003] |
| FR-A2, FR-A3 | AC #2 | NFR-A1 |
| FR-A4, FR-A5, FR-P1, FR-P2 | AC #6, #10 | gap FR-I4 [contratos.md] |
| FR-E1–FR-E7 | AC #3 | [ref: `compactness`]; gap FR-I5 [contratos.md] |
| FR-E8 | AC #4 | serie + agregado |
| FR-E9 | — | §7 #1 (abierto) |
| FR-V1, FR-V6 | AC #5 | [ref: `pitch-control`] |
| FR-V2 | — | [ref: `wide-open-spaces`] |
| FR-V3, FR-V4, FR-V5, FR-V8 | AC #6 | [ref: `obso`, `socceraction`, `epv`] |
| FR-V7 | — | §7 #3 (abierto) |
| FR-V9 | AC #7 | [ref: `epv`] |
| FR-R1, FR-R2 | AC #2, #3 | [ref: `metrica-data`] |
| FR-R3 | AC #8 | indicador de tier |
| FR-R4 | AC #10 | reponderación |
| FR-R5, FR-R6 | AC #13 | [ADR/NFR-8 overview]; §7 #4 |
| FR-D1, FR-D2, FR-D3 | AC #9 | [ref: `socceraction`, `pitch-control`, `epv`] |
| FR-D5, FR-D6, FR-D10 | AC #9 | [ADR-002, ref: `openskill`, `epv`] |
| FR-D7, FR-D8 | AC #10 | [ADR-009]; §7 #4 |
| FR-D9 | — | §7 #5 (abierto) |
| FR-C1, FR-C2 | AC #11 | [ref: `epv`, `openskill`] |
| FR-C3 | AC #11 | §7 #8 |
| FR-P3 | AC #14 | idempotencia; NFR-A7 |
| FR-O1, FR-O2, FR-O3 | AC #12 | [ADR-006], [contratos.md] §3.3, [datos-medallon.md] FR-G2 |
| FR-O4 | — | §7 #9 (abierto) |
| NFR-A1 | AC #2 | DAG |
| NFR-A3 | AC #6 | degradación |
| NFR-A5 | AC #7, #9 | interpretabilidad |
| NFR-A7 | AC #14 | idempotencia |
| NFR-A10 | AC #13 | honestidad de datos |
| NFR-A2, NFR-A4, NFR-A6, NFR-A8, NFR-A9 | — | restricciones estructurales verificadas por inspección de diseño |

> Cada requisito traza a ≥1 criterio de aceptación o a una validación documentada en una spec hermana.

---

## 9. Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-06-09 | Borrador inicial de la rama de Analytics (gold): tiers de estructura / superficies de valor / dominancia, orden de dependencia (DAG), robustez al tracking amateur, contribución por jugador, salida gold, criterios de aceptación, open items y trazabilidad a research/ADRs. Field-tilt parkeado [ADR-009]; términos pelota/SPADL-dependientes diferidos. |
