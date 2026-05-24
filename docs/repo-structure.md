# Repository Structure

**Status:** Active — canonical repo at [implacables/sportify](https://github.com/implacables/sportify)  
**Last updated:** 2026-05-24  
**Context:** VPS clones **one repo**. Local tree at `~/Documents/sportify` is the canonical layout.

## Current state

| Location | Contents | Problem |
|----------|----------|---------|
| **Local** `~/Documents/sportify` | Product docs, benchmarks, pipeline docs under `sportify-game-reconstruction/` | Not on GitHub yet |
| **GH** `sportify` | Deprecated product / old work | **Name collision** |
| **GH** `sportify-game-reconstruction` | AI pipeline code only | Incomplete; wrong scope for monorepo |

## Monorepo layout (canonical)

```
sportify/                          # github.com/<org>/sportify
├── AGENTS.md
├── README.md
├── docs/
├── benchmarks/
└── sportify-game-reconstruction/
    ├── docs/
    └── src/                       # future pipeline code
```

## GitHub migration (completed)

1. Renamed old `sportify` → [`sportify-legacy`](https://github.com/implacables/sportify-legacy)
2. Renamed old `sportify-game-reconstruction` → [`sportify-game-reconstruction-legacy`](https://github.com/implacables/sportify-game-reconstruction-legacy)
3. Canonical monorepo: [`implacables/sportify`](https://github.com/implacables/sportify)

## VPS layout

```bash
git clone git@github.com:implacables/sportify.git ~/sportify
export SPORTIFY_DATA_ROOT=~/data/sportify
export SPORTIFY_REPO=~/sportify
```

| Path | In git? | Purpose |
|------|---------|---------|
| `~/sportify/` | Yes | Docs, benchmarks, pipeline |
| `~/data/sportify/` | No | SoccerNet-GS, vendor/sn-gamestate, weights |

Data and vendor baselines stay **outside** the repo — see [VPS benchmark plan](plans/2026-05-24-vps-soccernet-baseline-benchmark.md).

## Future thesis repos (not monorepo)

Scoring and matchmaking → separate repos when built (`sportify-scoring`, etc.); consume reconstruction JSON artifacts only.
