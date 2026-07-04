#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Copy Today (YYYYMMDD)
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 📅
# @raycast.packageName Utilities

# Documentation:
# @raycast.description Copy today's date in YYYYMMDD format to clipboard
# @raycast.author yuki

date +%Y%m%d | pbcopy
