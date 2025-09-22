#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT=$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)
PREF_DIR="$REPO_ROOT/bootstrap/iterm2"

if [ -d "$PREF_DIR" ] && [ -f "$PREF_DIR/com.googlecode.iterm2.plist" ]; then
  echo "[INFO] Pointing iTerm2 to custom prefs at $PREF_DIR"
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$PREF_DIR"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  echo "[INFO] iTerm2 preferences folder set. Restart iTerm2 to take effect."
else
  echo "[WARN] $PREF_DIR/com.googlecode.iterm2.plist not found; skipping prefs binding"
fi
