# Sportify

Amateur football platform — **POC** challenges [SoccerNet Game State Reconstruction](https://arxiv.org/abs/2404.11335) on reconstruction **throughput and cost**, not broadcast-grade accuracy.

## Start here

| Doc | Purpose |
|-----|---------|
| [docs/product-stages.md](docs/product-stages.md) | POC vs thesis scope vs deferred |
| [docs/overview.md](docs/overview.md) | Product overview |
| [docs/repo-structure.md](docs/repo-structure.md) | Monorepo layout |

## Repository layout

```
sportify/
├── docs/                           # Product + thesis docs, VPS plans
├── benchmarks/                     # SoccerNet GSR baseline + throughput harness
└── sportify-game-reconstruction/   # Reconstruction pipeline (POC subsystem)
```

| Path | Contents |
|------|----------|
| [`docs/`](docs/) | Product spec, hardware notes, execution plans |
| [`benchmarks/`](benchmarks/) | Official GSR baseline reproduction + Sportify throughput benchmarks |
| [`sportify-game-reconstruction/`](sportify-game-reconstruction/) | Pipeline docs and (future) worker code |

**VPS benchmark:** [docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md](docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md)

## Legacy repositories

Development moved here from:

- [implacables/sportify-legacy](https://github.com/implacables/sportify-legacy)
- [implacables/sportify-game-reconstruction-legacy](https://github.com/implacables/sportify-game-reconstruction-legacy)

## Data (not in git)

Set `SPORTIFY_DATA_ROOT` (default `~/data/sportify`) for SoccerNet-GS, vendor baselines, and match video. See [benchmarks/README.md](benchmarks/README.md).
