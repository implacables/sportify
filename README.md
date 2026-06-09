# Sportify

Amateur football platform — **POC** challenges [SoccerNet Game State Reconstruction](https://arxiv.org/abs/2404.11335) on reconstruction **throughput and cost**, not broadcast-grade accuracy.

## Start here

| Doc | Purpose |
|-----|---------|
| [docs/product-stages.md](docs/product-stages.md) | POC vs thesis scope vs deferred |
| [docs/overview.md](docs/overview.md) | Product overview |
| [docs/repo-structure.md](docs/repo-structure.md) | Monorepo layout |
| [sportify-scoring/README.md](sportify-scoring/README.md) | Scoring + matchmaking (thesis subsystem) |

## Repository layout

```
sportify/
├── docs/                           # Product + thesis docs, VPS plans
├── scripts/                        # Shared tooling
├── sportify-game-reconstruction/   # Reconstruction pipeline (POC subsystem)
│   ├── benchmarks/                 # SoccerNet GSR baseline + throughput harness
│   └── experiments/                # Exploratory research
└── sportify-scoring/               # Scoring & matchmaking (thesis subsystem)
    └── docs/                       # Architecture, roadmap, decisions, research
```

| Path | Contents |
|------|----------|
| [`docs/`](docs/) | Product spec, hardware notes, execution plans |
| [`sportify-game-reconstruction/`](sportify-game-reconstruction/) | Pipeline docs and (future) worker code |
| [`sportify-game-reconstruction/benchmarks/`](sportify-game-reconstruction/benchmarks/) | Official GSR baseline reproduction + Sportify throughput benchmarks |
| [`sportify-scoring/`](sportify-scoring/) | Scoring + matchmaking system: architecture, decisions, and research (code scaffold lands in a later PR) |

**VPS benchmark:** [docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md](docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md)

## Legacy repositories

Development moved here from:

- [implacables/sportify-legacy](https://github.com/implacables/sportify-legacy)
- [implacables/sportify-game-reconstruction-legacy](https://github.com/implacables/sportify-game-reconstruction-legacy)

## Data (not in git)

Set **`SPORTIFY_DATA_ROOT`** (default `~/data/sportify`) for SoccerNet-GS (`$SPORTIFY_DATA_ROOT/SoccerNetGS/`), vendor baselines, and match video. Quick setup: `source scripts/sportify-env.sh`. Download and layout: [docs/data-layout.md](docs/data-layout.md). Benchmarks: [sportify-game-reconstruction/benchmarks/README.md](sportify-game-reconstruction/benchmarks/README.md).
