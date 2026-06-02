# Sportify Benchmarks

Benchmark harness for the reconstruction POC. Three tracks:

| Track | Purpose | POC gate? |
|-------|---------|-----------|
| **[throughput/](throughput/)** | Wall-clock FPS, conditional-step counts, cost model vs SoccerNet ~1.1 FPS | **Yes** |
| **[yolo-soccernet/](yolo-soccernet/)** | YOLO person detection — mAP sanity + inference FPS on SoccerNet-GS | Detection step |
| **[EasyOCR SoccerNet-GS](../sportify-game-reconstruction/experiments/easyocr/soccernet-gs/)** | Jersey OCR on GT player crops (valid clips) | OCR step (experiment) |
| **[soccernet-gsr/](soccernet-gsr/)** | Official GS-HOTA on SoccerNet-GS clips; baseline reproduction | Optional (sanity / thesis) |

## Layout

```
benchmarks/
├── config/reference.yaml       # Shared constants (baseline FPS, hardware notes)
├── soccernet-gsr/              # Official SoccerNet GSR baseline + GS-HOTA
│   ├── investigation.md        # Task, dataset, metric, baseline summary
│   ├── setup-bench.sh          # One-time env setup (vendor + dataset)
│   ├── manifests/              # Clip lists for smoke / full eval
│   └── run-baseline.sh         # Wrapper around sn-gamestate / TrackLab
├── yolo-soccernet/             # YOLO person detection on SoccerNet-GS
│   ├── spec.md                 # Train / eval / bench specification
│   ├── investigation.md        # Dataset label structure for conversion
│   ├── manifests/              # Clip lists for smoke / quick eval
│   └── schemas/                # Result JSON schema
├── throughput/                 # Sportify pipeline efficiency benchmarks
│   ├── manifests/              # Reference videos (paths, stride, roster refs)
│   └── schemas/                # Result JSON schema
└── results/                    # Run outputs (gitignored except README)
```

## Workflow

1. **Reproduce reference** — Run `soccernet-gsr/run-baseline.sh` on a small validation subset; record FPS and GS-HOTA in `results/`.
2. **Measure Sportify** — Run the reconstruction pipeline on the same clips (or representative amateur footage) with `throughput/` manifests; compare `effective_fps` and conditional-step counts.
3. **Record honestly** — Each run writes a timestamped folder under `results/` with hardware metadata, config snapshot, and metrics.

## Data paths

Large assets stay outside git. Set **`SPORTIFY_DATA_ROOT`** (default: `~/data/sportify`); SoccerNet-GS is at `$SPORTIFY_DATA_ROOT/SoccerNetGS/`. Download: `benchmarks/soccernet-gsr/setup-bench.sh`. Full layout: [docs/data-layout.md](../docs/data-layout.md). Path templates: [config/reference.yaml](config/reference.yaml).

**VPS execution:** [docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md](../docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md) — hand this to the VPS agent.

## Related docs

- [YOLO person detection spec](yolo-soccernet/spec.md)
- [SoccerNet GSR investigation](soccernet-gsr/investigation.md)
- [Pipeline spec — performance baseline](../sportify-game-reconstruction/docs/spec/overview.md#11-performance-baseline-soccernet-gsr)
- [Product stages](../docs/product-stages.md)
