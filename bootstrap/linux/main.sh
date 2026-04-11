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
WITH_MISE_INSTALL=0
XDG_ENGLISH_DIRS=0
USER_ONLY=0
DRY_RUN=0
PLAN=""
SKIP_AGE=0

usage() {
  cat <<'USAGE'
linux bootstrap orchestrator

Usage:
  main.sh [options]

Options:
  --plan <full|standard|minimal>  Deploy plan (auto-sets flags).
  --with-gpu                 Install NVIDIA driver/toolkit (guarded).
  --with-expressvpn          Install ExpressVPN (guarded).
  --with-docker              Install Docker CE + plugins.
  --with-nvidia-container    Install NVIDIA Container Toolkit.
  --with-clis                Install age/uv/mise/tailscale/claude (non mise-managed CLIs).
  --with-dotfiles            Setup prezto/tpm/chezmoi (guarded).
  --with-cleanup             Run apt autoremove at the end.
  --xdg-english-dirs         Convert XDG user dirs to English (guarded).
  --user-only                Skip base packages (no sudo). Run only CLIs + dotfiles.
  --dry-run                  Show planned actions only.
  -h, --help                 Show help.

Plans:
  full      Base packages (sudo) + Docker + CLIs (with age) + dotfiles + mise install
  standard  CLIs (no age, no sudo) + dotfiles + mise install
  minimal   Dotfiles only (chezmoi apply)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --plan)
      shift
      PLAN="$1"
      ;;
    --with-gpu) WITH_GPU=1 ;;
    --with-expressvpn) WITH_EXPRESSVPN=1 ;;
    --with-docker) WITH_DOCKER=1 ;;
    --with-nvidia-container) WITH_NVIDIA_CONTAINER=1 ;;
    --with-clis) WITH_CLIS=1 ;;
    --with-dotfiles) WITH_DOTFILES=1 ;;
    --with-cleanup) WITH_CLEANUP=1 ;;
    --xdg-english-dirs) XDG_ENGLISH_DIRS=1 ;;
    --user-only)
      USER_ONLY=1
      WITH_CLIS=1
      WITH_DOTFILES=1
      ;;
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      warn "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# Apply plan presets (override individual flags)
case "$PLAN" in
  full)
    WITH_DOCKER=1
    WITH_CLIS=1
    WITH_DOTFILES=1
    WITH_CLEANUP=1
    WITH_MISE_INSTALL=1
    ;;
  standard)
    USER_ONLY=1
    WITH_CLIS=1
    WITH_DOTFILES=1
    WITH_MISE_INSTALL=1
    SKIP_AGE=1
    ;;
  minimal)
    USER_ONLY=1
    WITH_DOTFILES=1
    ;;
  "")
    ;; # no plan specified, use individual flags
  *)
    warn "Unknown plan: $PLAN"
    usage
    exit 1
    ;;
esac

if [ "$USER_ONLY" -eq 0 ]; then
  require_ubuntu_2204
  require_cmd apt-get
else
  require_ubuntu
fi

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    "$@"
  fi
}

# Build flag arrays up-front so module invocations can pass them quoted.
# Arrays let us avoid SC2046 word-splitting warnings without disabling the check.
DRY_RUN_ARGS=()
if [ "$DRY_RUN" -eq 1 ]; then DRY_RUN_ARGS=(--dry-run); fi
XDG_ARGS=()
if [ "$XDG_ENGLISH_DIRS" -eq 1 ]; then XDG_ARGS=(--xdg-english-dirs); fi
SKIP_AGE_ARGS=()
if [ "$SKIP_AGE" -eq 1 ]; then SKIP_AGE_ARGS=(--skip-age); fi

if [ "$USER_ONLY" -eq 0 ]; then
  log "Running 00_base.sh"
  "${SCRIPT_DIR}/modules/00_base.sh" "${DRY_RUN_ARGS[@]}" "${XDG_ARGS[@]}"
else
  log "Skipping 00_base.sh (user-only mode)"
fi

if [ "$WITH_EXPRESSVPN" -eq 1 ]; then
  log "Running 05_expressvpn.sh"
  "${SCRIPT_DIR}/modules/05_expressvpn.sh" "${DRY_RUN_ARGS[@]}"
fi

if [ "$WITH_DOCKER" -eq 1 ]; then
  log "Running 20_docker.sh"
  "${SCRIPT_DIR}/modules/20_docker.sh" "${DRY_RUN_ARGS[@]}"
fi

if [ "$WITH_NVIDIA_CONTAINER" -eq 1 ]; then
  log "Running 25_nvidia_container.sh"
  "${SCRIPT_DIR}/modules/25_nvidia_container.sh" "${DRY_RUN_ARGS[@]}"
fi

GPU_DONE=0
if [ "$WITH_GPU" -eq 1 ]; then
  log "Running 10_gpu_nvidia.sh (explicit)"
  "${SCRIPT_DIR}/modules/10_gpu_nvidia.sh" "${DRY_RUN_ARGS[@]}"
  GPU_DONE=1
fi

# Auto-detect NVIDIA GPU and offer installation with confirmation
if [ "$GPU_DONE" -eq 0 ] && has_nvidia_gpu; then
  if confirm "NVIDIA GPU detected. Install driver/CUDA now?"; then
    log "Running 10_gpu_nvidia.sh (auto-detected)"
    "${SCRIPT_DIR}/modules/10_gpu_nvidia.sh" "${DRY_RUN_ARGS[@]}"
    GPU_DONE=1
  else
    warn "Skipped GPU installation despite detection"
  fi
fi

if [ "$WITH_CLIS" -eq 1 ]; then
  log "Running 30_clis.sh"
  "${SCRIPT_DIR}/modules/30_clis.sh" "${DRY_RUN_ARGS[@]}" "${SKIP_AGE_ARGS[@]}"
fi

if [ "$WITH_DOTFILES" -eq 1 ]; then
  log "Running 40_dotfiles.sh"
  "${SCRIPT_DIR}/modules/40_dotfiles.sh" "${DRY_RUN_ARGS[@]}"
fi

if [ "$WITH_MISE_INSTALL" -eq 1 ]; then
  # mise may have been just installed; try common paths
  MISE_CMD=""
  if command -v mise >/dev/null 2>&1; then
    MISE_CMD="mise"
  elif [ -x "$HOME/.local/bin/mise" ]; then
    MISE_CMD="$HOME/.local/bin/mise"
  fi

  if [ -n "$MISE_CMD" ]; then
    log "Running mise install"
    run "$MISE_CMD" install
  else
    warn "mise not found. Skipping mise install."
  fi
fi

# Post-mise tasks (need tools provided by `mise install`).
if [ "$WITH_CLIS" -eq 1 ]; then
  GH_BIN=""
  if command -v gh >/dev/null 2>&1; then
    GH_BIN="gh"
  elif [ -x "$HOME/.local/share/mise/shims/gh" ]; then
    GH_BIN="$HOME/.local/share/mise/shims/gh"
  fi

  if [ -n "$GH_BIN" ]; then
    if "$GH_BIN" extension list 2>/dev/null | grep -q dlvhdr/gh-dash; then
      log "gh-dash already installed, skipping"
    elif confirm "Install gh-dash (GitHub CLI extension for PR/issue dashboard)?"; then
      run "$GH_BIN" extension install dlvhdr/gh-dash
    fi
    warn "Run 'gh auth login' manually if you have not authenticated yet."
  else
    warn "gh not found (expected mise-managed); skipping gh-dash installation."
  fi
fi

if [ "$WITH_CLEANUP" -eq 1 ]; then
  log "Running 99_cleanup.sh"
  "${SCRIPT_DIR}/modules/99_cleanup.sh" "${DRY_RUN_ARGS[@]}"
fi

log "Linux bootstrap finished."
