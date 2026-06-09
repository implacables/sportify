# Sportify — Scoring & Matchmaking

**Stage:** thesis — designing

Mide el skill de los jugadores desde el tracking del partido (analytics) y los empareja parejo (matchmaking). Sistema **separado** del POC de reconstrucción; consume su contrato per-frame. El aporte original: emparejar con **visión por computadora** en vez de evaluación subjetiva.

## Docs

| Document | Description |
|----------|-------------|
| [docs/overview.md](docs/overview.md) | Big picture: dos ramas + puente, stack, estado |
| [docs/spec/overview.md](docs/spec/overview.md) | Arquitectura: stack, módulos, base de datos |
| [docs/spec/contratos.md](docs/spec/contratos.md) | Contratos de entrada/salida |
| [docs/spec/datos-medallon.md](docs/spec/datos-medallon.md) | Capas de datos (bronze/silver/gold) |
| [docs/investigations/](docs/investigations/) | Temas factuales: datos, valor, rating |
| [docs/decisions/log.md](docs/decisions/log.md) | Decisiones (ADR) |
| [docs/research/](docs/research/) | Research + papers por tema |
| [docs/glosario.md](docs/glosario.md) | Términos |
| [docs/roadmap.md](docs/roadmap.md) | Plan + estado |

Product context: [../docs/overview.md](../docs/overview.md) · Reconstrucción: [../sportify-game-reconstruction/](../sportify-game-reconstruction/)

## Code

Backend Go (`backend-go/`) y workers Python (`workers-py/`) vivirán acá. Estructura planificada en [docs/spec/overview.md](docs/spec/overview.md). Not started yet.
