#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required: https://docs.astral.sh/uv/" >&2
  exit 1
fi
uv venv --python 3.11
# shellcheck disable=SC1091
source .venv/bin/activate
uv pip install -r requirements.txt
python -m ipykernel install --user --name sportify-easyocr-preprocess-ablation --display-name "Sportify EasyOCR preprocess ablation"
echo "Done. cd $(pwd) && source .venv/bin/activate"
