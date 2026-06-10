# Especificación — Datos (medallón)

**Status:** Decisiones tomadas
**Version:** 0.3
**Last updated:** 2026-06-09
**Stage:** Thesis scope

Define el modelo de datos del sistema de scoring: el `Frame` canónico (metros del venue, agnóstico al `frame_stride`), las tres capas del medallón (bronze/silver/gold), la limpieza/calidad de silver como etapa propia, la validación por degradación sintética de Metrica, y la persistencia (parquet para per-frame, MongoDB para gold servible). **No** cubre las fórmulas de las métricas de gold (viven en §3.4/§8.1) ni el rating/matchmaking.

> **Cross-refs:** [overview.md](overview.md) (arquitectura) · [contratos.md](contratos.md) (I/O entre sistemas) · [../investigations/datos-y-metricas.md](../investigations/datos-y-metricas.md) (fundamentación) · [../research/references.md](../research/references.md) (fuentes) · [spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.

---

## 1. Propósito y alcance

Llevar la serie per-frame cruda de la reconstrucción a **features servibles**, recorriendo tres estados del mismo dato. La limpieza es una **etapa propia y auditable**, anterior a cualquier métrica.

| Capa | Estado del dato | Persistencia | Acceso |
|------|-----------------|--------------|--------|
| 🥉 **Bronze** | crudo, inmutable | parquet (archivos) | reproceso, auditoría |
| 🥈 **Silver** | limpio y conforme | parquet (archivos) | insumo de gold |
| 🥇 **Gold** | features listas | MongoDB | rating + reporte de la app |

Capas **lógicas**, no infraestructura de lakehouse: tres representaciones del mismo dato con distinto grado de procesamiento, persistidas según patrón de acceso.

**Éxito:** silver recupera una aproximación de tracking limpio a partir de tracking degradado sintéticamente, y gold queda servible desde Mongo (un documento por partido) para el rating y el reporte.

---

## 2. Contexto y definiciones

| Término | Significado |
|---------|-------------|
| **Frame** | Muestra posicional en un instante: índice temporal + `ball` + `players[]`. Modelo canónico vendor-independiente [ref: `kloppy`]. Ver §3.1. |
| **Point3D** | Coordenada `(x, y, z)` en metros del venue. |
| **Point2D** | Par `(x, y)`; usado para `velocity` en m/s. |
| **Metros del venue** | Coordenadas canónicas en metros con las dimensiones reales de la cancha (las amateur varían). Helper a `[0,1]` on-demand, no persistido. |
| **`frame_stride`** | Cada cuántos frames de video se emite una muestra (`output.frame_stride` upstream). El modelo `Frame` es agnóstico (no asume 25 fps). |
| **Venue** | Cancha física con dimensiones y homografía almacenadas; el upstream las usa para proyectar a metros ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §4.2). |
| **Bronze** | Estado crudo e inmutable: `reconstruction.json` tal cual + datos del árbitro. Posiciones crudas, IDs parciales, ruido, huecos. |
| **Silver** | Estado limpio y conforme: suavizado, interpolación, continuidad de IDs, outliers removidos, normalización a metros-venue, velocidades derivadas, equipo asignado, calidad validada. |
| **Gold** | Features derivadas: métricas espaciales de estructura, dominancia, agregados por partido/jugador/equipo. |
| **Métricas de estructura** | Direction-agnostic, robustas: centroide, stretch index, surface area, team spread, length/width, EPS [ref: `compactness`]. |
| **Métricas tácticas** | Requieren eventos derivados (SPADL) y dirección de ataque: PPDA, line-breaking, packing [ref: `ppda-packing`, `line-breaking`]. Diferidas. |
| **SPADL** | Representación de acciones on-ball; se **deriva** internamente, no se recibe [ref: `socceraction`]. |
| **Degradación sintética** | Inyección de ruido, huecos e ID-switches sobre tracking limpio para simular calidad amateur. Ver §3.5. |
| **Metrica** | Datos abiertos de tracking + eventos (2 partidos) para desarrollo y validación [ref: `metrica-data`]. |

---

## 3. Requisitos funcionales

### 3.1 Modelo `Frame` canónico

Modelo per-frame vendor-independiente [ref: `kloppy`], agnóstico al `frame_stride`.

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `timestamp` | number (s) o `frame_index` | sí | Índice temporal compartido para sincronizar con eventos derivados. |
| `ball` | Point3D | sí (silver) | Pelota en metros del venue. En bronze puede faltar — gap upstream (§5.1). |
| `players[]` | lista | sí | Un entry por jugador en cancha (apunta a los 22; ver §3.2). |
| `players[].position` | Point3D | sí | Posición en **metros del venue**. |
| `players[].team` | enum (`a`\|`b`) | sí (silver) | Asignación de equipo, derivada en silver (FR-S7). |
| `players[].id` | string | sí | Track id o `user_id`; continuidad garantizada en silver (FR-S3). |
| `players[].velocity` | Point2D (m/s) | sí (silver) | **Derivada** en silver, no recibida (FR-S6). |

**FR-F1:** El `Frame` **deberá** expresar toda posición en metros del venue, sin asumir una resolución temporal fija.
**FR-F2:** El sistema **deberá** poder normalizar a `[0,1]` on-demand desde las dimensiones del venue, sin persistir esa forma como canónica.
**FR-F3:** El sistema **deberá** sincronizar cualquier evento derivado (SPADL) al `Frame` por el índice temporal compartido.
**FR-F4:** El `Frame` **deberá** poder representar jugadores no-identificados individualmente (sin `user_id`) preservando su `position`, para que las métricas de equipo cuenten con los 11 (🟡 Abierto: §7 #7).

### 3.2 Bronze — crudo e inmutable

| Contenido | Origen |
|-----------|--------|
| `reconstruction.json` tal cual | pipeline de reconstrucción (§5.1) |
| Datos del árbitro | app de árbitro (cards, score, time) |

**FR-B1:** Bronze **deberá** almacenarse inmutable: posiciones crudas, IDs parciales, ruido y huecos se conservan sin corrección.
**FR-B2:** El sistema **no deberá** derivar métricas directamente de bronze; toda métrica consume silver. *Razón: separar limpieza de cálculo hace auditable la calidad.*
**FR-B3:** Bronze **deberá** preservar el `frame_stride` y las dimensiones del venue de origen, sin duplicar dimensiones por frame — viven en `job.meta.json` ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.2).

### 3.3 Silver — limpieza y calidad (etapa propia)

Etapa **antes** de cualquier métrica. Cada operación es un requisito. Implementación concreta de los algoritmos: no especificada en esta versión (🟡 Abierto: §7 #6).

| ID | Operación | Detalle |
|----|-----------|---------|
| **FR-S1** | Suavizado de trayectorias | Reducir jitter posicional cuadro a cuadro. |
| **FR-S2** | Interpolación de oclusiones | Rellenar huecos por oclusión / missed-detection. |
| **FR-S3** | Continuidad de IDs | Reconstruir track continuo ante ID-switches y breaks. |
| **FR-S4** | Remoción de outliers | Descartar saltos físicamente imposibles. |
| **FR-S5** | Normalización a metros-venue | Llevar todo a coordenadas canónicas (§3.1). |
| **FR-S6** | Derivación de velocidades | Calcular `velocity` por jugador desde posiciones consecutivas. |
| **FR-S7** | Asignación de equipo | Asignar `team` a cada jugador (🟡 Abierto: §7 #1). |
| **FR-S8** | Validación de calidad | Verificar umbrales antes de habilitar gold (§3.5, 🟡 Abierto: §7 #2). |

**FR-S9:** Silver **deberá** completar las ocho operaciones (FR-S1…FR-S8) antes de exponer cualquier `Frame` a gold.

### 3.4 Gold — features servibles

**FR-G1:** Gold **deberá** computar primero las métricas de estructura direction-agnostic [ref: `compactness`] por ser las más confiables con tracking amateur (no requieren dirección de ataque).
**FR-G2:** Gold **deberá** producir agregados por partido, por jugador y por equipo.
**FR-G3:** Las métricas tácticas (PPDA, line-breaking, packing) **deberían** diferirse: dependen de SPADL derivado y de la dirección de ataque, no provistas en esta etapa [ref: `ppda-packing`, `line-breaking`].
**FR-G4:** Gold **deberá** ser el insumo del rating y del reporte de la app, como un documento por partido (§5.3).

*Las fórmulas de las métricas viven en [../investigations/datos-y-metricas.md](../investigations/datos-y-metricas.md); este spec no las duplica.*

### 3.5 Validación por degradación sintética

No hay tracking amateur real todavía → se valida degradando tracking limpio de Metrica [ref: `metrica-data`].

**FR-V1:** El sistema **deberá** generar tracking de calidad amateur **degradando** tracking limpio de Metrica con ruido, huecos e ID-switches.
**FR-V2:** El pipeline de silver **deberá** ejecutarse sobre la versión degradada y **recuperar** una aproximación de la verdad limpia.
**FR-V3:** El sistema **deberá** medir el error entre silver-recuperado y la verdad limpia de Metrica por operación de §3.3 (umbrales: 🟡 Abierto §7 #2).

---

## 4. Requisitos no-funcionales

| ID | Requirement |
|----|-------------|
| NFR-D1 | **Persistencia por capa:** bronze y silver en parquet (archivos); gold en MongoDB. Frames crudos **nunca** en la base. |
| NFR-D2 | **Agnosticismo de cadencia:** ningún componente **deberá** asumir 25 fps ni un `frame_stride` fijo. |
| NFR-D3 | **Inmutabilidad de bronze:** reprocesar silver/gold **no deberá** mutar bronze. |
| NFR-D4 | **Idempotencia:** reejecutar silver o gold sobre el mismo bronze produce el mismo artefacto (overwrite o versión por partido). |
| NFR-D5 | **Trazabilidad de método:** cada métrica de gold **deberá** citar su `[ref: ...]` de [references.md](../research/references.md) en código/issue. |
| NFR-D6 | **VPS-only:** I/O en almacenamiento local o adjunto al VPS, sin egress a cloud. |
| NFR-D7 | **Honestidad de datos:** la validación sintética **no deberá** presentarse como evidencia sobre tracking amateur real; se rotula como sintética. |

---

## 5. Interfaces / contratos

Detalle completo en [contratos.md](contratos.md); acá, los esquemas de capa.

### 5.1 Entrada — `reconstruction.json` (bronze)

Serie per-frame del pipeline de reconstrucción ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5.1). Por muestra: `frame_index`, `timestamp_ms`, `players[]` con `user_id`, `x`, `y`, `z`, `confidence` (metros). Las dimensiones del venue viven en `job.meta.json` (upstream §5.2).

```json
{
  "frame_index": 1200,
  "timestamp_ms": 40000,
  "players": [
    { "user_id": "usr_abc123", "x": 34.2, "y": 12.8, "z": 0.0, "confidence": 0.91 }
  ]
}
```

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `frame_index` / `timestamp_ms` | integer | sí | Índice temporal de la muestra. |
| `players[].user_id` | string | cuando identificado | `user_id` del roster; puede faltar si no se resolvió el dorsal (upstream §5.1). |
| `players[].x`, `.y` | number | sí | Plano de cancha, metros (origen: 🟡 Abierto §7 #4). |
| `players[].z` | number | opcional | Default 0 (plano del suelo). |
| `players[].confidence` | number | recomendado | Confianza de identidad/detección. |

**Gaps que se le piden a upstream:**

| Gap | Por qué |
|-----|---------|
| **Posición de la pelota** por frame | sin pelota no hay SPADL ni valor on-ball ni término de transición de OBSO. |
| **Jugadores no-identificados** con posición | las métricas de equipo necesitan los 11 aunque no estén identificados individualmente. |

> La **dirección de ataque** **no** se pide: no es confiable y las métricas comprometidas son direction-agnostic [ref: `compactness`].

### 5.2 Frame silver (parquet)

```json
{
  "timestamp": 48.0,
  "ball": { "x": 52.1, "y": 30.0, "z": 0.4 },
  "players": [
    { "id": "usr_abc123", "team": "a", "position": { "x": 34.2, "y": 12.8, "z": 0.0 }, "velocity": { "x": 1.2, "y": -0.3 } }
  ]
}
```

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `timestamp` | number/index | sí | Índice temporal canónico. |
| `ball` | Point3D | sí | Metros del venue. |
| `players[].id` | string | sí | Track continuo o `user_id`. |
| `players[].team` | enum | sí | `a` \| `b`. |
| `players[].position` | Point3D | sí | Metros del venue. |
| `players[].velocity` | Point2D | sí | m/s, derivada. |

### 5.3 Salida — gold (MongoDB)

Un documento por partido en la colección de reportes de analytics ([overview.md](overview.md)), con métricas espaciales de estructura, dominancia y agregados por partido/jugador/equipo. Esquema exacto: ver `scoring.json` en [contratos.md](contratos.md) (🟡 Abierto: §7 #3).

---

## 6. Criterios de aceptación

1. Un `Frame` cargado expresa posiciones en metros del venue y se procesa con dos `frame_stride` distintos sin cambios de lógica (FR-F1, FR-B3, NFR-D2).
2. El normalizador a `[0,1]` produce coordenadas correctas desde las dimensiones del venue sin persistir esa forma (FR-F2).
3. Bronze persistido es byte-idéntico tras reejecutar silver y gold (FR-B1, NFR-D3).
4. Ningún cómputo de gold lee parquet de bronze directamente (FR-B2).
5. Sobre Metrica degradado, silver ejecuta FR-S1…FR-S8 y emite frames con `team`, `velocity` e IDs continuos antes de exponer a gold (FR-S3, FR-S6, FR-S7, FR-S9).
6. El error silver-recuperado vs verdad limpia de Metrica se reporta por operación de §3.3 (FR-V2, FR-V3).
7. Las métricas de estructura direction-agnostic se computan sin requerir dirección de ataque (FR-G1).
8. Existe un documento de gold por partido en Mongo, servible al rating/reporte (FR-G2, FR-G4, NFR-D1).
9. Reejecutar silver/gold sobre el mismo bronze produce artefactos idénticos (NFR-D4).
10. Los artefactos de validación están rotulados como sintéticos (NFR-D7).
11. Un `Frame` con jugadores sin `user_id` conserva sus `position` y esos jugadores alimentan las métricas de equipo de gold (FR-F4).

---

## 7. Open design items

| # | Topic | Notes |
|---|-------|-------|
| 1 | Método de asignación de equipo (FR-S7) | Clustering por color de camiseta vs roster del upstream vs otro. |
| 2 | Umbrales de calidad de silver (FR-S8, FR-V3) | Qué error máximo por operación habilita gold; métrica exacta por operación. |
| 3 | Esquema de salida de gold / `scoring.json` (FR-G4) | Score de dominancia + contribución por jugador; esquema exacto a definir ([contratos.md](contratos.md)). |
| 4 | Origen de coordenadas del venue (FR-S5, §5.1) | Centro vs esquina; debe alinearse con la convención del upstream (upstream §9 #4). |
| 5 | Layout/particionado de parquet (NFR-D1) | Por partido, por capa, por chunk temporal. |
| 6 | Algoritmos concretos de FR-S1…FR-S6 | Suavizado, interpolación, re-ID, detección de outliers — implementación no especificada. |
| 7 | Representación de jugadores no-identificados (FR-F4) | Cómo se modela el `id` provisional y cómo se concilia con la política de identidad upstream (upstream §9 #3). |

---

## 8. Trazabilidad y scope por etapa

### 8.1 Scope por product stage

| Stage | ¿En este spec? |
|-------|----------------|
| **POC** — reconstrucción | No — sistema separado (upstream); produce el insumo bronze. |
| **Thesis scope** — scoring | **Sí** (§3–§6): bronze/silver/gold del sistema de scoring. |
| **Deferred** — event detection | No — SPADL/eventos derivados se difieren (FR-G3). |
| **Production** | No — Redis, escalado y particionado avanzado quedan fuera. |

**Out of scope (este spec):**

- Fórmulas de las métricas de gold (viven en [../investigations/datos-y-metricas.md](../investigations/datos-y-metricas.md)).
- Motor de rating y matchmaking ([overview.md](overview.md)).
- Generación del `reconstruction.json` (upstream).
- Métricas tácticas (PPDA, line-breaking, packing) como entregable comprometido.

### 8.2 Trazabilidad

| Requisito | → AC | Notas |
|-----------|------|-------|
| FR-F1, NFR-D2 | AC #1 | Agnosticismo de cadencia. |
| FR-F2 | AC #2 | Helper `[0,1]`. |
| FR-F3 | — | Verificable al derivar SPADL (diferido). |
| FR-F4 | AC #11 | No-identificados; Abierto §7 #7. |
| FR-B1, NFR-D3 | AC #3 | Inmutabilidad. |
| FR-B2 | AC #4 | Silver antes de métrica. |
| FR-B3 | AC #1 | `frame_stride`/dimensiones preservados. |
| FR-S1…FR-S6, FR-S9 | AC #5 | Limpieza completa. |
| FR-S7 | AC #5 | Abierto §7 #1. |
| FR-S8 | AC #6 | Abierto §7 #2. |
| FR-V1, FR-V2, FR-V3 | AC #6, #10 | Degradación sintética de Metrica. |
| FR-G1 | AC #7 | Estructura direction-agnostic. |
| FR-G2, FR-G4 | AC #8 | Agregados servibles. |
| FR-G3 | — | Diferido (§8.1). |
| NFR-D1 | AC #8 | Parquet/Mongo. |
| NFR-D4 | AC #9 | Idempotencia. |
| NFR-D5 | — | Disciplina de citación en código. |
| NFR-D6 | — | VPS-only. |
| NFR-D7 | AC #10 | Honestidad de datos. |

---

## 9. Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-06-06 | Borrador inicial: capas, modelo `Frame`, validación sintética. |
| 0.2 | 2026-06-09 | Reescritura a spec formal (rúbrica): encabezado, FR/NFR con IDs, contratos, criterios de aceptación, open items, trazabilidad. |
| 0.3 | 2026-06-09 | Agrega FR-F4 (jugadores no-identificados) y AC #11; tabla de campos en §5.1; open item §7 #7; cross-refs a secciones exactas del spec upstream. |
