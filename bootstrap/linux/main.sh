#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

WITH_GPU=0
WITH_EXPRESSVPN=0
WITH_DOCKER=0
WITH_NVIDIA_CONTAINER=0
WITH_CLIS=0
WITH_DOTFILES=0
WITH_CLEANUP=0
XDG_ENGLISH_DIRS=0
DRY_RUN=0

usage() {
  cat <<'USAGE'
linux bootstrap orchestrator

Usage:
  main.sh [options]

Options:
  --with-gpu                 Install NVIDIA driver/toolkit (guarded).
  --with-expressvpn          Install ExpressVPN (guarded).
  --with-docker              Install Docker CE + plugins.
  --with-nvidia-container    Install NVIDIA Container Toolkit.
  --with-clis                Install gh/uv/rye/direnv/gcloud.
  --with-dotfiles            Setup prezto/tpm/chezmoi (guarded).
  --with-cleanup             Run apt autoremove at the end.
  --xdg-english-dirs         Convert XDG user dirs to English (guarded).
  --dry-run                  Show planned actions only.
  -h, --help                 Show help.

By default, only base packages and SSH/locale checks run.
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --with-gpu) WITH_GPU=1 ;;
    --with-expressvpn) WITH_EXPRESSVPN=1 ;;
    --with-docker) WITH_DOCKER=1 ;;
    --with-nvidia-container) WITH_NVIDIA_CONTAINER=1 ;;
    --with-clis) WITH_CLIS=1 ;;
    --with-dotfiles) WITH_DOTFILES=1 ;;
    --with-cleanup) WITH_CLEANUP=1 ;;
    --xdg-english-dirs) XDG_ENGLISH_DIRS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown option: $1"; usage; exit 1 ;;
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

log "Running 00_base.sh"
"${SCRIPT_DIR}/modules/00_base.sh" ${DRY_RUN:+--dry-run} ${XDG_ENGLISH_DIRS:+--xdg-english-dirs}

if [ "$WITH_EXPRESSVPN" -eq 1 ]; then
  log "Running 05_expressvpn.sh"
  "${SCRIPT_DIR}/modules/05_expressvpn.sh" ${DRY_RUN:+--dry-run}
fi

if [ "$WITH_DOCKER" -eq 1 ]; then
  log "Running 20_docker.sh"
  "${SCRIPT_DIR}/modules/20_docker.sh" ${DRY_RUN:+--dry-run}
fi

if [ "$WITH_NVIDIA_CONTAINER" -eq 1 ]; then
  log "Running 25_nvidia_container.sh"
  "${SCRIPT_DIR}/modules/25_nvidia_container.sh" ${DRY_RUN:+--dry-run}
fi

GPU_DONE=0
if [ "$WITH_GPU" -eq 1 ]; then
  log "Running 10_gpu_nvidia.sh (explicit)"
  "${SCRIPT_DIR}/modules/10_gpu_nvidia.sh" ${DRY_RUN:+--dry-run}
  GPU_DONE=1
fi

# Auto-detect NVIDIA GPU and offer installation with confirmation
if [ "$GPU_DONE" -eq 0 ] && has_nvidia_gpu; then
  if confirm "NVIDIA GPU detected. Install driver/CUDA now?"; then
    log "Running 10_gpu_nvidia.sh (auto-detected)"
    "${SCRIPT_DIR}/modules/10_gpu_nvidia.sh" ${DRY_RUN:+--dry-run}
    GPU_DONE=1
  else
    warn "Skipped GPU installation despite detection"
  fi
fi

if [ "$WITH_CLIS" -eq 1 ]; then
  log "Running 30_clis.sh"
  "${SCRIPT_DIR}/modules/30_clis.sh" ${DRY_RUN:+--dry-run}
fi

if [ "$WITH_DOTFILES" -eq 1 ]; then
  log "Running 40_dotfiles.sh"
  "${SCRIPT_DIR}/modules/40_dotfiles.sh" ${DRY_RUN:+--dry-run}
fi

if [ "$WITH_CLEANUP" -eq 1 ]; then
  log "Running 99_cleanup.sh"
  "${SCRIPT_DIR}/modules/99_cleanup.sh" ${DRY_RUN:+--dry-run}
fi

log "Linux bootstrap finished."
