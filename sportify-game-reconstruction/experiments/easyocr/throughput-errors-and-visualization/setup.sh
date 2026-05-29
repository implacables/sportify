#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
_REPO_ROOT="$(cd ../../../.. && pwd)"
# shellcheck source=../../../../scripts/sportify-check-requirements.sh
source "${_REPO_ROOT}/scripts/sportify-check-requirements.sh"
sportify_check_requirements easyocr || exit 1
uv venv --python 3.11
# shellcheck disable=SC1091
source .venv/bin/activate
uv pip install -r requirements.txt
python -m ipykernel install --user --name sportify-easyocr-throughput-viz --display-name "Sportify EasyOCR throughput viz"
echo "Done. cd $(pwd) && source .venv/bin/activate"
