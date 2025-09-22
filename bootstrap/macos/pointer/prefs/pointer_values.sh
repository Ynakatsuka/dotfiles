#!/usr/bin/env bash
# Apply fixed pointer/trackpad values captured from the current Mac.
# Edit these lines if you want to tweak behaviors.

# NSGlobalDomain
defaults write -g com.apple.mouse.doubleClickThreshold -float 0.5
defaults write -g com.apple.trackpad.scaling -float 3

# You can uncomment and set if you want tap-to-click at the system level.
# defaults write -g com.apple.mouse.tapBehavior -int 1

# Example toggles (uncomment if needed). Some systems may not use these keys.
# defaults write com.apple.AppleMultitouchTrackpad Clicking -int 1
# defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -int 1
# defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 1
# defaults write com.apple.AppleMultitouchTrackpad TrackpadCornerSecondaryClick -int 2

# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -int 1
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -int 1
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -int 1
# defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2

# com.apple.universalaccess
# defaults write com.apple.universalaccess mouseDriverCursorSize -float 1.0

