# Referencias — papers y fuentes

Bibliografía del sistema de scoring & matchmaking. Cada método que usamos sale de acá. La síntesis está en [scoring-matchmaking.md](scoring-matchmaking.md); las decisiones que derivan de estas fuentes, en [../decisions/log.md](../decisions/log.md).

> 📄 **Copias locales de los PDFs:** [`papers/`](papers/) (9 papers descargados en el repo).

> Convención: cuando implementemos un método, el issue/código cita la entrada de esta lista (`[ref: pitch-control]`) para mantener la trazabilidad.

---

## Estructura de datos y herramientas

| id | Fuente | Qué nos da |
|----|--------|------------|
| `kloppy` | kloppy.pysport.org · [data-model](https://kloppy.pysport.org/) | Modelo de tracking vendor-independiente (`TrackingDataset`/`Frame`); parsers (Metrica, etc.) |
| `socceraction` | socceraction.readthedocs.io · [github.com/ML-KULeuven/socceraction](https://github.com/ML-KULeuven/socceraction) | SPADL / Atomic-SPADL, xT, VAEP / Atomic-VAEP |
| `metrica-data` | [github.com/metrica-sports/sample-data](https://github.com/metrica-sports/sample-data) | Datos de tracking + eventos abiertos (2 partidos) para desarrollo y validación |
| `friends-of-tracking` | [github.com/Friends-of-Tracking-Data-FoTD](https://github.com/Friends-of-Tracking-Data-FoTD) | Implementaciones de referencia (pitch control de Spearman, etc.) |

## Superficies de valor espacial

| id | Fuente | Qué nos da |
|----|--------|------------|
| `pitch-control` | Spearman et al., *Physics-Based Modeling of Pass Probabilities in Soccer*, MIT Sloan 2017 — [ResearchGate](https://www.researchgate.net/publication/315166647) · impl: [Friends of Tracking](https://github.com/Friends-of-Tracking-Data-FoTD) | Campo de probabilidad de control `[0,1]` por zona |
| `obso` | Spearman, *Beyond Expected Goals*, MIT Sloan 2018 — [sloansportsconference.com](https://www.sloansportsconference.com/) | Off-Ball Scoring Opportunity: `control × transición × score` |
| `wide-open-spaces` | Fernández & Bornn, *Wide Open Spaces*, MIT Sloan | Valor de espacio creado/ocupado, equipo y jugador, con y sin pelota |
| `epv` | Fernández, Bornn, Cervone, *Decomposing the Immeasurable Sport*, MIT Sloan | Patrón EPV: modular, descompuesto, interpretable sobre el estado espacio-temporal |

## Métricas tácticas (estructura, presión, líneas)

| id | Fuente | Qué nos da |
|----|--------|------------|
| `compactness` | [pmc.ncbi.nlm.nih.gov/articles/PMC8805357](https://pmc.ncbi.nlm.nih.gov/articles/PMC8805357) · [nature.com/articles/s41598-025-97765-y](https://www.nature.com/articles/s41598-025-97765-y) | Compactación: centroide, stretch index, surface area, length/width |
| `ppda-packing` | [the-footballanalyst.com](https://the-footballanalyst.com/) | PPDA (presión), packing rate |
| `line-breaking` | [arxiv.org/html/2506.06666v1](https://arxiv.org/html/2506.06666v1) | Line-breaking passes vía clustering de líneas defensivas |

## Rating y matchmaking

| id | Fuente | Qué nos da |
|----|--------|------------|
| `openskill` | Weng-Lin 2011 (Plackett-Luce) — [arxiv.org/html/2401.05451v1](https://arxiv.org/html/2401.05451v1) | Motor de rating multi-equipo/multi-jugador con `margin` y reparto. **Elegido como base.** |
| `glicko2` | [glicko.net/glicko/glicko2.pdf](http://www.glicko.net/glicko/glicko2.pdf) | Rating + incertidumbre (RD) + volatilidad; referencia para inactividad amateur |
| `elo-mov` | [andr3w321.com/elo-ratings-part-2](https://andr3w321.com/) | Multiplicador de margen + corrección de autocorrelación |
| `forecasting` | [sciencedirect.com/S0169207020300157](https://www.sciencedirect.com/science/article/pii/S0169207020300157) · arXiv 2010.11187 | Evaluación de sistemas de rating/forecasting |

## Contexto del pipeline (upstream — Valentín)

| id | Fuente | Qué nos da |
|----|--------|------------|
| `soccernet-gsr` | [arxiv.org/abs/2404.11335](https://arxiv.org/abs/2404.11335) | Game State Reconstruction: tarea y baseline que produce nuestro insumo per-frame |

---

## Otros proveedores relevados (no fuentes directas, contexto de estado del arte)

StatsBomb/Hudl (360, possession value) · SkillCorner ([off-ball runs](https://skillcorner.com/blog/off-ball-runs)) · Second Spectrum/Genius · PFF FC · Impect (packing) · Opta/Stats Perform · Metrica.
