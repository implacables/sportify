# Default SPORTIFY_DATA_ROOT for bash scripts. Source this file; do not execute.
#
# Priority:
#   1. SPORTIFY_DATA_ROOT already set in the environment
#   2. /workspace (Cursor / cloud agent workspaces)
#   3. ~/data/sportify (local laptop / VPS)

sportify_default_data_root() {
  if [[ -n "${SPORTIFY_DATA_ROOT:-}" ]]; then
    printf '%s\n' "${SPORTIFY_DATA_ROOT}"
    return 0
  fi
  if [[ -d /workspace ]]; then
    printf '%s\n' /workspace
    return 0
  fi
  printf '%s\n' "${HOME}/data/sportify"
}

sportify_ensure_data_root() {
  if [[ -z "${SPORTIFY_DATA_ROOT:-}" ]]; then
    export SPORTIFY_DATA_ROOT="$(sportify_default_data_root)"
  fi
}
