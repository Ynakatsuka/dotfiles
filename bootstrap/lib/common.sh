#!/usr/bin/env bash
# Shared utility functions for bootstrap modules.

[[ -n "${_COMMON_SH_LOADED:-}" ]] && return 0
_COMMON_SH_LOADED=1

log()  { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }

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
