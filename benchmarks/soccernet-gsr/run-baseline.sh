#!/usr/bin/env bash
# Run SoccerNet GSR official baseline and capture timing + metrics under benchmarks/results/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DATA_ROOT="${SPORTIFY_DATA_ROOT:-$HOME/data/sportify}"
SN_GS="${DATA_ROOT}/vendor/sn-gamestate"
MANIFEST="${SCRIPT_DIR}/manifests/valid-quick.yaml"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="${REPO_ROOT}/benchmarks/results/soccernet-gsr/${TIMESTAMP}"

usage() {
  echo "Usage: $0 [--manifest PATH] [--dry-run]"
  echo "  Requires sn-gamestate cloned at: ${SN_GS}"
  exit 1
}

DRY_RUN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest) MANIFEST="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=true; shift ;;
    -h|--help)  usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ ! -d "$SN_GS" ]]; then
  echo "error: sn-gamestate not found at ${SN_GS}" >&2
  echo "See benchmarks/soccernet-gsr/README.md for setup." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
cp "$MANIFEST" "$OUT_DIR/manifest.yaml"
cp "${REPO_ROOT}/benchmarks/config/reference.yaml" "$OUT_DIR/reference.yaml"

meta() {
  cat > "$OUT_DIR/run-meta.json" <<EOF
{
  "benchmark": "soccernet-gsr",
  "timestamp_utc": "${TIMESTAMP}",
  "manifest": "$(basename "$MANIFEST")",
  "sn_gamestate_path": "${SN_GS}",
  "data_root": "${DATA_ROOT}",
  "status": "started"
}
EOF
}

meta

if $DRY_RUN; then
  echo "dry-run: would run tracklab in ${SN_GS}, output -> ${OUT_DIR}"
  exit 0
fi

START_SEC=$(date +%s)
(
  cd "$SN_GS"
  uv run tracklab -cn soccernet
) 2>&1 | tee "$OUT_DIR/stdout.log"
END_SEC=$(date +%s)
WALL=$((END_SEC - START_SEC))

# Upstream writes under sn-gamestate/output/; symlink latest for convenience
LATEST_OUTPUT="$(find "$SN_GS/output" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)"
if [[ -n "$LATEST_OUTPUT" ]]; then
  ln -sfn "$LATEST_OUTPUT" "$OUT_DIR/upstream-output"
fi

python3 - <<PY
import json
from pathlib import Path

out = Path("${OUT_DIR}/run-meta.json")
meta = json.loads(out.read_text())
meta["status"] = "finished"
meta["wall_clock_seconds"] = ${WALL}
meta["notes"] = "Parse GS-HOTA from stdout.log or upstream eval/ folder; effective_fps requires frames_processed from manifest"
out.write_text(json.dumps(meta, indent=2) + "\n")
PY

echo "Done. wall_clock=${WALL}s — results in ${OUT_DIR}"
