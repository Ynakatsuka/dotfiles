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

killall Finder || true

echo "[INFO] macOS defaults applied"

