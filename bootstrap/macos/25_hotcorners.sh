#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
. "${SCRIPT_DIR}/../lib/common.sh"

log "Configuring Hot Corners (bottom-right → Start Screen Saver)"

# Values: 0=none, 2=Mission Control, 3=Application windows, 4=Desktop,
# 5=Start screen saver, 6=Disable screen saver, 7=Dashboard (legacy),
# 11=Launchpad, 12=Notification Center, 13=Lock Screen

defaults write com.apple.dock wvous-br-corner -int 5
defaults write com.apple.dock wvous-br-modifier -int 0

log "Restarting Dock"
killall Dock || true

log "Hot Corners configured"
