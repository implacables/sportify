# Roadmap — Scoring & Matchmaking

Plan de construcción. Estructurado por las **dos ramas** (ver [architecture.md](architecture.md) §2) sobre la **columna del medallón** (§3). Cada bloque se romperá en issues de GitHub trazables a [research/references.md](research/references.md).

> **Leyenda de estado:** ⬜ no empezado · 🟦 en progreso · ✅ hecho

---

## Estado general

| | Estado |
|---|---|
| Arquitectura y stack | ✅ decidido ([architecture.md](architecture.md)) |
| Research consolidada | ✅ ([research/](research/)) |
| Alcance analítico / validación | 🟦 en definición ([architecture.md](architecture.md) §9) |
| Código | ⬜ no empezado |

---

## Columna de datos — Medallón

| Capa | Qué entrega | Estado |
|------|-------------|--------|
| 🥉 **Bronze** | ingesta cruda (`reconstruction.json` + datos árbitro), modelo `Frame`, loaders, fixtures | ⬜ |
| 🥈 **Silver** | limpieza: suavizado, interpolación, IDs, velocidades, equipo, validación de calidad | ⬜ |
| 🥇 **Gold** | features (ver ramas abajo) | ⬜ |

**Silver es prerrequisito de todas las métricas.** Validación: degradar Metrica a calidad amateur sintética.

---

## 🌳 Rama B — Analytics (gold)

Dependencias reales; arranca por lo robusto (direction-agnostic) [ref: `compactness`].

| # | Bloque | Depende de | Robustez | Estado |
|---|--------|-----------|----------|--------|
| B1 | Métricas espaciales directas (centroide, stretch, convex hull, EPS) | silver | 🟢 alta | ⬜ |
| B2 | Agregación per-frame → por partido (series temporales) | B1 | 🟢 | ⬜ |
| B3 | Capa de eventos derivados (SPADL desde tracking) [ref: `socceraction`] | silver | 🟡 | ⬜ |
| B4 | Métricas con eventos (PPDA, packing, line-breaking) [ref: `ppda-packing`,`line-breaking`] | B3 | 🟡 | ⬜ |
| B5 | Pitch control [ref: `pitch-control`] | silver (velocidades) | 🟡 | ⬜ |
| B6 | OBSO + valor de posesión (xT, VAEP/EPV) [ref: `obso`,`epv`,`socceraction`] | B3, B5 | 🟡 | ⬜ |
| B7 | **Score de dominancia** (ΔxG, Δpitch-control, ΔEPV, Δfield-tilt) | B5, B6 | 🟡 | ⬜ |

> ⚠️ B3/B4/B6 dependen de **eventos derivados** → choca con "scoring v1 sin event detection". Frontera **a definir** ([architecture.md](architecture.md) §9).

## 🌳 Rama A — Matchmaking (la base)

Funciona sola con una señal simple; el puente la mejora.

| # | Bloque | Depende de | Estado |
|---|--------|-----------|--------|
| A1 | Motor de rating OpenSkill (Plackett-Luce) [ref: `openskill`] | — | ⬜ |
| A2 | Update por margen [ref: `elo-mov`,`openskill`] | A1 | ⬜ |
| A3 | Reparto a jugadores (partial-play por contribución) | A2, B7 | ⬜ |
| A4 | Emparejamiento on-demand | A1 | ⬜ |

## 🌉 El puente (contribución de tesis)

| # | Bloque | Depende de | Estado |
|---|--------|-----------|--------|
| P1 | Alimentar el margen del rating con la dominancia (no goles) | A2, B7 | ⬜ |
| P2 | Calibración de pesos `w1..w4` | P1 | ⬜ |

---

## Plataforma (transversal)

| # | Bloque | Estado |
|---|--------|--------|
| INFRA1 | Backend Go (esqueleto modular: identidad, partidos, ratings, matchmaking, analytics) | ⬜ |
| INFRA2 | Workers Python (esqueleto del medallón) | ⬜ |
| INFRA3 | MongoDB (colecciones + índices) | ⬜ |
| INFRA4 | Contrato con reconstrucción (2 gaps: pelota, no-identificados) — coordinar con Valentín | ⬜ |
| INFRA5 | App móvil: migración de Supabase al backend Go | ⬜ |

---

## Orden sugerido (a confirmar)

1. **Fundaciones**: entorno + bronze (modelo `Frame`, loader Metrica, fixtures) + notebook de exploración.
2. **Silver** (limpieza) + su validación sintética.
3. **B1–B2** (métricas espaciales robustas) — primer valor analítico.
4. En paralelo, **A1–A4** (matchmaking base) — sistema que ya anda.
5. **B5–B7** + **el puente** — la tesis.
6. Resto de la rama B (eventos) según la frontera que definamos.
