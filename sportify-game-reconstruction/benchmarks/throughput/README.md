# Throughput Benchmark Track (POC primary gate)

Measures **Sportify reconstruction pipeline** efficiency against the SoccerNet GSR ~1.1 FPS baseline.

## Metrics

| Metric | Definition | POC gate |
|--------|------------|----------|
| `effective_fps` | `frames_processed / wall_clock_seconds` | **Yes** |
| `wall_clock_seconds` | End-to-end job time | **Yes** |
| `conditional_steps` | OCR / ReID invocation counts | Evidence of lean design |
| `baseline_comparison.hours_at_1_1_fps` | `frames / 1.1 / 3600` | Context |
| `gs_hota` | Only if running on SoccerNet-GS | No |

## Manifests

YAML files under `manifests/` describe a benchmark run:

- Video source (path, duration, native FPS)
- Venue homography reference (or synthetic for SoccerNet clips)
- Roster (for Sportify pipeline; N/A for raw baseline)
- Processing config (`frame_stride`, conditional triggers)

| File | Purpose |
|------|---------|
| [manifests/soccernet-clip.yaml](manifests/soccernet-clip.yaml) | Shared clip for apples-to-apples vs baseline |
| [manifests/amateur-reference.yaml](manifests/amateur-reference.yaml) | Placeholder for DJI Osmo match footage |

## Running (when pipeline exists)

```bash
# TBD: sportify-bench run --manifest benchmarks/throughput/manifests/soccernet-clip.yaml
```

Until the worker exists, record manual runs using [schemas/run-result.schema.json](schemas/run-result.schema.json).

## Result storage

```
benchmarks/results/throughput/<timestamp>/
├── manifest.yaml          # copy of input manifest
├── run-result.json        # validated against schema
├── reference.yaml         # baseline constants snapshot
└── job.meta.json          # pipeline job metadata (if applicable)
```
