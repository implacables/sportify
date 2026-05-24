# VPS SoccerNet GSR Baseline Benchmark Plan

> **For agentic workers:** Execute tasks in order. Check each checkbox before proceeding. Do not skip the smoke run (Task 4) before the full clip run (Task 5).

**Goal:** Establish a **measured throughput + GS-HOTA reference** for the official SoccerNet GSR baseline on **RTX 3090 (24 GB)**, using **SoccerNet-GS validation clips**, with results stored under `benchmarks/results/`.

**Architecture:** Clone Sportify monorepo to VPS. Install upstream `sn-gamestate` as a **vendor dependency** outside git (`~/data/sportify/vendor/`). Download **valid split only**. Run TrackLab baseline twice: smoke (100 frames) then one full 30s clip (`SNGS-021`). Record metrics in repo schema — **do not compare 3090 numbers to paper's A100 1.1 FPS as apples-to-apples**.

**Tech stack:** Ubuntu VPS, NVIDIA RTX 3090, CUDA 11.7+, Python **3.9 only**, [uv](https://docs.astral.sh/uv/), [sn-gamestate](https://github.com/SoccerNet/sn-gamestate) / TrackLab, SoccerNet-GS `gamestate-2024` valid split.

**Related docs:** [repo-structure.md](../repo-structure.md) · [benchmarks/soccernet-gsr/investigation.md](../../benchmarks/soccernet-gsr/investigation.md) · [reference.yaml](../../benchmarks/config/reference.yaml)

---

## Important constraints

| Topic | Rule |
|-------|------|
| Hardware | RTX 3090 24 GB — **not** A100. Paper baseline (1.1 FPS) is **context only**. |
| Comparison | SN-GS clips for both baseline and (later) Sportify pipeline on **same GPU**. |
| Python | **3.9.x only** — sn-gamestate requires `>=3.9,<3.10` |
| PyTorch | **1.13.1 + CUDA 11.7** — pinned by upstream |
| Disk budget | ~15–25 GB for valid split + model weights + venv (allow 50 GB free) |
| Remote git | Stay **local** until baseline numbers exist — copy repo via `scp`/`rsync` or private fork |

---

## Task 0: VPS prerequisites

**Files:** none (system setup)

- [ ] **Step 0.1: Verify GPU**

```bash
nvidia-smi
```

Expected: `NVIDIA GeForce RTX 3090`, driver ≥ 525, CUDA capability visible.

- [ ] **Step 0.2: Verify disk and RAM**

```bash
df -h ~
free -h
```

Expected: ≥ **50 GB** free on home/data volume; ≥ **16 GB** RAM recommended.

- [ ] **Step 0.3: Install system packages**

```bash
sudo apt-get update
sudo apt-get install -y git curl build-essential unzip ffmpeg libgl1 libglib2.0-0
```

- [ ] **Step 0.4: Install uv**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source "$HOME/.local/bin/env"  # or restart shell
uv --version
```

- [ ] **Step 0.5: Install Python 3.9** (if not present)

```bash
uv python install 3.9
uv python list | grep 3.9
```

---

## Task 1: Clone Sportify repo onto VPS

**Files:** entire repo at `~/sportify/`

Prerequisite: GitHub remote exists (see [repo-structure.md](../repo-structure.md) — rename old `sportify` → `sportify-legacy`, push monorepo as `sportify`).

- [ ] **Step 1.1: Clone**

```bash
git clone git@github.com:implacables/sportify.git ~/sportify
export SPORTIFY_REPO=~/sportify
export SPORTIFY_DATA_ROOT=~/data/sportify
```

- [ ] **Step 1.2: Verify layout**

```bash
test -f ~/sportify/benchmarks/soccernet-gsr/run-baseline.sh && \
test -f ~/sportify/docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md && \
echo OK
```

---

## Task 2: Create data layout (outside git)

**Files:**

- Create: `~/data/sportify/{vendor,SoccerNetGS,pretrained_models}`

- [ ] **Step 2.1: Set environment**

Add to `~/.bashrc` (or export in session):

```bash
export SPORTIFY_DATA_ROOT="$HOME/data/sportify"
export SPORTIFY_REPO="$HOME/sportify"
mkdir -p "$SPORTIFY_DATA_ROOT/vendor" "$SPORTIFY_DATA_ROOT/SoccerNetGS"
```

- [ ] **Step 2.2: Confirm git ignores data**

```bash
grep -q 'data/' "$SPORTIFY_REPO/.gitignore" && echo "data ignored OK"
```

---

## Task 3: Install sn-gamestate (vendor baseline)

**Files:**

- Clone: `$SPORTIFY_DATA_ROOT/vendor/sn-gamestate`
- Venv: `$SPORTIFY_DATA_ROOT/vendor/sn-gamestate/.venv`

- [ ] **Step 3.1: Clone upstream**

```bash
git clone https://github.com/SoccerNet/sn-gamestate.git \
  "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
```

- [ ] **Step 3.2: Create venv and install (expect 10–30 min)**

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv venv --python 3.9
uv pip install -e .
uv run mim install mmcv==2.0.1
```

If OOM during install: close other GPU processes; retry.

- [ ] **Step 3.3: Verify import**

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv run python -c "import tracklab; import sn_gamestate; print('OK')"
```

Expected: `OK` with no traceback.

- [ ] **Step 3.4: Patch config paths**

Edit `$SPORTIFY_DATA_ROOT/vendor/sn-gamestate/sn_gamestate/configs/soccernet.yaml`:

```yaml
data_dir: "/home/<USER>/data/sportify"   # absolute path — replace <USER>
model_dir: "/home/<USER>/data/sportify/pretrained_models"
```

Leave `dataset.nvid: 1` as default for now.

---

## Task 4: Download SoccerNet-GS (valid split only)

**Files:** `$SPORTIFY_DATA_ROOT/SoccerNetGS/valid/`

- [ ] **Step 4.1: Download valid split**

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
uv run python <<'PY'
from SoccerNet.Downloader import SoccerNetDownloader
dl = SoccerNetDownloader(LocalDirectory=f"{__import__('os').environ.get('SPORTIFY_DATA_ROOT', __import__('os').path.expanduser('~/data/sportify'))}/SoccerNetGS")
dl.downloadDataTask(task="gamestate-2024", split=["valid"])
print("download started/completed")
PY
```

- [ ] **Step 4.2: Unzip valid split**

```bash
cd "$SPORTIFY_DATA_ROOT/SoccerNetGS"
unzip -o gamestate-2024/valid.zip -d valid
```

- [ ] **Step 4.3: Verify dataset version ≥ 1.3**

```bash
python3 - <<'PY'
import json, glob
labels = glob.glob("/home/*/data/sportify/SoccerNetGS/valid/**/Labels-GameState.json", recursive=True)
assert labels, "no Labels-GameState.json found"
v = json.load(open(labels[0]))["info"]["version"]
print("dataset version:", v)
assert float(v) >= 1.3, f"need >= 1.3, got {v}"
PY
```

Adjust path if `$SPORTIFY_DATA_ROOT` differs.

- [ ] **Step 4.4: Confirm target clip exists**

```bash
find "$SPORTIFY_DATA_ROOT/SoccerNetGS/valid" -iname '*021*' | head -5
```

Note exact video id folder (expected `SNGS-021`).

---

## Task 5: Smoke run (minimal — 100 frames)

**Purpose:** Validate install, CUDA, weights download — **not** for reporting benchmark numbers.

**Files:**

- Output: `$SPORTIFY_DATA_ROOT/vendor/sn-gamestate/outputs/...`
- Copy results to: `$SPORTIFY_REPO/benchmarks/results/soccernet-gsr/<timestamp>-smoke/`

- [ ] **Step 5.1: Run smoke**

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
START=$(date +%s)
uv run tracklab -cn soccernet \
  dataset.eval_set=valid \
  dataset.nvid=1 \
  'dataset.vids_dict.valid=[SNGS-021]' \
  dataset.nframes=100 \
  visualization.cfg.save_videos=False \
  eval_tracking=True
END=$(date +%s)
echo "smoke wall_clock_seconds=$((END-START))"
```

If Hydra list syntax fails, try: `dataset.vids_dict.valid=[\"SNGS-021\"]` or edit yaml directly:

```yaml
dataset:
  vids_dict:
    valid: [SNGS-021]
  nframes: 100
```

- [ ] **Step 5.2: Confirm completion**

Expected in stdout: no Python traceback; eval section may show **low GS-HOTA** (incomplete frames — expected).

- [ ] **Step 5.3: If CUDA OOM, reduce batch sizes**

Edit `soccernet.yaml` under `modules:`:

```yaml
  bbox_detector: {batch_size: 4}
  reid: {batch_size: 32}
  jersey_number_detect: {batch_size: 4}
```

Retry Step 5.1.

---

## Task 6: Full benchmark run (one clip — reportable)

**Purpose:** Primary reference measurement for thesis/POC comparison.

**Clip:** `SNGS-021` (30 seconds, full frame count, typically ~750 frames at 25 FPS).

- [ ] **Step 6.1: Run full clip with timing**

```bash
cd "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate"
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="$SPORTIFY_REPO/benchmarks/results/soccernet-gsr/${TS}"
mkdir -p "$OUT"

cp "$SPORTIFY_REPO/benchmarks/soccernet-gsr/manifests/valid-quick.yaml" "$OUT/manifest.yaml"
cp "$SPORTIFY_REPO/benchmarks/config/reference.yaml" "$OUT/reference.yaml"
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv > "$OUT/gpu.txt"

START=$(date +%s)
uv run tracklab -cn soccernet \
  dataset.eval_set=valid \
  dataset.nvid=1 \
  'dataset.vids_dict.valid=[SNGS-021]' \
  visualization.cfg.save_videos=False \
  eval_tracking=True \
  2>&1 | tee "$OUT/stdout.log"
END=$(date +%s)
WALL=$((END-START))
echo "$WALL" > "$OUT/wall_clock_seconds.txt"
```

- [ ] **Step 6.2: Parse GS-HOTA from log**

```bash
grep -i 'GS-HOTA\|gs_hota\|HOTA' "$OUT/stdout.log" | tail -5
```

Record the validation GS-HOTA value (expect ~20–25% range if install is correct).

- [ ] **Step 6.3: Compute effective FPS**

SoccerNet clips are 30s. Get frame count from labels or assume 25 FPS → ~750 frames.

```bash
python3 <<PY
wall = float(open("$OUT/wall_clock_seconds.txt").read().strip())
# Replace with actual frame count from dataset if available
frames = 750  # ~30s @ 25fps — update after inspecting clip metadata
fps = frames / wall
print(f"effective_fps={fps:.3f}")
print(f"note: paper reports ~1.1 FPS on A100; this is RTX 3090 — not comparable hardware")
PY
```

If possible, read exact frame count:

```bash
uv run python - <<'PY'
import json, glob
# adjust path to SNGS-021 Labels-GameState.json
PY
```

- [ ] **Step 6.4: Write run-result JSON**

Create `$OUT/run-result.json`:

```json
{
  "benchmark": "soccernet-gsr",
  "timestamp_utc": "<TS>",
  "manifest_name": "SNGS-021-full",
  "pipeline": "soccernet-gsr",
  "hardware": {
    "gpu": "NVIDIA GeForce RTX 3090 24GB",
    "cpu": "<from lscpu>",
    "ram_gb": null,
    "vps_provider": "<provider name>"
  },
  "metrics": {
    "clip_id": "SNGS-021",
    "split": "valid",
    "frames_processed": 750,
    "wall_clock_seconds": 0,
    "effective_fps": 0,
    "gs_hota": null,
    "baseline_comparison": {
      "soccernet_paper_fps": 1.1,
      "soccernet_paper_gpu": "NVIDIA A100",
      "note": "Paper baseline is context only — different GPU"
    }
  },
  "status": "finished"
}
```

Fill in measured values from Steps 6.2–6.3.

- [ ] **Step 6.5: Symlink upstream output**

```bash
LATEST=$(find "$SPORTIFY_DATA_ROOT/vendor/sn-gamestate/outputs" -mindepth 3 -maxdepth 3 -type d | sort | tail -1)
ln -sfn "$LATEST" "$OUT/upstream-output"
```

---

## Task 7: Optional — three-clip throughput sample

Only after Task 6 succeeds. Uses manifest `benchmarks/soccernet-gsr/manifests/valid-quick.yaml` clips: `SNGS-021`, `SNGS-013`, `SNGS-175`.

- [ ] **Step 7.1: Run each clip** (same flags as Task 6, change `vids_dict`)

- [ ] **Step 7.2: Record mean ± std effective_fps** across 3 clips in `$OUT/summary-three-clip.json`

---

## Task 8: Handoff back to dev machine

- [ ] **Step 8.1: Archive results**

```bash
tar -czf ~/soccernet-gsr-baseline-3090.tar.gz -C "$SPORTIFY_REPO/benchmarks/results/soccernet-gsr" .
scp user@vps:~/soccernet-gsr-baseline-3090.tar.gz ~/Downloads/
```

- [ ] **Step 8.2: Update reference.yaml on dev machine** with measured 3090 baseline FPS (after review).

- [ ] **Step 8.3: Do not push to GitHub until numbers reviewed** (per project policy).

---

## Failure recovery

| Symptom | Action |
|---------|--------|
| `CUDA out of memory` | Lower batch sizes (Task 5 Step 5.3); ensure no other GPU jobs |
| mmcv install fails | `uv run mim install mmcv==2.0.1` inside venv; check CUDA 11.7 |
| Wrong Python version | `uv venv --python 3.9` — must not use 3.10+ |
| Incomplete dataset download | Delete `$SPORTIFY_DATA_ROOT/SoccerNetGS` and re-download valid only |
| Hydra override ignored | Edit `soccernet.yaml` directly instead of CLI overrides |
| GS-HOTA very low on smoke | Expected with `nframes=100`; only trust Task 6 full clip |

---

## What success looks like

| Deliverable | Location |
|-------------|----------|
| Smoke run passed | stdout, no crash |
| Full clip wall-clock + FPS | `benchmarks/results/soccernet-gsr/<ts>/run-result.json` |
| GS-HOTA on SNGS-021 | same JSON + `stdout.log` |
| GPU metadata | `gpu.txt` in result folder |
| Reproducible commands | this plan |

---

## After baseline: Sportify pipeline comparison (future plan)

When Sportify worker exists, rerun **same clips** on **same RTX 3090** with `benchmarks/throughput/manifests/soccernet-clip.yaml`. Compare:

- `effective_fps` (Sportify vs sn-gamestate, **same hardware** — fair)
- `conditional_steps` counts (Sportify only)
- GS-HOTA optional (Sportify may score lower initially — POC gate is throughput)

---

## Document history

| Date | Change |
|------|--------|
| 2026-05-24 | Initial plan for VPS RTX 3090 baseline |
