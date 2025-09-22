#!/usr/bin/env bash
set -euo pipefail

# Applies pointer/trackpad preferences if exported plists are present in the repo.

if ! command -v defaults >/dev/null 2>&1; then
  echo "[WARN] 'defaults' not found; skipping pointer prefs apply"
  exit 0
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
PREF_DIR="$SCRIPT_DIR/pointer/prefs"
VALUES_SH="$PREF_DIR/pointer_values.sh"

mkdir -p "$PREF_DIR"

apply() {
  local domain="$1"
  local file="$PREF_DIR/$domain.plist"
  if [ -f "$file" ]; then
    echo "[INFO] Importing $domain from $file"
    defaults import "$domain" "$file" || echo "[WARN] Failed to import $domain"
  else
    echo "[INFO] No plist for $domain; skipping"
  fi
}

# Prefer explicit key writes if a values script exists; otherwise try plist import.
if [ -f "$VALUES_SH" ]; then
  echo "[INFO] Applying pointer values from $VALUES_SH"
  # shellcheck disable=SC1090
  source "$VALUES_SH"
else
  apply NSGlobalDomain
  apply com.apple.AppleMultitouchTrackpad
  apply com.apple.driver.AppleBluetoothMultitouch.trackpad
  apply com.apple.universalaccess
fi

echo "[INFO] Restarting preference services"
killall cfprefsd 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
killall Dock 2>/dev/null || true

echo "[INFO] Pointer/Trackpad preferences applied"
