#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title aio
# @raycast.mode silent

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Prompt" }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Agent", "optional": true, "data": [{"title": "Claude", "value": "claude"}, {"title": "Codex", "value": "codex"}] }
# @raycast.packageName Git

# Documentation:
# @raycast.description Create a new Orca workspace in the selected workspace's repository and start Claude or Codex with the prompt.
# @raycast.author yuki

set -euo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Initialize mise environment for Claude/Codex shims.
command -v mise &>/dev/null && eval "$(mise activate bash --shims)"

prompt="${1:-}"
provider="${2:-claude}"

exec "$HOME/.local/bin/gwai-orca" --provider "$provider" -- "$prompt"
