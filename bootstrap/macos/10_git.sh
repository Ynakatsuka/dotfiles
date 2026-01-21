#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Configuring global Git identity (interactive)"

current_name=$(git config --global user.name || true)
current_email=$(git config --global user.email || true)

if [ -n "$current_name" ] && [ -n "$current_email" ]; then
  echo "[INFO] Git identity already set: $current_name <$current_email>"
  exit 0
fi

read -r -p "Your Git user.name: " name
read -r -p "Your Git user.email: " email

if [ -z "$name" ] || [ -z "$email" ]; then
  echo "[WARN] Empty name or email; skipping Git identity setup"
  exit 0
fi

git config --global user.name "$name"
git config --global user.email "$email"

echo "[INFO] Git identity configured: $name <$email>"

# Install gh-dash extension
if command -v gh &>/dev/null; then
  if ! gh extension list | grep -q "dlvhdr/gh-dash"; then
    echo "[INFO] Installing gh-dash extension..."
    gh extension install dlvhdr/gh-dash
  else
    echo "[INFO] gh-dash already installed"
  fi
else
  echo "[WARN] gh not found; skipping gh-dash installation"
fi
