# SoccerNet GSR Benchmark Track

Reproduce the official baseline and (optionally) score GS-HOTA on SoccerNet-GS clips.

## Prerequisites

- **OS:** Linux + NVIDIA CUDA (macOS is rejected by `setup-bench.sh` / `run-baseline.sh` checks)
- Python 3.9, [uv](https://docs.astral.sh/uv/) (recommended by upstream)
- GPU with sufficient VRAM for YOLO + TVCalib + MMOCR (≥ 8 GB; `--low-vram` for ≤ 8 GB cards; 24 GB recommended)
- RAM: ≥ 16 GB available
- Disk: ≥ 50 GB free at `SPORTIFY_DATA_ROOT` (≥ 15 GB if `--skip-download`)

`setup-bench.sh` and `run-baseline.sh` run these checks before clone/install/run. To inspect manually:

```bash
source scripts/sportify-check-requirements.sh
sportify_check_requirements gsr-setup --data-root "${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"
```

## One-time setup

```bash
export SPORTIFY_DATA_ROOT="${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"

# Automated setup (vendor clone, venv, dataset download, config paths)
./benchmarks/soccernet-gsr/setup-bench.sh

# GPUs with <= 8 GB VRAM (e.g. RTX 3060 Laptop):
./benchmarks/soccernet-gsr/setup-bench.sh --low-vram
```

Manual steps (if you prefer):

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

- `data_dir`: absolute path to `$SPORTIFY_DATA_ROOT` (dataset lives at `$SPORTIFY_DATA_ROOT/SoccerNetGS`)
- `model_dir`: `$SPORTIFY_DATA_ROOT/pretrained_models`
- Reduce `modules.*.batch_size` on low-VRAM GPUs

Dataset: downloaded by `setup-bench.sh`, or auto-download on first `tracklab` run. See [investigation.md](investigation.md).

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
