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

