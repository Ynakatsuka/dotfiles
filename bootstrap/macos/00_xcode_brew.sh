#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

log "Installing Xcode Command Line Tools (if needed)"
xcode-select --install || true

# Install Rosetta 2 on Apple Silicon Macs (required for some Intel-based applications)
if [ "$(uname -m)" = "arm64" ]; then
  if ! /usr/bin/pgrep -q oahd; then
    log "Installing Rosetta 2 (required for Intel-based applications)"
    softwareupdate --install-rosetta --agree-to-license
  else
    log "Rosetta 2 already installed"
  fi
fi

if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add Homebrew to PATH for both Apple Silicon and Intel Macs
  if [ -d /opt/homebrew/bin ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Add to shell profile files (guard against duplicate entries on re-runs)
    grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.zprofile"
    grep -q 'brew shellenv' "$HOME/.bash_profile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>"$HOME/.bash_profile"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
    # Add to shell profile files (guard against duplicate entries on re-runs)
    grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/usr/local/bin/brew shellenv)"' >>"$HOME/.zprofile"
    grep -q 'brew shellenv' "$HOME/.bash_profile" 2>/dev/null || echo 'eval "$(/usr/local/bin/brew shellenv)"' >>"$HOME/.bash_profile"
  fi
else
  log "Homebrew already installed"
fi

# Ensure Homebrew is in PATH for subsequent commands
if command -v brew >/dev/null 2>&1; then
  log "Homebrew is available in PATH"
elif [ -x "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  warn "Homebrew installation failed or not found"
  exit 1
fi

log "Updating Homebrew..."
brew update

log "Running brew cleanup"
brew cleanup || true
