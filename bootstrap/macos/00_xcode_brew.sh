#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing Xcode Command Line Tools (if needed)"
xcode-select --install || true

if ! command -v brew >/dev/null 2>&1; then
  echo "[INFO] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH for both Apple Silicon and Intel Macs
  if [ -d /opt/homebrew/bin ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    # Add to shell profile files
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.bash_profile"
  elif [ -d /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
    # Add to shell profile files
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.bash_profile"
  fi
else
  echo "[INFO] Homebrew already installed"
fi

# Ensure Homebrew is in PATH for subsequent commands
if command -v brew >/dev/null 2>&1; then
  echo "[INFO] Homebrew is available in PATH"
elif [ -x "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
else
  echo "[ERROR] Homebrew installation failed or not found"
  exit 1
fi

echo "[INFO] Updating Homebrew..."
brew update

echo "[INFO] Running brew cleanup"
brew cleanup || true
