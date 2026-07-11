#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

PLAN=""

usage() {
  cat <<'USAGE'
macOS bootstrap orchestrator

Usage:
  main.sh --plan <full|standard|minimal> [--dry-run]

Plans:
  full      Xcode + Homebrew + Brewfile + system defaults + SSH + dotfiles (with age) + mise install
  standard  Xcode + Homebrew + Brewfile + dotfiles (no age) + mise install
  minimal   Dotfiles only (chezmoi apply)
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --plan)
      shift
      PLAN="$1"
      ;;
    --dry-run) enable_dry_run ;;
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

if [ -z "$PLAN" ]; then
  warn "No plan specified."
  usage
  exit 1
fi

require_macos

install_chezmoi_standalone() {
  if command -v chezmoi >/dev/null 2>&1; then
    return 0
  fi
  log "Installing chezmoi via curl"
  run bash -c 'sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"'
}

run_dotfiles() {
  run bash "${SCRIPT_DIR}/45_dotfiles.sh"
}

case "$PLAN" in
  full)
    log "Plan: full"
    run bash "${SCRIPT_DIR}/00_xcode_brew.sh"

    if ! BREW=$(resolve_brew); then
      warn "Homebrew not found after install. Aborting."
      exit 1
    fi
    run "$BREW" bundle --file "${SCRIPT_DIR}/Brewfile"

    run bash "${SCRIPT_DIR}/20_defaults.sh"
    run bash "${SCRIPT_DIR}/22_pointer.sh"
    run bash "${SCRIPT_DIR}/25_hotcorners.sh"
    run bash "${SCRIPT_DIR}/31_cmux.sh"
    run bash "${SCRIPT_DIR}/10_git.sh"
    run bash "${SCRIPT_DIR}/40_ssh.sh"

    run_dotfiles
    run_mise_install

    run "$BREW" cleanup
    ;;

  standard)
    log "Plan: standard"
    run bash "${SCRIPT_DIR}/00_xcode_brew.sh"

    if ! BREW=$(resolve_brew); then
      warn "Homebrew not found after install. Aborting."
      exit 1
    fi
    run "$BREW" bundle --file "${SCRIPT_DIR}/Brewfile"

    run_dotfiles
    run_mise_install

    run "$BREW" cleanup
    ;;

  minimal)
    log "Plan: minimal"
    install_chezmoi_standalone
    run_dotfiles
    ;;

  *)
    warn "Unknown plan: $PLAN"
    usage
    exit 1
    ;;
esac

log "macOS bootstrap finished."
