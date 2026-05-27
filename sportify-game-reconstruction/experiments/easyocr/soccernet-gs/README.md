# EasyOCR on SoccerNet-GS

Jersey number OCR benchmark on **SoccerNet Game State** validation clips: crop GT player boxes, run EasyOCR, report accuracy and throughput.

| Doc | Purpose |
|-----|---------|
| [investigation.md](investigation.md) | Sampling, metrics, label schema |
| [easyocr_soccernet_gs.ipynb](easyocr_soccernet_gs.ipynb) | Runnable bench |
| [Data layout](../../../../docs/data-layout.md) | **`SPORTIFY_DATA_ROOT`** and where SoccerNet lives |

## Data (required)

You need the **SoccerNet-GS valid split** on disk (not in git). Set one env var:

```bash
export SPORTIFY_DATA_ROOT="$HOME/data/sportify"   # pick a path with enough disk
```

Dataset path (fixed relative to that root):

```text
$SPORTIFY_DATA_ROOT/SoccerNetGS/valid/SNGS-021/Labels-GameState.json
```

Download and extract from the **repo root**:

```bash
benchmarks/soccernet-gsr/setup-bench.sh
```

See [docs/data-layout.md](../../../../docs/data-layout.md) for the full tree, manual unzip, and VPS notes.

## Run notebook

```bash
cd sportify-game-reconstruction/experiments/easyocr/soccernet-gs
./setup.sh && source .venv/bin/activate
# ensure SPORTIFY_DATA_ROOT is set in this shell before jupyter
jupyter notebook easyocr_soccernet_gs.ipynb
```

Kernel: **Sportify EasyOCR SoccerNet-GS**. Default clips: `SNGS-021`–`023` ([valid-quick manifest](../../../../benchmarks/soccernet-gsr/manifests/valid-quick.yaml)).

If auto-detect fails, set `DATA_ROOT_OVERRIDE` in the notebook’s first code cell.
