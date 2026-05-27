# Data layout and environment variables

**Status:** Active  
**Last updated:** 2026-05-27

Large assets (SoccerNet-GS, vendor baselines, match video, model weights) stay **outside git**. One environment variable points at the shared data root on each machine.

## Required: `SPORTIFY_DATA_ROOT`

| Item | Value |
|------|--------|
| Variable | `SPORTIFY_DATA_ROOT` |
| Default if unset | `/workspace` when that directory exists (cloud workspaces), else `~/data/sportify` |
| In git? | **No** — local/VPS only |
| Repo clone | Separate path, e.g. `~/sportify` or `~/Documents/sportify` |

Set it in your shell profile on every machine that runs benchmarks or notebooks:

```bash
# Option 1 — repo helper (recommended)
source ~/sportify/scripts/sportify-env.sh
sportify-env   # print resolved paths

# Option 2 — manual
# Laptop / VPS:
export SPORTIFY_DATA_ROOT="$HOME/data/sportify"
# Cloud workspace (or rely on default when /workspace exists):
# export SPORTIFY_DATA_ROOT="/workspace"
mkdir -p "$SPORTIFY_DATA_ROOT"
```

Per-machine overrides (custom data root, `SOCCERNET_PWD`): copy [scripts/sportify-env.local.sh.example](../scripts/sportify-env.local.sh.example) to `scripts/sportify-env.local.sh` (gitignored).

**VPS example:** repo at `~/sportify`, data at `~/data/sportify`.

**Cloud / Cursor workspace:** if `/workspace` exists, `sportify-env.sh` and `setup-bench.sh` use **`/workspace`** even when a previous shell left `SPORTIFY_DATA_ROOT=/root/data/sportify`. To keep the old path: `export SPORTIFY_DATA_ROOT_FORCE=1`.

**Jupyter as root (no `/workspace`):** defaults to `~/data/sportify` → often `/root/data/sportify`. Export `SPORTIFY_DATA_ROOT` explicitly if your data lives elsewhere.

## Where SoccerNet-GS lives

SoccerNet Game State (task `gamestate-2024`) is always under:

```text
$SPORTIFY_DATA_ROOT/SoccerNetGS/
```

After download **and unzip**, labeled validation clips look like:

```text
$SPORTIFY_DATA_ROOT/SoccerNetGS/
├── sequences_info.json
├── gamestate-2024/
│   └── valid.zip          # downloader cache (can delete after extract)
├── valid/
│   └── SNGS-021/
│       ├── img1/
│       │   └── 000001.jpg … 000750.jpg
│       └── Labels-GameState.json
├── train/                 # optional — 57 clips
└── test/                  # images only; labels withheld
```

EasyOCR, YOLO, and GSR benchmarks all read from this tree. There is no separate “SoccerNet path” variable — only `SPORTIFY_DATA_ROOT` plus the fixed subdirectory `SoccerNetGS/`.

## Which dataset?

Sportify benchmarks use **SoccerNet Game State** (task id **`gamestate-2024`**), not the older SoccerNet v2 action-spotting packs. Each clip is 30 s of **1080p broadcast video** plus `Labels-GameState.json` (version **≥ 1.3**).

| Split | Clips | Labels in zip? | Needed for EasyOCR bench? |
|-------|-------|----------------|---------------------------|
| **valid** | 59 | Yes | **Yes** (default) |
| train | 57 | Yes | Optional (fine-tune) |
| test | 50 | No (submit predictions) | No |
| challenge | varies | No | No |

Upstream: [sn-gamestate README](https://github.com/SoccerNet/sn-gamestate), [SoccerNet data page](https://www.soccer-net.org/data).

## Access / NDA

SoccerNet **video** is copyrighted. If the downloader asks for a password:

1. Fill the [SoccerNet NDA form](https://www.soccer-net.org/data) (link on their data page).
2. Use the password from email as `SOCCERNET_PWD` or pass it to `SoccerNetDownloader(password=...)`.

Some tasks download labels without video; **gamestate-2024** includes frame JPEGs, so expect NDA/password for a full download. If download fails mid-way, delete the partial `SoccerNetGS` tree and retry (upstream recommendation).

## Download methods

### Method A — Sportify script (recommended)

Install [uv](https://docs.astral.sh/uv/), then from the **sportify repo root**:

```bash
source scripts/sportify-env.sh   # sets SPORTIFY_DATA_ROOT (/workspace or ~/data/sportify)
benchmarks/soccernet-gsr/setup-bench.sh
```

Or explicitly:

```bash
export SPORTIFY_DATA_ROOT="/workspace"
benchmarks/soccernet-gsr/setup-bench.sh
```

This:

1. Clones [sn-gamestate](https://github.com/SoccerNet/sn-gamestate) → `$SPORTIFY_DATA_ROOT/vendor/sn-gamestate` (Python 3.9 venv, ~10–30 min first time)
2. Runs `SoccerNetDownloader(...).downloadDataTask(task="gamestate-2024", split=[valid])`
3. Unzips `gamestate-2024/valid.zip` → `SoccerNetGS/valid/`

Options:

```bash
# Custom data root
benchmarks/soccernet-gsr/setup-bench.sh --data-root /mnt/data/sportify

# Train split instead of valid
benchmarks/soccernet-gsr/setup-bench.sh --split train

# Vendor install only (you will download/unzip yourself)
benchmarks/soccernet-gsr/setup-bench.sh --skip-download

# Low VRAM GPU patch for baseline (unrelated to download)
benchmarks/soccernet-gsr/setup-bench.sh --low-vram
```

**Valid only** is enough for the EasyOCR notebook (~tens of GB; exact size depends on SoccerNet packaging).

### Method B — Manual Python (minimal Sportify install)

Inside an environment that has the `SoccerNet` pip package (installed by `sn-gamestate` or `pip install SoccerNet`):

```bash
export SPORTIFY_DATA_ROOT="${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"
export SOCCERNET_PWD="your-nda-password"   # if prompted

cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"   # or any venv with SoccerNet
uv run python <<'PY'
import os
from SoccerNet.Downloader import SoccerNetDownloader

root = os.environ["SPORTIFY_DATA_ROOT"]
pwd = os.environ.get("SOCCERNET_PWD")
dl = SoccerNetDownloader(LocalDirectory=f"{root}/SoccerNetGS", password=pwd)
dl.downloadDataTask(task="gamestate-2024", split=["valid"])
print("done")
PY

mkdir -p "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid"
unzip -o "$SPORTIFY_DATA_ROOT/SoccerNetGS/gamestate-2024/valid.zip" \
  -d "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid"
```

### Method C — TrackLab auto-download

On first baseline run, TrackLab can download data and weights automatically:

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv run tracklab -cn soccernet dataset.eval_set=valid dataset.nvid=1 \
  'dataset.vids_dict.valid=[SNGS-021]' dataset.nframes=100
```

Still requires the same `data_dir` / `SoccerNetGS` layout. If a partial download corrupts the tree, remove `SoccerNetGS` and rerun.

### Method D — Unzip only (zip already on disk)

```bash
mkdir -p "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid"
unzip -o "$SPORTIFY_DATA_ROOT/SoccerNetGS/gamestate-2024/valid.zip" \
  -d "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid"
```

## Verify

```bash
test -f "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid/SNGS-021/Labels-GameState.json" && echo "OK"
test -f "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid/SNGS-021/img1/000001.jpg" && echo "frames OK"
python3 -c "import json; print(json.load(open('$SPORTIFY_DATA_ROOT/SoccerNetGS/valid/SNGS-021/Labels-GameState.json'))['info']['version'])"
# expect >= 1.3
```

## Full data root layout (reference)

```text
$SPORTIFY_DATA_ROOT/
├── SoccerNetGS/              # SoccerNet Game State (gamestate-2024)
├── vendor/
│   └── sn-gamestate/         # upstream GSR baseline (Python 3.9 venv inside)
├── pretrained_models/        # baseline weights (sn-gamestate)
├── yolo-soccernet/           # converted YOLO dataset (generated)
├── matches/                  # amateur / POC match video (optional)
├── venues/                   # homography etc. (optional)
└── rosters/                  # roster JSON (optional)
```

Path templates for manifests: [benchmarks/config/reference.yaml](../benchmarks/config/reference.yaml).

## Consumers

| Tool | Path used |
|------|-----------|
| [soccernet-gsr/setup-bench.sh](../benchmarks/soccernet-gsr/setup-bench.sh) | Downloads into `$SPORTIFY_DATA_ROOT/SoccerNetGS` |
| [EasyOCR SoccerNet-GS notebook](../sportify-game-reconstruction/experiments/easyocr/soccernet-gs/) | `$SPORTIFY_DATA_ROOT/SoccerNetGS/valid/...` |
| [yolo-soccernet](../benchmarks/yolo-soccernet/) | Same raw tree; writes `$SPORTIFY_DATA_ROOT/yolo-soccernet/` |

## Related

- [repo-structure.md](repo-structure.md) — monorepo vs data on VPS  
- [VPS benchmark plan](plans/2026-05-24-vps-soccernet-baseline-benchmark.md)  
- [soccernet-gsr/README.md](../benchmarks/soccernet-gsr/README.md)
