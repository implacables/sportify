# EasyOCR experiments

Jersey number OCR evaluation for game reconstruction (conditional trials, label ground truth **5**).

**Shared images:** [`images/`](images/) (`base/` × 10, `with_number/` ≥ 1). Each child folder uses `../images/`.

## Layout

```
experiments/easyocr/
├── images/
├── throughput-and-errors/              # speed + Type I/II + labels (text)
├── throughput-errors-and-visualization/  # same + OCR box overlays in notebook
├── preprocess-ablation/                # image preprocess A/B table
├── soccernet-gs/                       # EasyOCR on SoccerNet-GS jersey crops
└── exploratory-trial-logs/             # legacy detailed trial output
```

## Run

```bash
cd sportify-game-reconstruction/experiments/easyocr/throughput-and-errors   # pick a child
./setup.sh
source .venv/bin/activate
jupyter notebook *.ipynb
```

Use the Jupyter kernel installed by that folder’s `setup.sh`.

Branch: **`experiment/easyocr`**. Sync images:

```bash
rsync -av sportify-game-reconstruction/experiments/easyocr/images/ \
  user@server:~/sportify/sportify-game-reconstruction/experiments/easyocr/images/
```
