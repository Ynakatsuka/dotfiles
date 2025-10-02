#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Applying macOS defaults"

defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true
defaults write com.apple.screencapture location -string "$HOME/Downloads"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.systemsound com.apple.sound.beep.volume -float 0

# Trackpad and Mouse settings
echo "[INFO] Configuring trackpad and mouse speed (maximum)"
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 3.0
defaults write NSGlobalDomain com.apple.mouse.scaling -float 3.0

# Enable three-finger drag for window movement
echo "[INFO] Enabling three-finger drag"
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.AppleMultitouchTrackpad Dragging -bool false
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Dragging -bool false

killall Finder || true
killall SystemUIServer || true
killall cfprefsd || true

echo "[INFO] macOS defaults applied"
echo "[INFO] You may need to log out and log back in for all changes to take effect"

