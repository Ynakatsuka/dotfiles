#!/usr/bin/env bash
set -euo pipefail

# Applies pointer/trackpad preferences if exported plists are present in the repo.

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

if ! command -v defaults >/dev/null 2>&1; then
  warn "'defaults' not found; skipping pointer prefs apply"
  exit 0
fi
PREF_DIR="$SCRIPT_DIR/pointer/prefs"
VALUES_SH="$PREF_DIR/pointer_values.sh"

mkdir -p "$PREF_DIR"

apply() {
  local domain="$1"
  local file="$PREF_DIR/$domain.plist"
  if [ -f "$file" ]; then
    log "Importing $domain from $file"
    defaults import "$domain" "$file" || warn "Failed to import $domain"
  else
    log "No plist for $domain; skipping"
  fi
}

# Prefer explicit key writes if a values script exists; otherwise try plist import.
if [ -f "$VALUES_SH" ]; then
  log "Applying pointer values from $VALUES_SH"
  # shellcheck disable=SC1090
  source "$VALUES_SH"
else
  apply NSGlobalDomain
  apply com.apple.AppleMultitouchTrackpad
  apply com.apple.driver.AppleBluetoothMultitouch.trackpad
  apply com.apple.universalaccess
fi

log "Restarting preference services"
killall cfprefsd 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true
killall Dock 2>/dev/null || true

log "Pointer/Trackpad preferences applied"
