#!/usr/bin/env bash
# YOLO person-detection mAP evaluation on SoccerNet-GS clips.
# Requires: make setup && make convert
# See spec.md §6 for the full evaluation spec.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/sportify-default-data-root.sh
source "${REPO_ROOT}/scripts/sportify-default-data-root.sh"
sportify_ensure_data_root
DATA_ROOT="${SPORTIFY_DATA_ROOT}"

MANIFEST="${SCRIPT_DIR}/manifests/valid-quick.yaml"
MODEL="yolo11n.pt"
IMGSZ=640
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --manifest PATH    Clip manifest (default: manifests/valid-quick.yaml)
  --model NAME       YOLO weights filename (default: yolo11n.pt)
  --imgsz N          Input image size (default: 640)
  --dry-run          Check paths without running eval
  --help             Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --model)    MODEL="$2"; shift 2 ;;
    --imgsz)    IMGSZ="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -h|--help)  usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

VENV_PYTHON="${DATA_ROOT}/vendor/yolo-bench/.venv/bin/python"
DATA_YAML="${DATA_ROOT}/yolo-soccernet/data.yaml"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/sportify-game-reconstruction/benchmarks/results/yolo-soccernet/${TIMESTAMP}-eval"

if $DRY_RUN; then
  echo "==> Dry run: yolo-soccernet eval"
  echo "  DATA_ROOT:  ${DATA_ROOT}"
  echo "  MANIFEST:   ${MANIFEST}"
  echo "  MODEL:      ${MODEL}"
  echo "  IMGSZ:      ${IMGSZ}"
  echo "  DATA_YAML:  ${DATA_YAML}"
  echo "  VENV:       ${VENV_PYTHON}"
  echo "  OUT_DIR:    ${OUT_DIR}"
  [[ -f "${VENV_PYTHON}" ]] && echo "  venv:       found" || echo "  venv:       NOT FOUND — run: make setup"
  [[ -f "${DATA_YAML}" ]]   && echo "  data.yaml:  found" || echo "  data.yaml:  NOT FOUND — run: make convert"
  echo "==> No changes made"
  exit 0
fi

if [[ ! -f "${VENV_PYTHON}" ]]; then
  echo "error: YOLO venv not found — run: make setup" >&2
  exit 1
fi

if [[ ! -f "${DATA_YAML}" ]]; then
  echo "error: data.yaml not found at ${DATA_YAML}" >&2
  echo "Run: make convert" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"
cp "${MANIFEST}" "${OUT_DIR}/manifest.yaml"

GPU_INFO="none"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  nvidia-smi > "${OUT_DIR}/gpu.txt" 2>&1 || true
  GPU_INFO="$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null | head -1 | xargs || echo unknown)"
fi
echo "  GPU: ${GPU_INFO}"

echo "==> YOLO eval: ${MODEL} on $(basename "${DATA_YAML}") (imgsz=${IMGSZ})"

"${VENV_PYTHON}" - <<PYEOF 2>&1 | tee "${OUT_DIR}/stdout.log"
import json, sys, shutil
from pathlib import Path
from ultralytics import YOLO

model_name = "${MODEL}"
data_yaml  = "${DATA_YAML}"
imgsz      = ${IMGSZ}
out_dir    = Path("${OUT_DIR}")

print(f"  model:     {model_name}")
print(f"  data.yaml: {data_yaml}")
print(f"  imgsz:     {imgsz}")

model = YOLO(model_name)
metrics = model.val(
    data=data_yaml,
    imgsz=imgsz,
    verbose=True,
    project=str(out_dir),
    name="ultralytics-val",
    exist_ok=True,
)

def safe_float(obj, attr):
    try:
        v = getattr(obj, attr, None)
        return float(v) if v is not None else None
    except Exception:
        return None

box      = getattr(metrics, "box", None)
map50    = safe_float(box, "map50")
map50_95 = safe_float(box, "map")
precision = safe_float(box, "mp")
recall    = safe_float(box, "mr")

def fmt(label, v):
    return f"  {label}: {v:.4f}" if v is not None else f"  {label}: N/A"

print(fmt("mAP@0.5     ", map50))
print(fmt("mAP@0.5:0.95", map50_95))
print(fmt("precision   ", precision))
print(fmt("recall      ", recall))

result = {
    "benchmark": "yolo-soccernet",
    "timestamp_utc": "${TIMESTAMP}",
    "manifest_name": Path("${MANIFEST}").stem,
    "phase": "eval",
    "model": {
        "variant": model_name.replace(".pt", ""),
        "weights": model_name,
        "imgsz": imgsz,
    },
    "hardware": {
        "gpu": "${GPU_INFO}",
        "cpu": None,
        "ram_gb": None,
    },
    "metrics": {
        "clip_id": None,
        "split": "valid",
        "frames_processed": None,
        "wall_clock_seconds": None,
        "inference_fps": None,
        "map50":     round(map50, 6)     if map50    is not None else None,
        "map50_95":  round(map50_95, 6)  if map50_95 is not None else None,
        "precision": round(precision, 6) if precision is not None else None,
        "recall":    round(recall, 6)    if recall   is not None else None,
    },
    "status": "finished",
}
(out_dir / "run-result.json").write_text(json.dumps(result, indent=2) + "\n")
print(f"  result written: {out_dir}/run-result.json")
PYEOF

echo "Done — results in ${OUT_DIR}"
