#!/usr/bin/env bash
# YOLO person-detection throughput benchmark.
# Runs inference on a clip's raw frames and records inference_fps + GPU metadata.
# See spec.md §7 for the full benchmarking spec.
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
BATCH=1
DRY_RUN=false

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --manifest PATH    Clip manifest (default: manifests/valid-quick.yaml)
  --model NAME       YOLO weights filename (default: yolo11n.pt)
  --imgsz N          Input image size (default: 640)
  --batch N          Batch size (default: 1)
  --dry-run          Check paths without running inference
  --help             Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --model)    MODEL="$2"; shift 2 ;;
    --imgsz)    IMGSZ="$2"; shift 2 ;;
    --batch)    BATCH="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -h|--help)  usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

VENV_PYTHON="${DATA_ROOT}/vendor/yolo-bench/.venv/bin/python"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/sportify-game-reconstruction/benchmarks/results/yolo-soccernet/${TIMESTAMP}-bench"

# Parse bench clip (first clip in manifest) and split via Python (system python3 — stdlib only)
read -r BENCH_CLIP SN_SPLIT < <(python3 - "${MANIFEST}" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
clip, split = None, "valid"
in_clips = False
for line in path.read_text().splitlines():
    s = line.strip()
    if s.startswith("#"):
        continue
    if s.startswith("split:"):
        split = s.split(":", 1)[1].strip().strip('"').strip("'")
    elif s == "clips:":
        in_clips = True
    elif in_clips and s.startswith("- id:") and clip is None:
        clip = s[len("- id:"):].strip()
print(clip or "", split)
PY
)

if [[ -z "${BENCH_CLIP}" ]]; then
  echo "error: could not parse bench clip from manifest ${MANIFEST}" >&2
  exit 1
fi

CLIP_IMG_DIR="${DATA_ROOT}/SoccerNetGS/${SN_SPLIT}/${BENCH_CLIP}/img1"

if $DRY_RUN; then
  echo "==> Dry run: yolo-soccernet bench"
  echo "  DATA_ROOT:    ${DATA_ROOT}"
  echo "  MANIFEST:     ${MANIFEST}"
  echo "  BENCH_CLIP:   ${BENCH_CLIP}"
  echo "  CLIP_IMG_DIR: ${CLIP_IMG_DIR}"
  echo "  MODEL:        ${MODEL}"
  echo "  IMGSZ:        ${IMGSZ}"
  echo "  BATCH:        ${BATCH}"
  echo "  VENV:         ${VENV_PYTHON}"
  echo "  OUT_DIR:      ${OUT_DIR}"
  [[ -f "${VENV_PYTHON}" ]] && echo "  venv: found" || echo "  venv: NOT FOUND — run: make setup"
  [[ -d "${CLIP_IMG_DIR}" ]] && echo "  clip frames: found" || echo "  clip frames: NOT FOUND at ${CLIP_IMG_DIR}"
  echo "==> No changes made"
  exit 0
fi

if [[ ! -f "${VENV_PYTHON}" ]]; then
  echo "error: YOLO venv not found — run: make setup" >&2
  exit 1
fi

if [[ ! -d "${CLIP_IMG_DIR}" ]]; then
  echo "error: clip image dir not found: ${CLIP_IMG_DIR}" >&2
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

echo "==> YOLO bench: ${BENCH_CLIP} — ${MODEL}, imgsz=${IMGSZ}, batch=${BATCH}"

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
"${VENV_PYTHON}" - <<PYEOF 2>&1 | tee "${OUT_DIR}/stdout.log"
import json, sys, time
import torch
from pathlib import Path
from ultralytics import YOLO

WARMUP_N = 10
model_name  = "${MODEL}"
clip_img_dir = Path("${CLIP_IMG_DIR}")
imgsz  = ${IMGSZ}
batch  = ${BATCH}
out_dir = Path("${OUT_DIR}")

frames = sorted(clip_img_dir.glob("*.jpg"))
if not frames:
    print(f"error: no frames in {clip_img_dir}", file=sys.stderr)
    sys.exit(1)

print(f"  frames total: {len(frames)}")
print(f"  loading model: {model_name}")
model = YOLO(model_name)

print(f"  warmup: {WARMUP_N} frames")
for f in frames[:WARMUP_N]:
    model.predict(str(f), imgsz=imgsz, verbose=False)
torch.cuda.empty_cache()

print(f"  timed run: {len(frames)} frames ...")
t0 = time.perf_counter()
for f in frames:
    model.predict(str(f), imgsz=imgsz, verbose=False)
t1 = time.perf_counter()

wall = t1 - t0
fps  = len(frames) / wall
print(f"  wall_clock:    {wall:.2f}s")
print(f"  frames:        {len(frames)}")
print(f"  inference_fps: {fps:.1f}")

result = {
    "benchmark": "yolo-soccernet",
    "timestamp_utc": "${TIMESTAMP}",
    "manifest_name": Path("${MANIFEST}").stem,
    "phase": "bench",
    "model": {
        "variant": model_name.replace(".pt", ""),
        "weights": model_name,
        "imgsz": imgsz,
        "batch_size": batch,
    },
    "hardware": {
        "gpu": "${GPU_INFO}",
        "cpu": None,
        "ram_gb": None,
    },
    "metrics": {
        "clip_id": "${BENCH_CLIP}",
        "split": "${SN_SPLIT}",
        "frames_processed": len(frames),
        "wall_clock_seconds": round(wall, 3),
        "inference_fps": round(fps, 2),
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
