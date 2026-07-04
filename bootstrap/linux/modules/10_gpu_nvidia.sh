#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

DRIVER_FIXED="570" # fallback option from memo; guarded by prompt

# CUDA version constants — update these manually when upgrading CUDA.
CUDA_VERSION="12.4.0"   # full version, e.g. 12.4.0
CUDA_DRIVER="550.54.14" # bundled driver version in the local repo package
CUDA_PKG_SERIES="12-4"  # used in package names: cuda-toolkit-12-4, repo dir 12-4-local
CUDA_DEB="cuda-repo-ubuntu2204-${CUDA_PKG_SERIES}-local_${CUDA_VERSION}-${CUDA_DRIVER}-1_amd64.deb"

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) enable_dry_run ;;
    *)
      warn "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

require_ubuntu_2204
require_cmd apt-get

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

if confirm "Install CUDA Toolkit ${CUDA_VERSION} from NVIDIA repo (Ubuntu 22.04)?"; then
  run wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
  run sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
  run wget "https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/${CUDA_DEB}"
  run sudo dpkg -i "$CUDA_DEB"
  # The keyring name embeds a build hash, so the glob must expand inside a
  # shell (a quoted glob passed through run() would be taken literally).
  run bash -c "sudo cp /var/cuda-repo-ubuntu2204-${CUDA_PKG_SERIES}-local/cuda-*-keyring.gpg /usr/share/keyrings/"
  run sudo apt-get update -y
  run sudo apt-get -y install "cuda-toolkit-${CUDA_PKG_SERIES}"
  run rm -f "$CUDA_DEB"
else
  warn "Skipped CUDA installation"
fi

log "GPU/NVIDIA module completed"
