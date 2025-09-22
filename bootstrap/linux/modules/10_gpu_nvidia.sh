#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

DRY_RUN=0
DRIVER_FIXED="570" # fallback option from memo; guarded by prompt

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    *) warn "Unknown option: $1"; exit 1 ;;
  esac
  shift
done

require_ubuntu_2204
require_cmd apt-get

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

if ! has_nvidia_gpu; then
  warn "No NVIDIA GPU detected; skipping GPU module"
  exit 0
fi

log "Install ubuntu-drivers-common"
run sudo apt-get update -y
run sudo apt-get install -y ubuntu-drivers-common

if confirm "Detected NVIDIA GPU. Auto-install recommended driver via 'ubuntu-drivers install'?"; then
  run sudo ubuntu-drivers install
else
  if confirm "Install fixed driver nvidia-driver-${DRIVER_FIXED}?"; then
    run sudo apt-get install -y "nvidia-driver-${DRIVER_FIXED}"
  else
    warn "Skipped NVIDIA driver installation"
  fi
fi

if confirm "Install CUDA Toolkit 12.4 from NVIDIA repo (Ubuntu 22.04)?"; then
  run wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
  run sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
  run wget https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb
  run sudo dpkg -i cuda-repo-ubuntu2204-12-4-local_12.4.0-550.54.14-1_amd64.deb
  run sudo cp /var/cuda-repo-ubuntu2204-12-4-local/cuda-*-keyring.gpg /usr/share/keyrings/
  run sudo apt-get update -y
  run sudo apt-get -y install cuda-toolkit-12-4
else
  warn "Skipped CUDA installation"
fi

log "GPU/NVIDIA module completed"
