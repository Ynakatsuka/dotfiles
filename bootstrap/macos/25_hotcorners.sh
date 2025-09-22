#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Configuring Hot Corners (bottom-right → Start Screen Saver)"

# Values: 0=none, 2=Mission Control, 3=Application windows, 4=Desktop,
# 5=Start screen saver, 6=Disable screen saver, 7=Dashboard (legacy),
# 11=Launchpad, 12=Notification Center, 13=Lock Screen

defaults write com.apple.dock wvous-br-corner -int 5
defaults write com.apple.dock wvous-br-modifier -int 0

echo "[INFO] Restarting Dock"
killall Dock || true

echo "[INFO] Hot Corners configured"

