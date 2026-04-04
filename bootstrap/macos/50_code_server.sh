#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
ROOT_DIR=$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)
# shellcheck source=../lib/common.sh
. "${ROOT_DIR}/bootstrap/lib/common.sh"

if ! command -v code-server >/dev/null 2>&1; then
  log "code-server not found, skipping extension install."
  exit 0
fi

extensions=(
  GitHub.github-vscode-theme
  vscode-icons-team.vscode-icons
  ms-python.python
  ms-python.pylance
  esbenp.prettier-vscode
  rust-lang.rust-analyzer
  golang.go
)

log "Installing code-server extensions ..."
for ext in "${extensions[@]}"; do
  log "  $ext"
  code-server --install-extension "$ext" --force 2>/dev/null || warn "Failed to install $ext"
done

log "code-server extensions installed."
