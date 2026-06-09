# Sportify — Scoring & Matchmaking

Sistema de **scoring** (medir skill desde el tracking) y **matchmaking** (emparejar parejo) de Sportify. Es la **parte de tesis nuestra**, un sistema **separado** del POC de reconstrucción ([`sportify-game-reconstruction/`](../sportify-game-reconstruction/), de Valentín). Consume el contrato per-frame que produce la reconstrucción.

> **Estado:** diseño activo. Arquitectura y stack **decididos** (ver abajo). Alcance analítico y validación **en definición**.

## La idea en una imagen

```
🎥 video ─→ [reconstrucción: Valentín] ─→ reconstruction.json
📲 app árbitro ─→ tarjetas, goles, tiempo (lo que la visión no ve)
                          │
                          ▼
🌳 RAMA B — ANALYTICS (medallón: 🥉bronze → 🥈silver → 🥇gold)
   produce: SCORE DE DOMINANCIA + contribución por jugador
                          │
            (dominancia)  │──🌉──→ 🌳 RAMA A — MATCHMAKING
                          │          rating OpenSkill + margen → leaderboard
                          ▼                │
              📦 STORE (MongoDB) ◄─────────┘
                          │
                          ▼
              📱 APP MÓVIL  (leaderboard · perfil · cómo jugó el equipo)
```

**El puente** (meter dominancia derivada de analytics en el margen del rating, en vez de diferencia de goles) **es la contribución original de la tesis.**

## Stack

| Pieza | Tecnología | Rol |
|---|---|---|
| Backend | **Go** | API que sirve a la app (binario único, VPS-friendly) |
| Workers | **Python** | analytics (medallón) + update del rating |
| Base | **MongoDB** | única base NoSQL: identidad, ratings, partidos, reportes, leaderboard |
| Frames crudos | **parquet** (archivos) | bronze/silver — nunca en la base |

Arquitectura de código: **monolito modular → microservices-ready**.

## Estructura del repo

```
sportify-scoring/
└── docs/              # arquitectura, roadmap, decisiones (ADR), research
```

> **Código (próximamente):** `backend-go/` (API Go) y `workers-py/` (workers Python) se agregan en un PR aparte cuando arranque la construcción. La estructura de código planificada está en [docs/architecture.md](docs/architecture.md) §6.

## Docs

| Doc | Contenido |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Arquitectura y stack — todas las decisiones |
| [docs/roadmap.md](docs/roadmap.md) | Plan de construcción por ramas + medallón, con estado |
| [docs/decisions/log.md](docs/decisions/log.md) | Log de decisiones (ADR) — qué, por qué y de dónde salió cada una |
| [docs/research/scoring-matchmaking.md](docs/research/scoring-matchmaking.md) | Research consolidada (fuente de verdad) |
| [docs/research/references.md](docs/research/references.md) | Bibliografía — papers y fuentes de cada método |

## Estado

| | Estado |
|---|---|
| Arquitectura y stack | ✅ decidido |
| Research consolidada | ✅ |
| Alcance analítico / validación | 🟦 en definición |
| Código | ⬜ no empezado |

Detalle por bloque en [docs/roadmap.md](docs/roadmap.md).

## Relacionados

- Research consolidada (local, sin commitear): `../_research-notes/scoring-and-matchmaking-research.md`
- Etapas de producto: [`../docs/product-stages.md`](../docs/product-stages.md)
- Contrato de reconstrucción: [`../sportify-game-reconstruction/docs/spec/overview.md`](../sportify-game-reconstruction/docs/spec/overview.md) §5
