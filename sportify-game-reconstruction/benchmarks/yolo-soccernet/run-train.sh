#!/usr/bin/env bash
# Fine-tune a YOLO model on the SoccerNet-GS training split.
# Writes best.pt to $DATA_ROOT/yolo-soccernet/runs/<run-name>/weights/best.pt
# See spec.md §8 for the full training protocol.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "${REPO_ROOT}/scripts/sportify-default-data-root.sh"
sportify_ensure_data_root
DATA_ROOT="${SPORTIFY_DATA_ROOT}"

MODEL="yolo26m.pt"
IMGSZ=640
BATCH=16
EPOCHS=50
PATIENCE=10
RUN_NAME="yolo26m-finetune-v1"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --model NAME       Init weights filename (default: yolo26m.pt)
  --imgsz N          Input image size (default: 640)
  --batch N          Batch size (default: 16)
  --epochs N         Max epochs (default: 50)
  --patience N       Early-stop patience (default: 10)
  --run-name NAME    Experiment name under yolo-soccernet/runs/ (default: yolo26m-finetune-v1)
  --help             Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)     MODEL="$2"; shift 2 ;;
    --imgsz)     IMGSZ="$2"; shift 2 ;;
    --batch)     BATCH="$2"; shift 2 ;;
    --epochs)    EPOCHS="$2"; shift 2 ;;
    --patience)  PATIENCE="$2"; shift 2 ;;
    --run-name)  RUN_NAME="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

VENV_PYTHON="${DATA_ROOT}/vendor/yolo-bench/.venv/bin/python"
DATA_YAML="${DATA_ROOT}/yolo-soccernet/data.yaml"
RUNS_DIR="${DATA_ROOT}/yolo-soccernet/runs"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/sportify-game-reconstruction/benchmarks/results/yolo-soccernet/${TIMESTAMP}-train"

if [[ ! -f "${VENV_PYTHON}" ]]; then
  echo "error: YOLO venv not found — run: make setup" >&2
  exit 1
fi

if [[ ! -f "${DATA_YAML}" ]]; then
  echo "error: data.yaml not found at ${DATA_YAML}" >&2
  echo "Run: make convert" >&2
  exit 1
fi

if [[ ! -d "${DATA_ROOT}/yolo-soccernet/images/train" ]]; then
  echo "error: training images not found at ${DATA_ROOT}/yolo-soccernet/images/train" >&2
  echo "Convert training clips first (see convert_to_yolo.py --yolo-split train)" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

GPU_INFO="none"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  nvidia-smi > "${OUT_DIR}/gpu.txt" 2>&1 || true
  GPU_INFO="$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null | head -1 | xargs || echo unknown)"
fi
echo "  GPU: ${GPU_INFO}"

echo "==> YOLO train: ${MODEL}, imgsz=${IMGSZ}, batch=${BATCH}, epochs=${EPOCHS}, patience=${PATIENCE}"
echo "    run name: ${RUN_NAME}"

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
"${VENV_PYTHON}" - <<PYEOF 2>&1 | tee "${OUT_DIR}/stdout.log"
import json
from pathlib import Path
from ultralytics import YOLO

model_name = "${MODEL}"
data_yaml  = "${DATA_YAML}"
imgsz      = ${IMGSZ}
batch      = ${BATCH}
epochs     = ${EPOCHS}
patience   = ${PATIENCE}
runs_dir   = "${RUNS_DIR}"
run_name   = "${RUN_NAME}"
out_dir    = Path("${OUT_DIR}")

print(f"  model:     {model_name}")
print(f"  data.yaml: {data_yaml}")
print(f"  imgsz:     {imgsz}, batch: {batch}, epochs: {epochs}, patience: {patience}")
print(f"  runs dir:  {runs_dir}/{run_name}")

model = YOLO(model_name)
results = model.train(
    data=data_yaml,
    imgsz=imgsz,
    epochs=epochs,
    batch=batch,
    patience=patience,
    project=runs_dir,
    name=run_name,
    exist_ok=True,
    device=0,
    verbose=True,
)

best_pt = Path(runs_dir) / run_name / "weights" / "best.pt"
print(f"  best.pt: {best_pt}")
print(f"  best.pt exists: {best_pt.exists()}")

result = {
    "benchmark": "yolo-soccernet",
    "timestamp_utc": "${TIMESTAMP}",
    "manifest_name": "valid-train-split",
    "phase": "train",
    "model": {
        "variant": model_name.replace(".pt", ""),
        "weights": model_name,
        "imgsz": imgsz,
        "batch_size": batch,
        "epochs_requested": epochs,
        "patience": patience,
        "best_pt": str(best_pt),
    },
    "hardware": {
        "gpu": "${GPU_INFO}",
        "cpu": None,
        "ram_gb": None,
    },
    "metrics": {
        "clip_id": None,
        "split": "train",
        "frames_processed": None,
        "wall_clock_seconds": None,
        "inference_fps": None,
        "map50": None,
        "map50_95": None,
        "precision": None,
        "recall": None,
    },
    "status": "finished",
}
(out_dir / "run-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(f"  result written: {out_dir}/run-result.json")
PYEOF

echo "Done — results in ${OUT_DIR}"
