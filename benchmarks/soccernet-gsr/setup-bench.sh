#!/usr/bin/env bash
# One-time SoccerNet GSR benchmark environment setup.
# Installs upstream sn-gamestate under SPORTIFY_DATA_ROOT and downloads the valid split.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../scripts/sportify-default-data-root.sh
source "${REPO_ROOT}/scripts/sportify-default-data-root.sh"
SPLIT="${SPLIT:-valid}"  # valid | train | test — default valid for benchmarks

usage() {
  cat <<EOF
Usage: $0 [--data-root PATH] [--split valid|train] [--skip-download] [--low-vram]

Environment:
  SPORTIFY_DATA_ROOT   Data directory (default: /workspace if present, else ~/data/sportify)

Options:
  --data-root PATH     Override SPORTIFY_DATA_ROOT
  --split SPLIT        SoccerNet-GS split to download (default: valid)
  --skip-download      Skip dataset download (vendor install only)
  --low-vram           Patch batch sizes for GPUs with <= 8 GB VRAM
  --help               Show this help
EOF
  exit 1
}

SKIP_DOWNLOAD=false
LOW_VRAM=false
DATA_ROOT_CLI=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-root)     DATA_ROOT_CLI="$2"; shift 2 ;;
    --split)         SPLIT="$2"; shift 2 ;;
    --skip-download) SKIP_DOWNLOAD=true; shift ;;
    --low-vram)      LOW_VRAM=true; shift ;;
    -h|--help)       usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -n "${DATA_ROOT_CLI}" ]]; then
  export SPORTIFY_DATA_ROOT="${DATA_ROOT_CLI}"
else
  sportify_ensure_data_root
fi
DATA_ROOT="${SPORTIFY_DATA_ROOT}"
SN_GS="${DATA_ROOT}/vendor/sn-gamestate"
SOCNET_YAML="${SN_GS}/sn_gamestate/configs/soccernet.yaml"

if ! command -v uv >/dev/null 2>&1; then
  echo "error: uv not found. Install: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

echo "==> Data root: ${DATA_ROOT}"
mkdir -p "${DATA_ROOT}/vendor" "${DATA_ROOT}/SoccerNetGS" "${DATA_ROOT}/pretrained_models"

if [[ ! -d "${SN_GS}/.git" ]]; then
  echo "==> Cloning sn-gamestate..."
  git clone https://github.com/SoccerNet/sn-gamestate.git "${SN_GS}"
else
  echo "==> sn-gamestate already cloned at ${SN_GS}"
fi

echo "==> Creating Python 3.9 venv and installing sn-gamestate (10–30 min)..."
(
  cd "${SN_GS}"
  if [[ ! -d .venv ]]; then
    uv venv --python 3.9
  else
    echo "    .venv exists — skipping venv creation"
  fi
  uv pip install -e .
  uv run mim install mmcv==2.0.1
)

echo "==> Verifying imports..."
(
  cd "${SN_GS}"
  uv run python -c "import tracklab; import sn_gamestate; print('imports OK')"
)

echo "==> Patching ${SOCNET_YAML} paths..."
if $LOW_VRAM; then
  LOW_VRAM_PY=True
else
  LOW_VRAM_PY=False
fi
python3 - <<PY
from pathlib import Path

path = Path("${SOCNET_YAML}")
text = path.read_text()
data_root = "${DATA_ROOT}"
replacements = {
    'data_dir: "\${project_dir}/data"': f'data_dir: "{data_root}"',
    'model_dir: "\${project_dir}/pretrained_models"': f'model_dir: "{data_root}/pretrained_models"',
}
for old, new in replacements.items():
    if old in text:
        text = text.replace(old, new)
    elif new.split(": ", 1)[0] + ":" in text:
        pass  # already patched
    else:
        print(f"warning: pattern not found: {old}")

if ${LOW_VRAM_PY}:
    low_vram = {
        "bbox_detector: {batch_size: 8}": "bbox_detector: {batch_size: 2}",
        "reid: {batch_size: 64}": "reid: {batch_size: 16}",
        "track: {batch_size: 64}": "track: {batch_size: 16}",
        "jersey_number_detect: {batch_size: 8}": "jersey_number_detect: {batch_size: 2}",
    }
    for old, new in low_vram.items():
        text = text.replace(old, new)
    print("Applied low-VRAM batch sizes")

path.write_text(text)
print("Config patched")
PY

if $SKIP_DOWNLOAD; then
  echo "==> Skipping dataset download (--skip-download)"
else
  echo "==> Downloading SoccerNet-GS split: ${SPLIT}"
  (
    cd "${SN_GS}"
    export SPORTIFY_DATA_ROOT="${DATA_ROOT}"
    export SPLIT="${SPLIT}"
    uv run python <<'PY'
import os
from SoccerNet.Downloader import SoccerNetDownloader

data_root = os.environ["SPORTIFY_DATA_ROOT"]
split = os.environ.get("SPLIT", "valid")
dl = SoccerNetDownloader(LocalDirectory=f"{data_root}/SoccerNetGS")
dl.downloadDataTask(task="gamestate-2024", split=[split])
print(f"download task finished for split={split}")
PY
  )

  ZIP="${DATA_ROOT}/SoccerNetGS/gamestate-2024/${SPLIT}.zip"
  DEST="${DATA_ROOT}/SoccerNetGS/${SPLIT}"
  if [[ -f "${ZIP}" ]]; then
    echo "==> Extracting ${ZIP} -> ${DEST}"
    mkdir -p "${DEST}"
    if command -v unzip >/dev/null 2>&1; then
      unzip -o -q "${ZIP}" -d "${DEST}"
    else
      echo "    (unzip not found — using Python zipfile)"
      _ZIP="${ZIP}" _DEST="${DEST}" python3 <<'PY'
import os
import zipfile
from pathlib import Path

zip_path = Path(os.environ["_ZIP"])
dest = Path(os.environ["_DEST"])
dest.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(dest)
print(f"extracted {len(zf.namelist())} entries -> {dest}")
PY
    fi
  else
    echo "warning: zip not found at ${ZIP} — dataset may already be extracted or download failed"
  fi

  echo "==> Checking dataset version..."
  python3 - <<PY
import json, glob, sys
labels = glob.glob("${DATA_ROOT}/SoccerNetGS/${SPLIT}/**/Labels-GameState.json", recursive=True)
if not labels:
    print("warning: no Labels-GameState.json found under ${DATA_ROOT}/SoccerNetGS/${SPLIT}")
    sys.exit(0)
v = json.load(open(labels[0]))["info"]["version"]
print(f"dataset version: {v}")
if float(v) < 1.3:
    print(f"error: need dataset version >= 1.3, got {v}", file=sys.stderr)
    sys.exit(1)
PY
fi

echo ""
echo "Setup complete."
echo "  SPORTIFY_DATA_ROOT=${DATA_ROOT}"
echo "  sn-gamestate:     ${SN_GS}"
echo ""
echo "Next steps:"
echo "  export SPORTIFY_DATA_ROOT=${DATA_ROOT}"
echo "  ${REPO_ROOT}/benchmarks/soccernet-gsr/run-baseline.sh --manifest ${REPO_ROOT}/benchmarks/soccernet-gsr/manifests/valid-quick.yaml"
echo ""
echo "Smoke test (100 frames, from vendor dir):"
echo "  cd ${SN_GS} && uv run tracklab -cn soccernet dataset.eval_set=valid dataset.nvid=1 'dataset.vids_dict.valid=[SNGS-021]' dataset.nframes=100 visualization.cfg.save_videos=False eval_tracking=True"
