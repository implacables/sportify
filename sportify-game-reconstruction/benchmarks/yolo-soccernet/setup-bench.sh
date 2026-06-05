#!/usr/bin/env bash
# One-time YOLO SoccerNet benchmark setup: create Ultralytics venv.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# shellcheck source=../../../scripts/sportify-default-data-root.sh
source "${REPO_ROOT}/scripts/sportify-default-data-root.sh"

usage() {
  cat <<EOF
Usage: $0 [--data-root PATH]

Environment:
  SPORTIFY_DATA_ROOT   Data directory (default: /workspace if present, else ~/data/sportify)

Options:
  --data-root PATH     Override SPORTIFY_DATA_ROOT
  --help               Show this help
EOF
  exit 1
}

DATA_ROOT_CLI=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-root) DATA_ROOT_CLI="$2"; shift 2 ;;
    -h|--help)   usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -n "${DATA_ROOT_CLI}" ]]; then
  export SPORTIFY_DATA_ROOT="${DATA_ROOT_CLI}"
else
  sportify_ensure_data_root
fi
DATA_ROOT="${SPORTIFY_DATA_ROOT}"

# shellcheck source=../../../scripts/sportify-check-requirements.sh
source "${REPO_ROOT}/scripts/sportify-check-requirements.sh"
sportify_check_requirements yolo-bench --data-root "${DATA_ROOT}" || exit 1

VENV_DIR="${DATA_ROOT}/vendor/yolo-bench"
mkdir -p "${VENV_DIR}"

echo "==> Creating Python 3.10 venv at ${VENV_DIR}/.venv ..."
if [[ ! -f "${VENV_DIR}/.venv/pyvenv.cfg" ]]; then
  uv venv --python 3.10 "${VENV_DIR}/.venv"
else
  echo "    .venv exists — skipping venv creation"
fi

echo "==> Installing Ultralytics ..."
uv pip install --python "${VENV_DIR}/.venv/bin/python" ultralytics

echo "==> Verifying import ..."
"${VENV_DIR}/.venv/bin/python" -c "import ultralytics; print(f'ultralytics {ultralytics.__version__} OK')"

echo ""
echo "Setup complete."
echo "  SPORTIFY_DATA_ROOT: ${DATA_ROOT}"
echo "  VENV:               ${VENV_DIR}/.venv"
echo ""
echo "Next steps:"
echo "  cd ${REPO_ROOT}/sportify-game-reconstruction/benchmarks/yolo-soccernet"
echo "  make convert        # convert SoccerNetGS labels to YOLO format"
echo "  make bench          # run inference throughput benchmark"
echo "  make eval           # run mAP evaluation (requires convert first)"
