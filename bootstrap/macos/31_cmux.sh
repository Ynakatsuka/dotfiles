#!/usr/bin/env bash
set -euo pipefail

# Install xterm-ghostty terminfo for cmux (Ghostty-based terminal)
# Without this, TUI apps like Claude Code hang because the terminfo is missing.

CMUX_TERMINFO="/Applications/cmux.app/Contents/Resources/ghostty/terminfo/78/xterm-ghostty"

if [ ! -f "$CMUX_TERMINFO" ]; then
  echo "[INFO] cmux not installed; skipping terminfo setup"
  exit 0
fi

if infocmp xterm-ghostty >/dev/null 2>&1; then
  echo "[INFO] xterm-ghostty terminfo already available"
  exit 0
fi

echo "[INFO] Installing xterm-ghostty terminfo from cmux"
mkdir -p "$HOME/.terminfo/78"
cp "$CMUX_TERMINFO" "$HOME/.terminfo/78/"
echo "[INFO] xterm-ghostty terminfo installed"
