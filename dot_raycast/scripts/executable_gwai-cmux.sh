#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title AI Worktree in cmux
# @raycast.mode silent

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Prompt" }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Agent", "optional": true, "data": [{"title": "Codex", "value": "codex"}, {"title": "Claude", "value": "claude"}] }
# @raycast.packageName Git

# Documentation:
# @raycast.description Create an AI-named worktree from the active cmux workspace and start Claude or Codex with the prompt.
# @raycast.author yuki

set -euo pipefail

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Initialize mise environment for Claude/Codex shims.
command -v mise &>/dev/null && eval "$(mise activate bash --shims)"

prompt="${1:-}"
provider="${2:-codex}"

exec "$HOME/.local/bin/gwai-cmux" --provider "$provider" -- "$prompt"
