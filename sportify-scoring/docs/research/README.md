# Research — Scoring & Matchmaking

Toda la información que fundamenta el sistema: la síntesis, las fuentes y los papers.

| Recurso | Qué es |
|---------|--------|
| [scoring-matchmaking.md](scoring-matchmaking.md) | **Síntesis consolidada** (fuente de verdad): estructura de datos, superficies de valor, rating de equipo, matchmaking con margen. Cada sección cita sus fuentes. |
| [references.md](references.md) | **Bibliografía** (fuente única de links): papers y fuentes de cada método, con su `id` para trazar (`[ref: pitch-control]`). |

> Los PDFs de los papers se mantienen **localmente** (fuera de git); los links viven en `references.md`.

## Cómo se usa la trazabilidad

1. Un método (ej. pitch control) se sintetiza en `scoring-matchmaking.md`.
2. Su fuente vive en `references.md` con un `id` (`pitch-control`) y su link.
3. Cuando se implementa, el issue/código cita ese `id` → de la línea de código al paper en dos saltos.

> Origen: deep-research harness (2026-05-28, 107 agentes, 24 claims verificados 3-0 adversarial) + síntesis dirigida. Borrador de trabajo en `_research-notes/` (local, fuera de git).
