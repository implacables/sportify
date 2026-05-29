#!/usr/bin/env bash
# Sportify minimum requirements checks — source and call sportify_check_requirements.
#
#   source /path/to/sportify/scripts/sportify-check-requirements.sh
#   sportify_check_requirements gsr-setup --data-root "$SPORTIFY_DATA_ROOT"
#
# Profiles: common | easyocr | gsr-setup | gsr-run

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _hint_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "Source this file instead of running it:" >&2
  echo "  source \"${_hint_dir}/sportify-check-requirements.sh\"" >&2
  echo "  sportify_check_requirements <profile> [--data-root PATH] [--skip-download]" >&2
  exit 1
fi

# --- thresholds (documented in benchmarks/soccernet-gsr/README.md) ---
_SPORTIFY_MIN_DISK_GSR_FULL=$((50 * 1024 * 1024 * 1024))      # valid + weights + venv
_SPORTIFY_MIN_DISK_GSR_VENDOR=$((15 * 1024 * 1024 * 1024))    # --skip-download
_SPORTIFY_MIN_DISK_GSR_RUN=$((10 * 1024 * 1024 * 1024))
_SPORTIFY_MIN_DISK_EASYOCR=$((2 * 1024 * 1024 * 1024))
_SPORTIFY_MIN_RAM_GSR=$((16 * 1024 * 1024 * 1024))
_SPORTIFY_MIN_RAM_EASYOCR=$((8 * 1024 * 1024 * 1024))
_SPORTIFY_MIN_VRAM_MB=8192
_SPORTIFY_REC_VRAM_MB=24576
_SPORTIFY_MIN_BASH_MAJOR=4

_SPORTIFY_REQ_ERRORS=0
_SPORTIFY_REQ_WARNS=0

sportify_req_fail() {
  echo "error: $*" >&2
  _SPORTIFY_REQ_ERRORS=$((_SPORTIFY_REQ_ERRORS + 1))
}

sportify_req_warn() {
  echo "warning: $*" >&2
  _SPORTIFY_REQ_WARNS=$((_SPORTIFY_REQ_WARNS + 1))
}

sportify_req_human_bytes() {
  local bytes="$1"
  if ((bytes >= 1024 * 1024 * 1024)); then
    printf '%s GB' "$((bytes / 1024 / 1024 / 1024))"
  elif ((bytes >= 1024 * 1024)); then
    printf '%s MB' "$((bytes / 1024 / 1024))"
  else
    printf '%s KB' "$((bytes / 1024))"
  fi
}

sportify_os_id() {
  local sys
  sys="$(uname -s 2>/dev/null || echo unknown)"
  case "$sys" in
    Linux)  printf '%s\n' linux ;;
    Darwin) printf '%s\n' darwin ;;
    *)      printf '%s\n' "$sys" ;;
  esac
}

sportify_os_pretty() {
  local os
  os="$(sportify_os_id)"
  case "$os" in
    linux)  printf 'Linux (%s)\n' "$(uname -r 2>/dev/null || echo unknown)" ;;
    darwin) printf 'macOS (%s)\n' "$(sw_vers -productVersion 2>/dev/null || uname -r)" ;;
    *)      printf '%s\n' "$(uname -srm 2>/dev/null || echo unknown)" ;;
  esac
}

sportify_bytes_free() {
  local target="${1:-.}"
  if [[ ! -e "$target" ]]; then
    mkdir -p "$target" 2>/dev/null || true
  fi
  if [[ ! -e "$target" ]]; then
    sportify_req_fail "disk check path does not exist: ${target}"
    printf '0\n'
    return 1
  fi
  python3 - "$target" <<'PY'
import shutil
import sys
from pathlib import Path

path = Path(sys.argv[1]).resolve()
if path.is_file():
    path = path.parent
path.mkdir(parents=True, exist_ok=True)
print(shutil.disk_usage(path).free)
PY
}

sportify_ram_bytes_available() {
  local os
  os="$(sportify_os_id)"
  case "$os" in
    linux)
      if [[ -r /proc/meminfo ]]; then
        awk '/^MemAvailable:/ { print $2 * 1024; exit }' /proc/meminfo
        return 0
      fi
      ;;
    darwin)
      local pages page_size
      pages="$(vm_stat 2>/dev/null | awk '/Pages free/ { gsub(/\./, "", $3); print $3 }')"
      page_size="$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)"
      if [[ -n "$pages" ]]; then
        echo $((pages * page_size))
        return 0
      fi
      local total
      total="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
      printf '%s\n' "$total"
      return 0
      ;;
  esac
  printf '0\n'
  return 1
}

sportify_check_command() {
  local cmd="$1"
  local hint="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  sportify_req_fail "missing command: ${cmd}${hint:+ — }${hint}"
  return 1
}

sportify_check_bash() {
  if [[ -z "${BASH_VERSION:-}" ]]; then
    sportify_req_fail "must be run under bash (not sh)"
    return 1
  fi
  if ((BASH_VERSINFO[0] < _SPORTIFY_MIN_BASH_MAJOR)); then
    sportify_req_fail "bash ${_SPORTIFY_MIN_BASH_MAJOR}+ required (got ${BASH_VERSION}). On macOS: brew install bash"
    return 1
  fi
}

sportify_check_disk_at_least() {
  local path="$1"
  local min_bytes="$2"
  local label="$3"
  local free
  free="$(sportify_bytes_free "$path" 2>/dev/null | tail -1)"
  if [[ -z "$free" || ! "$free" =~ ^[0-9]+$ ]]; then
    sportify_req_fail "could not measure free disk at ${path}"
    return 1
  fi
  if ((free < min_bytes)); then
    sportify_req_fail "${label}: need $(sportify_req_human_bytes "$min_bytes") free at ${path}, have $(sportify_req_human_bytes "$free")"
    return 1
  fi
  echo "  disk ${path}: $(sportify_req_human_bytes "$free") free (need $(sportify_req_human_bytes "$min_bytes"))"
}

sportify_check_ram_at_least() {
  local min_bytes="$1"
  local label="$2"
  local avail
  avail="$(sportify_ram_bytes_available 2>/dev/null | tail -1)"
  if [[ -z "$avail" || ! "$avail" =~ ^[0-9]+$ ]]; then
    sportify_req_warn "${label}: could not detect RAM; ensure $(sportify_req_human_bytes "$min_bytes")+ available"
    return 0
  fi
  if ((avail < min_bytes)); then
    sportify_req_fail "${label}: need $(sportify_req_human_bytes "$min_bytes") RAM available, detected $(sportify_req_human_bytes "$avail")"
    return 1
  fi
  echo "  RAM available: $(sportify_req_human_bytes "$avail") (need $(sportify_req_human_bytes "$min_bytes"))"
}

sportify_check_nvidia_gpu() {
  local require_gpu="${1:-true}"
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    if [[ "$require_gpu" == true ]]; then
      sportify_req_fail "nvidia-smi not found — SoccerNet GSR baseline needs an NVIDIA GPU on Linux"
    else
      sportify_req_warn "nvidia-smi not found (optional for this step)"
    fi
    return 1
  fi
  if ! nvidia-smi >/dev/null 2>&1; then
    sportify_req_fail "nvidia-smi failed — check NVIDIA driver installation"
    return 1
  fi
  local name vram_mb driver
  name="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | xargs)"
  vram_mb="$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')"
  driver="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | xargs)"
  if [[ -z "$vram_mb" || ! "$vram_mb" =~ ^[0-9]+$ ]]; then
    sportify_req_warn "could not read GPU VRAM from nvidia-smi"
    echo "  GPU: ${name:-unknown} (driver ${driver:-unknown})"
    return 0
  fi
  echo "  GPU: ${name} — ${vram_mb} MiB VRAM (driver ${driver})"
  if ((vram_mb < _SPORTIFY_MIN_VRAM_MB)); then
    sportify_req_fail "GPU VRAM ${vram_mb} MiB < minimum ${_SPORTIFY_MIN_VRAM_MB} MiB (try setup-bench.sh --low-vram on 8 GB cards)"
  elif ((vram_mb < _SPORTIFY_REC_VRAM_MB)); then
    sportify_req_warn "GPU VRAM ${vram_mb} MiB < recommended ${_SPORTIFY_REC_VRAM_MB} MiB — use --low-vram if you hit OOM"
  fi
}

sportify_check_uv_python() {
  local version="$1"
  if ! command -v uv >/dev/null 2>&1; then
    return 1
  fi
  if uv python find "$version" >/dev/null 2>&1; then
    echo "  Python ${version}: $(uv python find "$version" 2>/dev/null)"
    return 0
  fi
  sportify_req_warn "Python ${version} not installed yet — run: uv python install ${version}"
}

sportify_check_common() {
  sportify_check_bash
  sportify_check_command git "https://git-scm.com/downloads"
  sportify_check_command uv "https://docs.astral.sh/uv/"
  sportify_check_command python3 "system Python 3 for config patching"
}

sportify_check_os_linux_only() {
  local os
  os="$(sportify_os_id)"
  echo "  OS: $(sportify_os_pretty | tr -d '\n')"
  if [[ "$os" != linux ]]; then
    sportify_req_fail "SoccerNet GSR baseline requires Linux + NVIDIA CUDA (got ${os}). Use a Linux VPS or GPU host; see docs/plans/2026-05-24-vps-soccernet-baseline-benchmark.md"
    return 1
  fi
}

sportify_check_os_easyocr() {
  local os
  os="$(sportify_os_id)"
  echo "  OS: $(sportify_os_pretty | tr -d '\n')"
  case "$os" in
    linux|darwin) ;;
    *)
      sportify_req_fail "unsupported OS for EasyOCR experiments: ${os} (need Linux or macOS)"
      ;;
  esac
  if [[ "$os" == darwin ]]; then
    sportify_req_warn "macOS: EasyOCR notebooks run on CPU; full GSR baseline is Linux-only"
  fi
}

sportify_check_requirements() {
  local profile="${1:-}"
  shift || true

  local data_root=""
  local skip_download=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --data-root)      data_root="$2"; shift 2 ;;
      --skip-download)  skip_download=true; shift ;;
      *)
        sportify_req_fail "unknown argument to sportify_check_requirements: $1"
        shift
        ;;
    esac
  done

  _SPORTIFY_REQ_ERRORS=0
  _SPORTIFY_REQ_WARNS=0

  echo "==> Checking requirements (profile: ${profile})"

  case "$profile" in
    common)
      sportify_check_common
      ;;
    easyocr)
      sportify_check_common
      sportify_check_os_easyocr
      sportify_check_ram_at_least "$_SPORTIFY_MIN_RAM_EASYOCR" "EasyOCR notebook"
      sportify_check_disk_at_least "$(pwd)" "$_SPORTIFY_MIN_DISK_EASYOCR" "EasyOCR venv" || true
      sportify_check_uv_python 3.11
      ;;
    gsr-setup)
      sportify_check_common
      sportify_check_os_linux_only
      sportify_check_nvidia_gpu true
      sportify_check_ram_at_least "$_SPORTIFY_MIN_RAM_GSR" "GSR setup"
      if [[ -z "$data_root" ]]; then
        sportify_req_fail "gsr-setup profile requires --data-root PATH"
      else
        local disk_min="$_SPORTIFY_MIN_DISK_GSR_FULL"
        if $skip_download; then
          disk_min="$_SPORTIFY_MIN_DISK_GSR_VENDOR"
        fi
        sportify_check_disk_at_least "$data_root" "$disk_min" "GSR data root" || true
      fi
      sportify_check_uv_python 3.9
      if [[ "$(sportify_os_id)" == linux ]]; then
        for pkg in gcc unzip; do
          if ! command -v "$pkg" >/dev/null 2>&1; then
            sportify_req_warn "missing optional system tool: ${pkg} (install via apt: build-essential unzip)"
          fi
        done
      fi
      ;;
    gsr-run)
      sportify_check_common
      sportify_check_os_linux_only
      sportify_check_nvidia_gpu true
      sportify_check_ram_at_least "$_SPORTIFY_MIN_RAM_GSR" "GSR run"
      if [[ -z "$data_root" ]]; then
        sportify_req_fail "gsr-run profile requires --data-root PATH"
      else
        sportify_check_disk_at_least "$data_root" "$_SPORTIFY_MIN_DISK_GSR_RUN" "GSR data root" || true
        local sn_gs="${data_root}/vendor/sn-gamestate"
        if [[ ! -d "${sn_gs}" ]]; then
          sportify_req_fail "sn-gamestate not found at ${sn_gs} — run benchmarks/soccernet-gsr/setup-bench.sh first"
        else
          echo "  vendor: ${sn_gs}"
        fi
      fi
      ;;
    *)
      sportify_req_fail "unknown profile: ${profile} (use common | easyocr | gsr-setup | gsr-run)"
      ;;
  esac

  if ((_SPORTIFY_REQ_ERRORS > 0)); then
    echo "" >&2
    echo "Requirements check failed (${_SPORTIFY_REQ_ERRORS} error(s), ${_SPORTIFY_REQ_WARNS} warning(s)). Fix the issues above and retry." >&2
    return 1
  fi
  if ((_SPORTIFY_REQ_WARNS > 0)); then
    echo "==> Requirements OK with ${_SPORTIFY_REQ_WARNS} warning(s)"
  else
    echo "==> Requirements OK"
  fi
  return 0
}
