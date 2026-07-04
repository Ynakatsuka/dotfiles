#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

log "Configuring global Git identity (interactive)"

current_name=$(git config --global user.name || true)
current_email=$(git config --global user.email || true)

if [ -n "$current_name" ] && [ -n "$current_email" ]; then
  log "Git identity already set: $current_name <$current_email>"
  exit 0
fi

read -r -p "Your Git user.name: " name
read -r -p "Your Git user.email: " email

if [ -z "$name" ] || [ -z "$email" ]; then
  warn "Empty name or email; skipping Git identity setup"
  exit 0
fi

git config --global user.name "$name"
git config --global user.email "$email"

log "Git identity configured: $name <$email>"

# Install gh-dash extension
if command -v gh &>/dev/null; then
  if ! gh extension list | grep -q "dlvhdr/gh-dash"; then
    log "Installing gh-dash extension..."
    gh extension install dlvhdr/gh-dash
  else
    log "gh-dash already installed"
  fi
else
  warn "gh not found; skipping gh-dash installation"
fi
