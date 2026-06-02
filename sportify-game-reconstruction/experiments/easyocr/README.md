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
./setup.sh
source .venv/bin/activate
jupyter notebook *.ipynb
```

Branch: **`experiment/easyocr-speed`**. Sync images:

```bash
rsync -av sportify-game-reconstruction/experiments/easyocr/images/ \
  user@server:~/sportify/sportify-game-reconstruction/experiments/easyocr/images/
```
