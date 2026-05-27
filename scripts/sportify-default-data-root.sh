# Default SPORTIFY_DATA_ROOT for bash scripts. Source this file; do not execute.
#
# When /workspace exists (cloud agents), use it unless you set a custom path
# and export SPORTIFY_DATA_ROOT_FORCE=1.

sportify_is_legacy_data_root() {
  local p="${1%/}"
  [[ -z "$p" ]] && return 0
  [[ "$p" == "${HOME}/data/sportify" ]] && return 0
  [[ "$p" == "/root/data/sportify" ]] && return 0
  return 1
}

sportify_default_data_root() {
  if [[ -d /workspace ]]; then
    printf '%s\n' /workspace
    return 0
  fi
  printf '%s\n' "${HOME}/data/sportify"
}

sportify_ensure_data_root() {
  if [[ -n "${SPORTIFY_DATA_ROOT_FORCE:-}" ]]; then
    if [[ -z "${SPORTIFY_DATA_ROOT:-}" ]]; then
      export SPORTIFY_DATA_ROOT="$(sportify_default_data_root)"
    fi
    return 0
  fi

  if [[ -d /workspace ]]; then
    if [[ -z "${SPORTIFY_DATA_ROOT:-}" ]] || sportify_is_legacy_data_root "${SPORTIFY_DATA_ROOT}"; then
      if [[ -n "${SPORTIFY_DATA_ROOT:-}" ]]; then
        echo "sportify: SPORTIFY_DATA_ROOT -> /workspace (was ${SPORTIFY_DATA_ROOT})" >&2
      fi
      export SPORTIFY_DATA_ROOT=/workspace
      return 0
    fi
  fi

  if [[ -z "${SPORTIFY_DATA_ROOT:-}" ]]; then
    export SPORTIFY_DATA_ROOT="$(sportify_default_data_root)"
  fi
}
