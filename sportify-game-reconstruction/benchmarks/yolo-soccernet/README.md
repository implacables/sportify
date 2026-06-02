# YOLO Person Detection on SoccerNet-GS

Benchmark track for single-class **person** detection: label conversion, mAP evaluation, and inference throughput on SoccerNet-GS clips.

| Doc | Purpose |
|-----|---------|
| [spec.md](spec.md) | Normative train / eval / bench specification |
| [investigation.md](investigation.md) | Dataset layout and label schema reference |

## Quick reference

| Phase | What | POC gate? |
|-------|------|-----------|
| **A — Eval + bench** | Pretrained YOLO (`yolo11n.pt`) on valid split; mAP + FPS | FPS yes; mAP sanity only |
| **B — Fine-tune** | Optional train on `train`, eval on `valid` | When Phase A mAP insufficient |

## Layout

```
yolo-soccernet/
├── spec.md
├── investigation.md
├── manifests/
│   └── valid-quick.yaml
└── schemas/
    └── run-result.schema.json
```

## Data paths

- Raw labels: `$SPORTIFY_DATA_ROOT/SoccerNetGS` — setup via [soccernet-gsr/setup-bench.sh](../soccernet-gsr/setup-bench.sh)
- Converted YOLO dataset: `$SPORTIFY_DATA_ROOT/yolo-soccernet/`
- Results: `benchmarks/results/yolo-soccernet/<timestamp>/`

## Related

- [Benchmarks overview](../README.md)
- [SoccerNet GSR investigation](../soccernet-gsr/investigation.md)
- [Pipeline spec — player detection](../../sportify-game-reconstruction/docs/spec/overview.md)

Harness scripts (`convert_to_yolo.py`, `run-eval.sh`, `run-bench.sh`) are follow-up work — see spec.md §12.
