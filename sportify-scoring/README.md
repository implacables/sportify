# Sportify — Scoring & Matchmaking

**Stage:** thesis — designing

Mide el skill de los jugadores desde el tracking del partido (analytics) y los empareja parejo (matchmaking). Sistema **separado** del POC de reconstrucción; consume su contrato per-frame. El aporte original: emparejar con **visión por computadora** en vez de evaluación subjetiva.

## Documentación

Organizada por **áreas** en [`docs/`](docs/index.md) — se navega directo en GitHub, carpeta por carpeta (área → tema → concepto).

| Área | Qué cubre |
|------|-----------|
| [Inicio](docs/index.md) | el mapa: dos ramas + el puente |
| [Datos](docs/datos/index.md) | el `Frame` + la limpieza (silver) |
| [Analytics](docs/analytics/index.md) | métricas espaciales, superficies de valor, dominancia |
| [Matchmaking](docs/matchmaking/index.md) | rating, el puente, emparejamiento |
| [Plataforma](docs/plataforma/index.md) | backend Go, workers, base de datos, identidad |

Además: [Decisiones (ADR)](docs/decisions/log.md) · [Research + papers](docs/research/README.md) · [Glosario](docs/glosario.md) · [Roadmap](docs/roadmap.md)

Reconstrucción (upstream): [`../sportify-game-reconstruction/`](../sportify-game-reconstruction/)

## Code

Backend Go (`backend-go/`) y workers Python (`workers-py/`) vivirán acá. Not started yet.
