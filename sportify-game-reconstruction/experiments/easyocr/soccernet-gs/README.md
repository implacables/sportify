# EasyOCR on SoccerNet-GS

Jersey number OCR benchmark on **SoccerNet Game State** validation clips: crop GT player boxes, run EasyOCR, report accuracy and throughput.

| Doc | Purpose |
|-----|---------|
| [investigation.md](investigation.md) | Dataset fields, sampling, metrics |
| [easyocr_soccernet_gs.ipynb](easyocr_soccernet_gs.ipynb) | Runnable bench |

## Prerequisites

```bash
# From repo root — downloads valid split to ~/data/sportify/SoccerNetGS
benchmarks/soccernet-gsr/setup-bench.sh
```

## Run

```bash
cd sportify-game-reconstruction/experiments/easyocr/soccernet-gs
./setup.sh && source .venv/bin/activate
jupyter notebook easyocr_soccernet_gs.ipynb
```

Set `SPORTIFY_DATA_ROOT` if data is not under `~/data/sportify`. Kernel: **Sportify EasyOCR SoccerNet-GS**.

Default clips: `SNGS-021`, `SNGS-022`, `SNGS-023` (same as [valid-quick manifest](../../../../benchmarks/soccernet-gsr/manifests/valid-quick.yaml)).
