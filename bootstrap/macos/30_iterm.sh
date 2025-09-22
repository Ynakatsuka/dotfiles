#!/usr/bin/env bash
set -euo pipefail

if ! command -v curl >/dev/null 2>&1; then
  echo "[WARN] curl not found; skipping iTerm2 shell integration"
  exit 0
fi

echo "[INFO] Installing iTerm2 shell integration"
curl -L https://iterm2.com/shell_integration/install_shell_integration.sh | bash

if [ -f "$HOME/.iterm2_shell_integration.zsh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.iterm2_shell_integration.zsh" || true
fi

echo "[INFO] iTerm2 integration done"

