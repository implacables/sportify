# EasyOCR speed experiment

Benchmark EasyOCR on **sequences of 10 frames**, mimicking conditional jersey OCR: the numbered frame appears at a **random index** or **not at all** each trial.

## Setup

From this directory:

```bash
./setup.sh
# or manually:
uv venv --python 3.11 && source .venv/bin/activate
uv pip install -r requirements.txt
python -m ipykernel install --user --name sportify-easyocr-speed --display-name "Sportify EasyOCR speed"
```

First EasyOCR run downloads recognition models into `~/.EasyOCR/` (several hundred MB).

## Images

| Folder | Count | Content |
|--------|-------|---------|
| `images/base/` | **10** | Same scene type as your pipeline frames — **no** visible jersey number |
| `images/with_number/` | **≥1** | Shots with a readable number; one is chosen at random when a trial injects a number |

Supported extensions: `.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`. Base files are ordered by **sorted filename** (slot 0 … 9). Each trial either keeps all 10 base frames or **replaces one random slot** with a randomly chosen image from `with_number/`.

## Run

**Simple benchmark (recommended):**

```bash
source .venv/bin/activate
jupyter notebook easyocr_benchmark.ipynb
```

**Detailed / exploratory:** `easyocr_speed.ipynb`

Kernel: **Sportify EasyOCR speed**.

Notebook knobs:

- `P_HAS_NUMBER` — probability a trial includes the numbered frame (default `0.3`, i.e. often no OCR-worthy frame)
- `N_TRIALS` — how many random sequences to run (increase for stabler means)
- `RANDOM_SEED` — set for reproducible placement
- `IMAGE_SCALE` — upscale screenshots before OCR (default `4`; jersey digits are often unreadable at 1×)
- `OCR_KWARGS` — passed to `readtext` (`allowlist`, `mag_ratio`, contrast tuning)

Before the benchmark loop, the notebook runs a **preflight** on every `with_number/` image. If that reports `0/N`, raise `IMAGE_SCALE` or use tighter crops on the jersey.

## Outputs

Per-trial and aggregate timing, effective batch FPS (10 frames), and OCR hit rate when the number was injected.

## Server + local

Work on branch **`experiment/easyocr-speed`** on both machines (experiment code only; images stay untracked).

**Server (first time on branch):**

```bash
cd ~/sportify   # or your clone path
git fetch origin
git checkout experiment/easyocr-speed   # or: git checkout -b experiment/easyocr-speed origin/experiment/easyocr-speed
cd sportify-game-reconstruction/experiments/easyocr-speed
./setup.sh
```

**Local:**

```bash
cd ~/Documents/sportify
git checkout experiment/easyocr-speed
cd sportify-game-reconstruction/experiments/easyocr-speed
source .venv/bin/activate
```

**Sync code** (after committing on either side):

```bash
git push -u origin experiment/easyocr-speed   # first push from server or local
git pull                                       # on the other machine
```

Copy `images/base/` and `images/with_number/` between machines with `rsync` or scp — they are not in git. Example:

```bash
rsync -av sportify-game-reconstruction/experiments/easyocr-speed/images/ user@server:~/sportify/sportify-game-reconstruction/experiments/easyocr-speed/images/
```
