# Arquitectura — Scoring & Matchmaking

**Estado:** decisiones tomadas el 2026-06-09 (sesión de diseño). Documento vivo.
**Alcance:** este doc cubre **arquitectura y stack**. El alcance analítico (qué métricas, qué outputs) y la validación están **en definición** (ver §9).

---

## 1. Encuadre

El proyecto-tesis tiene tres sistemas:

1. **Reconstrucción** — POC de Valentín (`sportify-game-reconstruction/`). Ya tiene spec, benchmarks y contrato de salida.
2. **Scoring** — *nuestro*, tesis. Mide skill desde el tracking.
3. **Matchmaking** — *nuestro*, tesis. Empareja parejo.

Scoring + matchmaking son **un sistema separado** que consume el contrato per-frame de la reconstrucción. Este doc es sobre ese sistema.

---

## 2. Dos ramas + un puente

El sistema se piensa como **dos ramas que se complementan**, no como una cadena lineal:

- **Rama A — Matchmaking** (la base / núcleo del producto): rating de equipos y jugadores (OpenSkill / Plackett-Luce) + update por margen → leaderboard + emparejamiento on-demand. **Funciona sola**, con una señal de entrada simple (incluso goles).
- **Rama B — Analytics** (el medallón): procesa el tracking del partido y produce un **score de dominancia** + contribución por jugador.

**🌉 El puente = la contribución original de la tesis:** alimentar el *margen* del rating con el **score de dominancia derivado de analytics** en vez de la diferencia de goles (ruidosa en amateur). Un equipo que mereció ganar sube fuerte aunque sea 1-0; una goleada con suerte no infla tanto.

Las dos ramas están **desacopladas** por una interfaz clara (el score de dominancia), así que se pueden construir en paralelo o matchmaking primero.

---

## 3. Arquitectura de datos — Medallón

Tres **estados del mismo dato** (capas **lógicas**, no infraestructura de lakehouse):

| Capa | Qué es | Contenido |
|---|---|---|
| 🥉 **Bronze** | crudo, inmutable, "lo que llegó" | `reconstruction.json` tal cual + datos del árbitro. Posiciones crudas, IDs parciales, ruido, huecos. |
| 🥈 **Silver** | limpio y conforme | suavizado de trayectorias, interpolación de oclusiones, continuidad de IDs, remoción de outliers, normalización a metros-venue, **derivación de velocidades**, asignación de equipo, normalización de frame-stride, validación de calidad. |
| 🥇 **Gold** | features listas | métricas espaciales, superficies de valor, dominancia, agregados por partido/jugador/equipo. |

**Silver (la limpieza) es una etapa propia ANTES de cualquier métrica.** Ahí vive el mayor riesgo de la tesis: la robustez al tracking amateur ruidoso/parcial.

**Validación de la limpieza:** como no hay tracking amateur real todavía, se **degrada** tracking limpio (Metrica) a calidad amateur de forma sintética (ruido, huecos, ID-switches) y se verifica que silver lo recupera.

**Persistencia:** bronze/silver (per-frame, pesado) → **parquet en archivos**. Gold servible (agregados) → **MongoDB**.

---

## 4. Stack

```
📱 APP (React Native)
        │  habla SOLO con Go
        ▼
🟦 BACKEND Go  ── API · auth · identidad · rosters · leaderboard
        │           ciclo de vida del partido · pedir matchmaking · servir reportes
        ▼
🟩 MongoDB  ── identidad, ratings, partidos, reportes, leaderboard
        ▲   📄 parquet ── frames crudos (bronze/silver)
        │  escribe resultados
🐍 WORKERS Python ── medallón analytics · update del rating
        (offline, por partido, en el VPS)
```

| Pieza | Tecnología | Por qué |
|---|---|---|
| **Backend** | Go | Binario único sin runtime → ideal VPS. Rápido, concurrente. La app habla solo con esto. |
| **Workers** | Python | El ecosistema de football analytics es Python-only (kloppy, socceraction/SPADL/VAEP, pitch control). No negociable. |
| **Base** | MongoDB | Única base, NoSQL. Ver §5. |
| **Frames crudos** | parquet | Miles de frames × jugadores reventarían la base. Van a archivos. |

**Go sirve; Python procesa. Se encuentran en el store** (no se hablan directo).

**Matchmaking se parte en dos:**
- *Update del rating* (post-partido, consume la dominancia) → **worker Python**, escribe ratings en Mongo.
- *Pedir emparejamiento* (on-demand) → **Go** (request-response).

---

## 5. Base de datos — MongoDB sola (NoSQL)

Decisión: **todo NoSQL, una sola base (MongoDB).**

- Mongo es **base principal**: persiste en disco, documentos, indexa, agrega.
- A escala amateur/tesis, Mongo **cubre solo** lo que haría Redis:
  - leaderboard → `sort({rating:-1})` con índice; puesto → `countDocuments`.
  - realtime → **Change Streams**.
  - caché → working-set en RAM de Mongo (+ caché en Go si hace falta).
  - cola de jobs → colección `jobs` con estado, o Go orquesta directo.
- **Redis es un add-on futuro** (sorted sets para leaderboard, pub/sub para realtime) si algún día la escala lo pide. No ahora (YAGNI).

**Modelado (clave para que NoSQL salga bien):** modelar por **patrón de acceso**, no por normalización. Embeber lo que se lee junto; referenciar lo compartido/grande; denormalizar a propósito; updates atómicos por documento (el rating vive en el doc del `user`); many-to-many vía colección de unión.

**Colecciones (boceto):**

| Colección | Guarda |
|---|---|
| `users` | perfil + rating actual (embebido) |
| `teams` | refs a usuarios |
| `matches` | metadata + estado del partido |
| `match_participations` | user × match × team × stats del jugador (el "join") |
| `analytics_reports` | un documento por partido (el "cómo jugó el equipo") |

---

## 6. Arquitectura de código — Monolito modular

**Monolito ahora, divisible después** (modular monolith → microservices-ready). NO microservicios todavía (complejidad prematura).

- **Backend Go = un servicio**, modular por dominio: `identidad/`, `partidos/`, `ratings/`, `matchmaking/`, `analytics/`.
- **Workers Python = un pipeline**, modular por etapa del medallón: `bronze/`, `silver/`, `gold/`, `rating/`.
- *(Go-backend + Python-workers ya son dos procesos, pero eso es el patrón normal "app + worker", no microservicios.)*

**Disciplina que hace real el "divisible después":**
1. Cada módulo **es dueño de sus datos** — no toca las colecciones de otro; pasa por su interfaz.
2. Los módulos se hablan **por interfaces**, no metiéndose en las tripas del otro.
3. Fronteras por **capacidad de negocio** (= cómo después se parte en servicios).

---

## 7. Identidad

`user_id` que está **registrado o no**:
- **Registrado** → cuenta, perfil, rating, leaderboard.
- **No registrado (invitado)** → slot en el roster sin cuenta; rating "en la sombra" que se **activa y reclama** cuando se registra.

Conecta con el cold-start del rating y con el roster del contrato de reconstrucción.

---

## 8. Coordenadas y contrato con reconstrucción

- **Coordenadas canónicas internas:** **metros** usando las **dimensiones reales del venue** (las canchas amateur varían: fútbol 5/7/11). Helper a `[0,1]` on-demand. Las velocidades físicas (que necesita pitch control) salen de acá.
- **Módulo `Pitch` configurable** desde venue data (dims + origen), independiente de la homografía (la homografía es de Valentín y produce nuestras coordenadas; nosotros consumimos el resultado en metros).
- **Gaps a pedirle al contrato de Valentín (2):**
  1. **Posición de la pelota** por frame.
  2. **Jugadores no-identificados** con posición (no omitirlos).
  - *(La dirección de ataque se descartó: no es confiable determinarla, y las métricas espaciales robustas son direction-agnostic.)*

---

## 9. Decidido vs. abierto

**✅ Decidido:** dos ramas + puente · medallón · stack (Go + Python + Mongo + parquet) · Mongo sola NoSQL · monolito modular · coordenadas metros-venue · modelo de identidad · 2 gaps del contrato.

**🟡 Abierto (a definir):**
- **Alcance / entregable mínimo** de la tesis y la **salida de scoring** (nuestro `scoring.json`).
- **Tensión eventos vs no-eventos:** VAEP/xT/PPDA necesitan eventos derivados, pero producto dice "scoring v1 sin event detection". Definir la frontera.
- **Validación** sin ground-truth de skill real amateur.
- **Calibración** de los pesos de dominancia (`w1..w4`).
- **Profundidad** de cada capa analítica (impl. propia vs librería vs simplificada).
