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
| `images/with_number/` | **≥1** | Shots with jersey **5** (set `EXPECTED_JERSEY` in the notebook); one is chosen at random per injected trial |

Supported extensions: `.png`, `.jpg`, `.jpeg`, `.webp`, `.bmp`. Base files are ordered by **sorted filename** (slot 0 … 9). Each trial either keeps all 10 base frames or **replaces one random slot** with a randomly chosen image from `with_number/`.

## Run

**Full benchmark (recommended):**

```bash
source .venv/bin/activate
jupyter notebook easyocr_bench.ipynb
```

Speed, Type I/II, jersey label checks, wrong-file lists, and **in-notebook** OCR box overlays on failures (nothing saved to disk).

**Preprocessing A/B (comparison table):** `easyocr_preprocess_ab.ipynb`  
**Quick text-only:** `easyocr_benchmark.ipynb`  
**Legacy / exploratory:** `easyocr_speed.ipynb`

Kernel: **Sportify EasyOCR speed**.

Notebook knobs (`easyocr_bench.ipynb`):

- `P_HAS_NUMBER` — probability a trial includes the numbered frame (default `0.3`)
- `N_TRIALS` — random sequences to run (increase for stabler means)
- `RANDOM_SEED` — reproducible placement
- `EXPECTED_JERSEY` — label ground truth for `with_number/` (default `"5"`)
- `IMAGE_SCALE` — upscale before OCR (default `4`)
- `OCR_KWARGS` — `readtext` options (`allowlist`, `mag_ratio`, contrast)
- `MAX_DISPLAY` — cap on failure images shown with boxes (default `30`)

**Preprocessing A/B** (`easyocr_preprocess_ab.ipynb`): runs `none`, `invert`, `clahe`, `clahe_invert`, `hsv_v` on the **same trials** and prints a comparison table (speed, Type I/II, preflight accuracy, deltas vs `none`).

Preflight scans every `with_number/` image before trials. If all show `(none)`, raise `IMAGE_SCALE` or crop tighter on the jersey.

## Outputs

- Plain-text summary: speed, Type I/II, label errors, wrong-file lists
- Annotated failure images displayed inline (PIL boxes on the upscaled frame OCR used)

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
