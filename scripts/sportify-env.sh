#!/usr/bin/env bash
# Sportify environment variables — source this file, do not execute it.
#
#   source /path/to/sportify/scripts/sportify-env.sh
#
# Optional machine-specific overrides (gitignored):
#   cp scripts/sportify-env.local.sh.example scripts/sportify-env.local.sh
#   edit scripts/sportify-env.local.sh

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _hint_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Source this file instead of running it:" >&2
  echo "  source \"${_hint_dir}/sportify-env.sh\"" >&2
  exit 1
fi

_SPORTIFY_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SPORTIFY_REPO="$(cd "${_SPORTIFY_ENV_DIR}/.." && pwd)"

# shellcheck source=sportify-default-data-root.sh
source "${_SPORTIFY_ENV_DIR}/sportify-default-data-root.sh"
# Large assets live outside the repo. Override before sourcing, or in sportify-env.local.sh
sportify_ensure_data_root
export SPORTIFY_DATA_ROOT="$(cd "${SPORTIFY_DATA_ROOT}" 2>/dev/null && pwd || echo "${SPORTIFY_DATA_ROOT}")"

# SoccerNet Game State (task gamestate-2024)
export SOCNET_GS_ROOT="${SPORTIFY_DATA_ROOT}/SoccerNetGS"
export SOCNET_GS_VALID="${SOCNET_GS_ROOT}/valid"
export SOCNET_GS_TRAIN="${SOCNET_GS_ROOT}/train"

# Upstream GSR baseline clone + venv
export SN_GAMESTATE_ROOT="${SPORTIFY_DATA_ROOT}/vendor/sn-gamestate"
export SN_PRETRAINED_MODELS="${SPORTIFY_DATA_ROOT}/pretrained_models"

# Derived benchmark paths
export YOLO_SOCNET_DATASET="${SPORTIFY_DATA_ROOT}/yolo-soccernet"
export SPORTIFY_MATCHES="${SPORTIFY_DATA_ROOT}/matches"

# SoccerNet NDA password (only if downloader prompts — do not commit real values)
# export SOCCERNET_PWD="..."

# Per-machine overrides (paths, SOCCERNET_PWD, etc.)
_LOCAL_ENV="${_SPORTIFY_ENV_DIR}/sportify-env.local.sh"
if [[ -f "${_LOCAL_ENV}" ]]; then
  # shellcheck source=/dev/null
  source "${_LOCAL_ENV}"
fi

mkdir -p "${SPORTIFY_DATA_ROOT}" "${SOCNET_GS_ROOT}" "${SN_PRETRAINED_MODELS}"

sportify-env() {
  printf 'SPORTIFY_REPO=%s\n' "${SPORTIFY_REPO}"
  printf 'SPORTIFY_DATA_ROOT=%s\n' "${SPORTIFY_DATA_ROOT}"
  printf 'SOCNET_GS_ROOT=%s\n' "${SOCNET_GS_ROOT}"
  printf 'SOCNET_GS_VALID=%s\n' "${SOCNET_GS_VALID}"
  printf 'SN_GAMESTATE_ROOT=%s\n' "${SN_GAMESTATE_ROOT}"
  if [[ -n "${SOCCERNET_PWD:-}" ]]; then
    printf 'SOCCERNET_PWD=(set)\n'
  else
    printf 'SOCCERNET_PWD=(not set)\n'
  fi
}
