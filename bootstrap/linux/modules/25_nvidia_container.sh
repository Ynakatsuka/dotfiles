#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../../.." &>/dev/null && pwd)
# shellcheck source=../../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

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

require_ubuntu
require_cmd curl
require_cmd apt-get

log "Installing NVIDIA Container Toolkit"
run bash -c 'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
run bash -c 'curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed "s#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list'
run sudo apt update -y
run sudo apt install -y nvidia-container-toolkit

log "NVIDIA Container Toolkit module completed"
