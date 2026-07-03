#!/usr/bin/env bash
# Shared utility functions for bootstrap modules.

[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

DRY_RUN=0

log() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

enable_dry_run() { DRY_RUN=1; }

run() {
  if [ "${DRY_RUN:-0}" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

confirm() {
  local answer
  printf '%s [y/N]: ' "$1"
  read -r answer
  [[ "$answer" =~ ^[yY]$ ]]
}

require_ubuntu() {
  local id
  id=$(. /etc/os-release 2>/dev/null && echo "${ID:-}")
  if [[ "$id" != "ubuntu" ]]; then
    echo "[ERROR] This script requires Ubuntu (detected: ${id:-unknown})." >&2
    exit 1
  fi
}

require_ubuntu_2204() {
  require_ubuntu
  local ver
  ver=$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")
  if [[ "$ver" != "22.04" ]]; then
    echo "[ERROR] Ubuntu 22.04 required (detected: ${ver:-unknown})." >&2
    exit 1
  fi
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $1" >&2
    exit 1
  fi
}

has_nvidia_gpu() {
  lspci 2>/dev/null | grep -qi nvidia
}

# Install a CLI via its vendor's install script when not already present.
# Usage: install_cli_via_script <command> <display name> <script URL>
install_cli_via_script() {
  local cmd="$1" name="$2" url="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    log "$name already installed, skipping"
    return 0
  fi
  if ! confirm "Install $name (native installer)?"; then
    warn "Skipped $name installation"
    return 0
  fi
  run bash -lc '_s=$(mktemp) && curl --fail -fsSL "$1" -o "$_s" && bash "$_s" && rm -f "$_s"' _ "$url"
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "[ERROR] This script requires macOS." >&2
    exit 1
  fi
}

is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
