#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY_FILE" ]; then
  log "Creating a new SSH key (ed25519)"
  read -r -p "Key comment (e.g., user@mac): " comment
  comment=${comment:-"$(whoami)@$(hostname)"}
  ssh-keygen -t ed25519 -C "$comment" -f "$KEY_FILE" -N ""
else
  log "SSH key already exists: $KEY_FILE"
fi

log "Adding key to agent with Keychain support"
eval "$(/usr/bin/ssh-agent -s)" >/dev/null 2>&1 || true
ssh-add --apple-use-keychain "$KEY_FILE" || ssh-add -K "$KEY_FILE" || true

CONFIG_FILE="$SSH_DIR/config"
if ! grep -q "UseKeychain yes" "$CONFIG_FILE" 2>/dev/null; then
  {
    echo "Host *"
    echo "  AddKeysToAgent yes"
    echo "  IgnoreUnknown UseKeychain"
    echo "  UseKeychain yes"
    echo "  IdentityFile ~/.ssh/id_ed25519"
  } >>"$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  log "Appended default SSH config to $CONFIG_FILE"
else
  log "SSH config already contains UseKeychain setting"
fi

log "To copy your key to a server: brew install ssh-copy-id && ssh-copy-id user@host"
