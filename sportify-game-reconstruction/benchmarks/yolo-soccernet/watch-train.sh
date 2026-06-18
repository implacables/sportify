#!/usr/bin/env bash
# Tail results.csv from a training run and write a per-epoch markdown table.
# Can be run while training is in progress or after it completes.
# Usage: ./watch-train.sh [--run-name NAME] [--follow]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "${REPO_ROOT}/scripts/sportify-default-data-root.sh"
sportify_ensure_data_root
DATA_ROOT="${SPORTIFY_DATA_ROOT}"

RUN_NAME="yolo26m-finetune-v1"
FOLLOW=false

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --run-name NAME    Training run name (default: yolo26m-finetune-v1)
  --follow           Keep watching and updating until training ends
  --help             Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-name) RUN_NAME="$2"; shift 2 ;;
    --follow)   FOLLOW=true; shift ;;
    -h|--help)  usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

RUNS_DIR="${DATA_ROOT}/yolo-soccernet/runs"
CSV="${RUNS_DIR}/${RUN_NAME}/results.csv"
# Write alongside the training result in benchmarks/results/
RESULTS_BASE="${REPO_ROOT}/sportify-game-reconstruction/benchmarks/results/yolo-soccernet"
OUT_MD="${RESULTS_BASE}/training-progress-${RUN_NAME}.md"

if [[ ! -f "${CSV}" ]]; then
  echo "error: results.csv not found at ${CSV}" >&2
  echo "Has training started? Run: bash run-train.sh" >&2
  exit 1
fi

generate_table() {
  python3 - "${CSV}" "${RUN_NAME}" <<'PY'
import sys, csv
from pathlib import Path

csv_path = Path(sys.argv[1])
run_name = sys.argv[2]

rows = []
with open(csv_path) as f:
    reader = csv.DictReader(f)
    for row in reader:
        rows.append(row)

if not rows:
    print("No epochs recorded yet.")
    sys.exit(0)

# Phase A baseline (pretrained yolo26m, valid-quick manifest)
BASELINE = {"mAP50": 0.9099, "mAP5095": 0.5730, "P": 0.8980, "R": 0.8920}

print(f"# yolo26m fine-tune training progress — {run_name}\n")
print(f"Phase A baseline (pretrained): mAP@0.5={BASELINE['mAP50']:.4f}  mAP@0.5:0.95={BASELINE['mAP5095']:.4f}  P={BASELINE['P']:.4f}  R={BASELINE['R']:.4f}\n")
print(f"| Epoch | Time (min) | box_loss | cls_loss | dfl_loss | P | R | mAP@0.5 | Δ mAP@0.5 | mAP@0.5:0.95 | Δ mAP@0.5:0.95 |")
print(f"|------:|-----------:|---------:|---------:|---------:|--:|--:|--------:|----------:|-------------:|---------------:|")

best_map50 = 0.0
for row in rows:
    epoch   = int(float(row["epoch"]))
    t_min   = float(row["time"]) / 60
    box     = float(row["train/box_loss"])
    cls     = float(row["train/cls_loss"])
    dfl     = float(row["train/dfl_loss"])
    p       = float(row["metrics/precision(B)"])
    r       = float(row["metrics/recall(B)"])
    map50   = float(row["metrics/mAP50(B)"])
    map5095 = float(row["metrics/mAP50-95(B)"])

    d50   = map50   - BASELINE["mAP50"]
    d5095 = map5095 - BASELINE["mAP5095"]
    best_map50 = max(best_map50, map50)

    d50_str   = f"+{d50:.4f}" if d50 >= 0 else f"{d50:.4f}"
    d5095_str = f"+{d5095:.4f}" if d5095 >= 0 else f"{d5095:.4f}"

    print(f"| {epoch:5d} | {t_min:10.1f} | {box:.4f} | {cls:.4f} | {dfl:.6f} | {p:.4f} | {r:.4f} | {map50:.4f} | {d50_str:>9} | {map5095:.4f} | {d5095_str:>14} |")

n = len(rows)
last = rows[-1]
last_map50   = float(last["metrics/mAP50(B)"])
last_map5095 = float(last["metrics/mAP50-95(B)"])
total_min = sum(float(r["time"]) for r in rows) / 60

print(f"\n**Epochs complete:** {n}  |  **Best mAP@0.5:** {best_map50:.4f}  |  **Latest mAP@0.5:** {last_map50:.4f}  |  **Total time:** {total_min:.0f} min")
PY
}

mkdir -p "${RESULTS_BASE}"

if $FOLLOW; then
  echo "==> Watching ${CSV} (Ctrl-C to stop) ..."
  LAST_LINES=0
  while true; do
    CURRENT_LINES=$(wc -l < "${CSV}")
    if [[ "${CURRENT_LINES}" -ne "${LAST_LINES}" ]]; then
      generate_table > "${OUT_MD}"
      LAST_LINES="${CURRENT_LINES}"
      echo "  updated: $(date -u +%H:%M:%SZ) — epoch $((CURRENT_LINES - 1)) written to ${OUT_MD}"
    fi
    # Stop if training process is gone
    if ! pgrep -f "run-train.sh" > /dev/null 2>&1 && ! pgrep -f "yolo.*train" > /dev/null 2>&1; then
      # Give it one final update
      generate_table > "${OUT_MD}"
      echo "  Training process ended. Final table written to ${OUT_MD}"
      break
    fi
    sleep 30
  done
else
  generate_table | tee "${OUT_MD}"
  echo ""
  echo "Written to: ${OUT_MD}"
fi
