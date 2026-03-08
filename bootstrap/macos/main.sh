#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

PLAN=""
DRY_RUN=0

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
    --plan) shift; PLAN="$1" ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown option: $1"; usage; exit 1 ;;
  esac
  shift
done

if [ -z "$PLAN" ]; then
  warn "No plan specified."
  usage
  exit 1
fi

require_macos

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

resolve_brew() {
  if [ -x "/opt/homebrew/bin/brew" ]; then
    echo "/opt/homebrew/bin/brew"
  elif [ -x "/usr/local/bin/brew" ]; then
    echo "/usr/local/bin/brew"
  elif command -v brew >/dev/null 2>&1; then
    command -v brew
  else
    echo ""
  fi
}

install_chezmoi_standalone() {
  if command -v chezmoi >/dev/null 2>&1; then
    return 0
  fi
  log "Installing chezmoi via curl"
  run 'sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"'
}

run_dotfiles() {
  run bash "${SCRIPT_DIR}/45_dotfiles.sh"
}

run_mise_install() {
  local mise_cmd=""
  if command -v mise >/dev/null 2>&1; then
    mise_cmd="mise"
  elif [ -x "$HOME/.local/bin/mise" ]; then
    mise_cmd="$HOME/.local/bin/mise"
  fi

  if [ -n "$mise_cmd" ]; then
    log "Running mise install"
    run "$mise_cmd" install
  else
    warn "mise not found. Skipping mise install."
  fi
}

case "$PLAN" in
  full)
    log "Plan: full"
    run bash "${SCRIPT_DIR}/00_xcode_brew.sh"

    BREW=$(resolve_brew)
    if [ -z "$BREW" ]; then
      warn "Homebrew not found after install. Aborting."
      exit 1
    fi
    run "$BREW" bundle --file "${SCRIPT_DIR}/Brewfile"

    run bash "${SCRIPT_DIR}/20_defaults.sh"
    run bash "${SCRIPT_DIR}/22_pointer.sh"
    run bash "${SCRIPT_DIR}/25_hotcorners.sh"
    run bash "${SCRIPT_DIR}/30_iterm.sh"
    run bash "${SCRIPT_DIR}/35_iterm_prefs.sh"
    run bash "${SCRIPT_DIR}/10_git.sh"
    run bash "${SCRIPT_DIR}/40_ssh.sh"

    run_dotfiles
    run_mise_install

    run "$BREW" cleanup
    ;;

  standard)
    log "Plan: standard"
    run bash "${SCRIPT_DIR}/00_xcode_brew.sh"

    BREW=$(resolve_brew)
    if [ -z "$BREW" ]; then
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
