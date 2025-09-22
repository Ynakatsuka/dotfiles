#!/usr/bin/env bash
set -euo pipefail

SSH_DIR="$HOME/.ssh"
KEY_FILE="$SSH_DIR/id_rsa"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ ! -f "$KEY_FILE" ]; then
  echo "[INFO] Creating a new SSH key (RSA 4096)"
  read -r -p "Key comment (e.g., yuki@mac): " comment
  comment=${comment:-"$(whoami)@$(hostname)"}
  ssh-keygen -t rsa -b 4096 -C "$comment" -f "$KEY_FILE" -N ""
else
  echo "[INFO] SSH key already exists: $KEY_FILE"
fi

echo "[INFO] Adding key to agent with Keychain support"
eval "$(/usr/bin/ssh-agent -s)" >/dev/null 2>&1 || true
ssh-add --apple-use-keychain "$KEY_FILE" || ssh-add -K "$KEY_FILE" || true

CONFIG_FILE="$SSH_DIR/config"
if ! grep -q "UseKeychain yes" "$CONFIG_FILE" 2>/dev/null; then
  {
    echo "Host *"
    echo "  AddKeysToAgent yes"
    echo "  UseKeychain yes"
    echo "  IdentityFile ~/.ssh/id_rsa"
  } >> "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
  echo "[INFO] Appended default SSH config to $CONFIG_FILE"
else
  echo "[INFO] SSH config already contains UseKeychain setting"
fi

echo "[INFO] To copy your key to a server: brew install ssh-copy-id && ssh-copy-id user@host"

