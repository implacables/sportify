# SoccerNet GSR Benchmark Track

Reproduce the official baseline and (optionally) score GS-HOTA on SoccerNet-GS clips.

## Prerequisites

- Python 3.9, [uv](https://docs.astral.sh/uv/) (recommended by upstream)
- GPU with sufficient VRAM for YOLO + TVCalib + MMOCR (A100-class for paper parity; smaller GPUs need batch-size tuning)
- Disk: dataset ~several GB; model weights downloaded on first run

## One-time setup

```bash
export SPORTIFY_DATA_ROOT="${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"
mkdir -p "$SPORTIFY_DATA_ROOT/vendor"

# Clone official baseline (GPL-3.0 — keep in vendor/, not vendored into Sportify source)
git clone https://github.com/SoccerNet/sn-gamestate.git "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv venv --python 3.9
uv pip install -e .
uv run mim install mmcv==2.0.1
```

Edit `sn_gamestate/configs/soccernet.yaml`:

- `data_dir`: absolute path to `$SPORTIFY_DATA_ROOT/SoccerNetGS`
- Machine / batch_size for your GPU

Dataset: auto-download on first `tracklab` run, or see [investigation.md](investigation.md).

## Run

From the Sportify repo:

```bash
./benchmarks/soccernet-gsr/run-baseline.sh --manifest benchmarks/soccernet-gsr/manifests/valid-quick.yaml
```

Or directly in the vendor clone:

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv run tracklab -cn soccernet
```

Results land in `benchmarks/results/soccernet-gsr/<timestamp>/` when using the wrapper.

## Manifests

| File | Use |
|------|-----|
| [manifests/valid-quick.yaml](manifests/valid-quick.yaml) | 1–3 validation clips — smoke test throughput + GS-HOTA |
| (TBD) `valid-full.yaml` | Full validation set — accuracy regression |

## What to record

| Field | Source |
|-------|--------|
| `wall_clock_seconds` | Wrapper timing |
| `frames_processed` | Clip length × FPS |
| `effective_fps` | frames / wall_clock |
| `gs_hota` | TrackLab eval output |
| `gpu`, `batch_size` | Config snapshot |

Compare against [reference.yaml](../config/reference.yaml) baseline (1.1 FPS, 22.26% GS-HOTA).
