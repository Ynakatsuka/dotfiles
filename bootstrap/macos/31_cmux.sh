#!/usr/bin/env bash
set -euo pipefail

# Install xterm-ghostty terminfo for cmux (Ghostty-based terminal)
# Without this, TUI apps like Claude Code hang because the terminfo is missing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

CMUX_TERMINFO="/Applications/cmux.app/Contents/Resources/ghostty/terminfo/78/xterm-ghostty"

if [ ! -f "$CMUX_TERMINFO" ]; then
  log "cmux not installed; skipping terminfo setup"
  exit 0
fi

if infocmp xterm-ghostty >/dev/null 2>&1; then
  log "xterm-ghostty terminfo already available"
  exit 0
fi

log "Installing xterm-ghostty terminfo from cmux"
mkdir -p "$HOME/.terminfo/78"
cp "$CMUX_TERMINFO" "$HOME/.terminfo/78/"
log "xterm-ghostty terminfo installed"
