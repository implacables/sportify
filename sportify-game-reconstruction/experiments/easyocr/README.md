# EasyOCR experiments

Jersey number OCR evaluation for game reconstruction (conditional trials, label ground truth **5**).

**Shared images:** [`images/`](images/) (`base/` × 10, `with_number/` ≥ 1). Each child folder uses `../images/`.

## Layout

```
experiments/easyocr/
├── images/
├── synthetic/      # throughput + Type I/II errors + preprocessing ablation on local images
└── soccernet-gs/   # throughput + accuracy on SoccerNet-GS jersey crops
```

## Run

```bash
cd sportify-game-reconstruction/experiments/easyocr/synthetic   # or soccernet-gs
make setup
source .venv/bin/activate
jupyter notebook *.ipynb
```

`make setup` checks OS (Linux or macOS), RAM (≥ 8 GB), disk (≥ 2 GB), `git`, `uv`, and Python 3.11 before creating the venv. Run `make dry-run` first to check prerequisites without installing anything. Run `make clean` to remove the venv.

Sync images:

```bash
rsync -av sportify-game-reconstruction/experiments/easyocr/images/ \
  user@server:~/sportify/sportify-game-reconstruction/experiments/easyocr/images/
```
