# Especificación — Arquitectura del sistema

**Status:** Decisiones tomadas
**Version:** 0.5
**Last updated:** 2026-06-09
**Stage:** Thesis scope

Define la arquitectura técnica de `sportify-scoring`: stack, monolito modular y sus módulos, flujo de datos Go↔store↔workers, persistencia, identidad y requisitos no-funcionales. La parte **normativa** vive acá; el porqué de cada elección, en los ADR. Los esquemas de entrada/salida y las capas de datos se especifican aparte y se referencian, **no** se duplican.

> **Cross-refs:** [contratos.md](contratos.md) (entrada/salida) · [datos-medallon.md](datos-medallon.md) (capas de datos) · [../overview.md](../overview.md) (las dos ramas + el puente) · [../decisions/log.md](../decisions/log.md) (ADRs) · [spec upstream — reconstrucción](../../../sportify-game-reconstruction/docs/spec/overview.md).

---

## 1. Propósito y alcance

Este sistema mide el skill de jugadores amateur desde el tracking del partido (analytics) y los empareja parejo (matchmaking), sirviendo el resultado a una app móvil. Es un sistema **separado** del POC de reconstrucción; lo consume vía contrato per-frame [ADR-001].

Esta spec define **cómo se estructura el software**: qué piezas hay, cómo se comunican y dónde vive cada dato. **No** define el método analítico (qué métricas, qué fórmula de rating) ni los esquemas exactos de datos; eso vive en [contratos.md](contratos.md), [datos-medallon.md](datos-medallon.md) y las investigaciones.

**Condición de éxito:** la app móvil habla con un solo backend, que sirve leaderboard/perfil/reporte desde el store; los workers procesan el tracking y escriben al store sin que la app los toque nunca directamente.

---

## 2. Contexto y definiciones

| Término | Significado |
|---------|-------------|
| **Backend** | Servicio Go que sirve la app móvil. Única superficie pública de la plataforma. |
| **Worker** | Proceso Python que ejecuta una etapa del pipeline (medallón o rating). No expone API a la app. |
| **Store** | MongoDB. Punto de encuentro entre Go y Python; ninguno llama al otro por red [ADR-006]. |
| **Módulo** | Unidad interna del monolito, dueña de sus datos, expuesta por interfaz; candidata a extraerse como servicio [ADR-007]. |
| **Medallón** | Capas lógicas bronze→silver→gold del dato analítico [ADR-003]; ver [datos-medallon.md](datos-medallon.md). |
| **Rama A — Matchmaking** | Rating OpenSkill + emparejamiento. Funciona sola con señal simple. |
| **Rama B — Analytics** | El medallón; produce el score de dominancia y contribución por jugador. |
| **Puente (dominancia)** | La dominancia derivada de analytics alimenta el `margin` del rating, en vez de la diferencia de goles. Contribución de la tesis [ADR-002] [ref: `openskill`, `epv`]. |
| **`reconstruction.json`** | Artefacto per-frame de entrada que produce el pipeline upstream. |
| **`scoring.json`** | Artefacto de salida de la rama de analytics (esquema 🟡 abierto — ver §7 #1). |
| **Frame** | Modelo canónico interno: `timestamp` + `ball` + `players[]` en metros del venue [ADR-008]. |
| **SPADL** | Representación unificada de acciones on-ball; insumo de los modelos de valor (xT/VAEP) [ref: `socceraction`]. |
| **Registrado** | `user_id` con cuenta, perfil, rating y presencia en leaderboard. |
| **Invitado** | `user_id` con slot en el roster sin cuenta; rating "en la sombra" reclamable al registrarse. |
| **VPS** | Servidor único auto-hosteado; sin egress a cloud. |

---

## 3. Requisitos funcionales

### 3.1 Stack y separación de planos

| ID | Requisito |
|----|-----------|
| **FR-S1** | El sistema **deberá** servir a la app móvil desde un único backend en Go (binario único, VPS-friendly) [ADR-004]. |
| **FR-S2** | El procesamiento analítico (medallón) y el update del rating **deberán** correr en workers Python [ADR-005] [ref: `kloppy`, `socceraction`, `friends-of-tracking`]. |
| **FR-S3** | La app móvil **deberá** comunicarse **solo** con el backend Go; **no** hablará con los workers ni con el store directamente. |
| **FR-S4** | Go y Python **no** se llamarán entre sí por red; se coordinan **a través del store** (Mongo + parquet). |
| **FR-S5** | El emparejamiento on-demand **deberá** resolverse en Go; el update del rating, en el worker Python. |

### 3.2 Arquitectura de código — monolito modular

Monolito ahora, **divisible después** (microservices-ready); no microservicios todavía [ADR-007].

| ID | Requisito |
|----|-----------|
| **FR-C1** | El backend Go **deberá** ser un único servicio, modular por dominio: `identidad`, `partidos`, `ratings`, `matchmaking`, `analytics`. |
| **FR-C2** | Los workers Python **deberán** ser un único pipeline, modular por etapa del medallón: `bronze`, `silver`, `gold`, `rating`. |
| **FR-C3** | Cada módulo **deberá** ser dueño de sus datos y exponerse por interfaz; **no** tocará las colecciones de otro módulo. |
| **FR-C4** | Las fronteras entre módulos **deberán** mantenerse limpias para permitir extraer un módulo como servicio sin reescribir su contrato. |

### 3.3 Ramas y puente

| ID | Requisito |
|----|-----------|
| **FR-B1** | Matchmaking (Rama A) y Analytics (Rama B) **deberán** poder construirse y operar desacoplados [ADR-002]. |
| **FR-B2** | Matchmaking **deberá** funcionar de forma autónoma con una señal de margen simple desde el día 1, sin depender de que analytics esté listo. |
| **FR-B3** | El puente **deberá** alimentar el `margin` del rating con la dominancia derivada de analytics, **no** con la diferencia de goles [ref: `openskill`]. |

### 3.4 Persistencia

| ID | Requisito |
|----|-----------|
| **FR-D1** | El sistema **deberá** usar una única base NoSQL (MongoDB) como system-of-record para identidad, ratings, partidos, reportes y leaderboard [ADR-006]. |
| **FR-D2** | Los frames crudos (bronze) y el dato limpio (silver) **deberán** persistirse como archivos **parquet**, **nunca** en la base [ADR-003] [ADR-006]. |
| **FR-D3** | Solo la capa gold (lo servible: métricas, dominancia, agregados) **deberá** persistirse en MongoDB; ver [datos-medallon.md](datos-medallon.md). |
| **FR-D4** | El modelado de colecciones **deberá** hacerse por patrón de acceso (embeber lo que se lee junto, referenciar lo compartido), no por normalización. |
| **FR-D5** | El rating de un usuario **deberá** vivir en su documento `user` para permitir update atómico por documento. |
| **FR-D6** | Las relaciones many-to-many (usuario × partido × equipo) **deberán** modelarse vía colección de unión. |

Colecciones (gold + operacional):

| Colección | Guarda |
|-----------|--------|
| `users` | perfil + rating actual |
| `teams` | refs a usuarios |
| `matches` | metadata + estado del partido |
| `match_participations` | user × match × team × stats (el "join") |
| `analytics_reports` | un documento por partido |

> Redis es un add-on futuro si la escala lo pide (YAGNI) [ADR-006]. A escala amateur/tesis Mongo cubre leaderboard (`sort`+índice), realtime (change streams) y jobs (colección).

### 3.5 Identidad

| ID | Requisito |
|----|-----------|
| **FR-I1** | Todo participante de un partido **deberá** identificarse con un `user_id`, sea **registrado** o **invitado**. |
| **FR-I2** | Un usuario registrado **deberá** tener cuenta, perfil, rating y presencia en leaderboard. |
| **FR-I3** | Un invitado **deberá** ocupar un slot en el roster sin cuenta, con un rating "en la sombra". |
| **FR-I4** | El rating en la sombra de un invitado **deberá** activarse y poder reclamarse cuando ese usuario se registra. |

### 3.6 Coordinación Go↔store↔workers

| ID | Requisito |
|----|-----------|
| **FR-F1** | Go **deberá** servir; los workers Python **deberán** procesar; ambos se encuentran en el store. |
| **FR-F2** | El backend Go **deberá** registrar el trabajo a procesar (p. ej. una colección de jobs en Mongo) y los workers **deberán** consumirlo desde ahí. |
| **FR-F3** | Los workers **deberán** escribir resultados servibles (gold) en MongoDB y artefactos crudos/limpios en parquet, sin notificar a Go por red. |
| **FR-F4** | El backend **puede** observar cambios de estado vía change streams de Mongo en lugar de polling. (Mecanismo exacto — 🟡 abierto: ver §7 #2.) |

---

## 4. Requisitos no-funcionales

| ID | Requisito |
|----|-----------|
| **NFR-1** | **VPS-only:** todo el I/O **deberá** ocurrir en storage local o adjunto al VPS — sin egress a cloud. |
| **NFR-2** | **Binario único:** el backend Go **deberá** desplegarse como binario sin runtime externo [ADR-004]. |
| **NFR-3** | **Aislamiento de datos:** ningún módulo **deberá** leer/escribir colecciones de otro módulo (dueño único por dato). |
| **NFR-4** | **Una fuente de verdad:** un dato normativo se define en una sola colección/capa; el resto lo referencia. |
| **NFR-5** | **Idempotencia:** el reprocesamiento del medallón **deberá** poder rehacerse desde bronze sin molestar a upstream [ADR-003]. |
| **NFR-6** | **Atomicidad:** los updates de rating **deberán** ser atómicos a nivel de documento `user` (FR-D5). |
| **NFR-7** | **Observabilidad:** los workers **deberían** loguear etapa, partido/job y resultado para trazabilidad de tesis. (Detalle — 🟡 abierto: ver §7 #4.) |
| **NFR-8** | **Honestidad de demo/datos:** sin tracking amateur real todavía, la validación de la limpieza **deberá** degradar tracking limpio (Metrica) a calidad amateur sintética y verificar que silver lo recupera [ref: `metrica-data`]; ver [datos-medallon.md](datos-medallon.md). |
| **NFR-9** | **Microservices-ready:** la arquitectura **deberá** preservar fronteras que permitan extraer servicios sin reescritura de contratos (FR-C4) [ADR-007]. |

---

## 5. Interfaces / contratos

Los esquemas de campo se definen en [contratos.md](contratos.md); acá se fija la **topología** de interfaces entre planos.

### 5.1 Entrada — `reconstruction.json` (upstream → bronze)

Serie temporal per-frame del pipeline de reconstrucción ([spec upstream](../../../sportify-game-reconstruction/docs/spec/overview.md) §5). Entra a bronze tal cual, junto con los datos del árbitro.

Gaps que se le piden al upstream (definidos en [contratos.md](contratos.md)):

| Gap | Por qué |
|-----|---------|
| Posición de la pelota por frame | sin pelota no hay SPADL ni valor on-ball [ref: `socceraction`, `obso`]. |
| Jugadores no-identificados con posición | las métricas de equipo necesitan los 11 aunque no estén identificados [ref: `compactness`, `pitch-control`]. |

> La **dirección de ataque** **no** se pide al contrato [ADR-009]. Las dimensiones del venue viven en el `job.meta.json` upstream.

### 5.2 Estado interno — Frame canónico (silver)

Modelo `Frame` interno: `timestamp` + `ball` (Point3D) + `players[]` (posición en metros del venue, equipo, id, velocidad derivada), agnóstico al `frame_stride` [ADR-008]. Esquema en [datos-medallon.md](datos-medallon.md) §"Modelo `Frame`".

### 5.3 Frontera Go↔store↔workers

```yaml
# illustrative — topología, no esquema normativo
app_movil  --> backend_go            # única superficie pública (FR-S3)
backend_go --> mongo.jobs            # encola trabajo (FR-F2)
workers_py <-- mongo.jobs            # consumen
workers_py --> parquet (bronze/silver)   # crudo + limpio (FR-D2)
workers_py --> mongo (gold)              # servible (FR-D3)
backend_go <-- mongo (change streams)    # observa estado (FR-F4)
```

### 5.4 Salida — `scoring.json` (analytics → matchmaking + app)

Artefacto que produce la rama de analytics; mínimo: score de dominancia del partido + contribución por jugador. Es el insumo del rating y del reporte de la app.

> 🟡 Abierto: el esquema exacto de `scoring.json` está sin definir — ver §7 #1 y [contratos.md](contratos.md).

---

## 6. Criterios de aceptación

1. La app móvil obtiene leaderboard, perfil y reporte llamando **solo** al backend Go; no existe ningún path en que la app contacte workers o el store directamente (FR-S1, FR-S3).
2. Un partido procesado deja bronze y silver como archivos parquet en el VPS y gold en MongoDB; ningún frame crudo aparece en la base (FR-D2, FR-D3, NFR-1).
3. Go encola un job y un worker Python lo consume desde el store sin que exista una llamada de red directa Go→Python ni Python→Go (FR-S4, FR-F1, FR-F2).
4. El emparejamiento devuelve resultado en Go on-demand; el update del rating ocurre en el worker Python (FR-S5).
5. El backend Go corre como binario único en el VPS sin runtime adicional (FR-S2, NFR-2).
6. Matchmaking produce y sirve un rating con margen simple aunque la rama de analytics no esté implementada todavía (FR-B1, FR-B2).
7. El bridge usa dominancia (no diferencia de goles) como `margin` cuando analytics está disponible (FR-B3).
8. Un invitado puede ocupar slot en un roster, acumular rating en la sombra, y reclamarlo al registrarse, conservando el historial (FR-I1, FR-I3, FR-I4).
9. El update de rating de un usuario es atómico a nivel de su documento `user` (FR-D5, NFR-6).
10. El medallón se puede reprocesar desde bronze produciendo el mismo gold, sin tocar al upstream (NFR-5).
11. Un intento de un módulo de leer/escribir una colección de otro módulo se considera violación de arquitectura (FR-C3, NFR-3).

---

## 7. Open design items

| # | Topic | Notes |
|---|-------|-------|
| 1 | Esquema de `scoring.json` | Campos exactos del score de dominancia + contribución por jugador (§5.4, [contratos.md](contratos.md)). |
| 2 | Mecanismo job/coordinación | Colección de jobs vs change streams vs ambos; forma exacta del descriptor de job (FR-F2, FR-F4). |
| 3 | Portar partes a Go | Mover a Go piezas estables del worker (geometría, rating) más adelante; mantener VAEP/xT en Python [ADR-005]. |
| 4 | Detalle de observabilidad | Qué se loguea por etapa, formato y retención (NFR-7). |
| 5 | Origen de coordenadas del venue | Convención (centro vs esquina) heredada del upstream [ADR-008]; documentar en schema de venue. |
| 6 | Schema de colecciones | Forma exacta de `users`, `matches`, `match_participations`, `analytics_reports` (índices, embebido vs ref). |
| 7 | Reclamo de invitado → registrado | Flujo de merge de identidad y rating en la sombra (FR-I4). |

---

## 8. Trazabilidad y scope por etapa

### 8.1 Scope por product stage

| Stage | ¿En este spec? |
|-------|----------------|
| **POC** — reconstrucción | **No** — sistema separado upstream; se consume vía contrato (§5.1) [ADR-001]. |
| **Thesis scope** — scoring + matchmaking | **Sí** — esta es la arquitectura del sistema (§1–7). |
| **Deferred** — event detection | **No** — sin enfoque viable; scoring v1 debe andar sin eventos. |
| **Production** — microservicios, Redis, multi-VPS | **No** — la arquitectura los habilita (FR-C4, NFR-9) pero no los implementa. |

**Out of scope (esta spec):**

- El método analítico concreto (qué métricas, qué fórmula de rating) — investigaciones.
- El esquema exacto de `scoring.json` y de las colecciones — §7 #1, #6, [contratos.md](contratos.md).
- El pipeline de reconstrucción upstream y su deploy — repo separado [ADR-001].
- La app móvil (UI) y el referee app — productos aparte.
- Microservicios, Redis, object storage/cloud — diferidos [ADR-006] [ADR-007].

### 8.2 Trazabilidad

| Requisito | Origen | Verifica |
|-----------|--------|----------|
| FR-S1, FR-S3 | ADR-004 | AC #1 |
| FR-S2, NFR-2 | ADR-004, ADR-005 | AC #5 |
| FR-S4, FR-F1, FR-F2 | ADR-006, ADR-007 | AC #3 |
| FR-S5 | ADR-002 | AC #4 |
| FR-C1–FR-C4, NFR-3, NFR-9 | ADR-007 | AC #11 |
| FR-B1, FR-B2 | ADR-002 | AC #6 |
| FR-B3 | ADR-002 [ref: `openskill`] | AC #7 |
| FR-D2, FR-D3 | ADR-003, ADR-006 | AC #2 |
| FR-D5, NFR-6 | ADR-006 | AC #9 |
| FR-I1, FR-I2, FR-I3, FR-I4 | diseño de identidad | AC #8 |
| NFR-1 | ADR-006 | AC #2 |
| NFR-5 | ADR-003 | AC #10 |
| NFR-8 | ADR-003 [ref: `metrica-data`] | (validación de limpieza — [datos-medallon.md](datos-medallon.md)) |

> Cada requisito traza a ≥1 criterio de aceptación o a una validación documentada en una spec hermana. NFR-4, NFR-7, FR-D1, FR-D4, FR-D6, FR-F3, FR-F4 son restricciones estructurales verificadas por inspección de diseño, no por corrida única.

---

## 9. Document history

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-06-09 | Notas iniciales de arquitectura (stack, monolito modular, Mongo, identidad). |
| 0.4 | 2026-06-09 | Reescritura formal según rúbrica de specs: secciones numeradas, IDs FR-/NFR-, contratos/interfaces, criterios de aceptación, open items, trazabilidad a ADRs y research. |
| 0.5 | 2026-06-09 | Síntesis y conformance pass: definido `SPADL` en §2; FR-I2 agregado a la trazabilidad (§8.2) para no dejar requisitos huérfanos. |
