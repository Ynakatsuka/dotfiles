#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing Xcode Command Line Tools (if needed)"
xcode-select --install || true

if ! command -v brew >/dev/null 2>&1; then
  echo "[INFO] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -d /opt/homebrew/bin ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo 'eval $(/opt/homebrew/bin/brew shellenv)' >> "$HOME/.zprofile"
  fi
else
  echo "[INFO] Homebrew already installed"
fi

echo "[INFO] Updating Homebrew..."
brew update

echo "[INFO] Running brew cleanup"
brew cleanup || true
