# workers-py — Analytics + rating (Python)

Workers offline de Sportify scoring: el **medallón de analytics** + el **update del rating**. Corren por partido en el VPS y escriben resultados en MongoDB. Ver [../docs/architecture.md](../docs/architecture.md) §3–4.

> **Lenguaje:** Python (el ecosistema de football analytics es Python-only — ver [ADR-005](../docs/decisions/log.md)).

## Estructura (modular por etapa del medallón)

```
src/sportify_scoring/
├── bronze/   # ingesta cruda: reconstruction.json + datos árbitro → modelo Frame
├── silver/   # limpieza: suavizado, interpolación, IDs, velocidades, equipo, validación
├── gold/     # features: métricas espaciales, pitch control, valor, dominancia
└── rating/   # OpenSkill: update del rating + reparto a jugadores
notebooks/    # exploración (empezamos acá: entender los datos)
tests/
```

Cada módulo tiene una frontera clara y es dueño de su etapa (disciplina del monolito modular, [ADR-007](../docs/decisions/log.md)).

## Entorno (pendiente de armar)

Python **3.12** (no 3.14 del sistema: las libs científicas pueden no tener wheels para 3.14). Recomendado con [uv](https://docs.astral.sh/uv/):

```bash
# instalar uv (una vez):           brew install uv
uv venv --python 3.12
uv pip install -e ".[dev]"
uv run jupyter lab        # para los notebooks de exploración
```

## Estado

⬜ Esqueleto creado. Primer trabajo: notebook de exploración + capa bronze (modelo `Frame`, loader de Metrica). Ver [../docs/roadmap.md](../docs/roadmap.md).
