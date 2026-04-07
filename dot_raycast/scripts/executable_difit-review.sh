#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Difit Review
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔍
# @raycast.packageName Git

# Documentation:
# @raycast.description Open difit diff view in cmux browser split pane
# @raycast.author yuki

# Initialize mise environment for difit (npm global)
command -v mise &>/dev/null && eval "$(mise activate bash --shims)"

exec "$HOME/.local/bin/difit-cmux"
