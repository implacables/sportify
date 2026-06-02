# SoccerNet GSR Benchmark Track

Reproduce the official baseline and (optionally) score GS-HOTA on SoccerNet-GS clips.

## Prerequisites

- **OS:** Linux + NVIDIA CUDA (macOS is rejected by `setup-bench.sh` / `run-baseline.sh` checks)
- Python 3.9, [uv](https://docs.astral.sh/uv/) (recommended by upstream)
- GPU with sufficient VRAM for YOLO + TVCalib + MMOCR (≥ 8 GB; `--low-vram` for ≤ 8 GB cards; 24 GB recommended)
- RAM: ≥ 16 GB available
- Disk: ≥ 50 GB free at `SPORTIFY_DATA_ROOT` (≥ 15 GB if `--skip-download`)

`make setup` and `make run` run these checks before clone/install/run. To inspect manually:

```bash
source scripts/sportify-check-requirements.sh
sportify_check_requirements gsr-setup --data-root "${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"
```

## One-time setup

```bash
cd sportify-game-reconstruction/benchmarks/soccernet-gsr
export SPORTIFY_DATA_ROOT="${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"

make setup                  # clone, install, download dataset, patch config
make setup LOW_VRAM=1       # same but patches batch sizes for <= 8 GB VRAM
make setup SPLIT=train      # download train split instead of valid
make setup SKIP_DOWNLOAD=1  # vendor install only (dataset already on disk)
make setup DATA_ROOT=/path  # override data root
```

Run `make dry-run` first to check prerequisites and see resolved paths without installing anything.

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

```bash
cd sportify-game-reconstruction/benchmarks/soccernet-gsr
make run                              # uses manifests/valid-quick.yaml
make run MANIFEST=path/to/custom.yaml
```

Or directly in the vendor clone:

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv run tracklab -cn soccernet
```

Results land in `sportify-game-reconstruction/benchmarks/results/soccernet-gsr/<timestamp>/` when using the wrapper.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `DATA_ROOT` | auto (`/workspace` or `~/data/sportify`) | SoccerNet data location |
| `SPLIT` | `valid` | Dataset split to download |
| `SKIP_DOWNLOAD` | unset | Set to `1` to skip dataset download |
| `LOW_VRAM` | unset | Set to `1` to patch batch sizes for ≤ 8 GB VRAM |
| `MANIFEST` | `manifests/valid-quick.yaml` | Clip manifest for `make run` |

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
