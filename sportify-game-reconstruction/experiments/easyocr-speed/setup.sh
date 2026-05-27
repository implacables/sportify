#!/usr/bin/env bash
# Create venv and install deps for easyocr_speed.ipynb
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install: https://docs.astral.sh/uv/" >&2
  exit 1
fi

uv venv --python 3.11
# shellcheck disable=SC1091
source .venv/bin/activate
uv pip install -r requirements.txt
python -m ipykernel install --user --name sportify-easyocr-speed --display-name "Sportify EasyOCR speed"
echo "Done. Activate with: source .venv/bin/activate"
