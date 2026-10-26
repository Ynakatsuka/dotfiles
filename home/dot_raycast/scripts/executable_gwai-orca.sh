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

readonly HAMMERSPOON_CLI='/Applications/Hammerspoon.app/Contents/Frameworks/hs/hs'
# An alert outlives this script only if the script is killed before its EXIT trap.
readonly STEP_ALERT_SECONDS=300

prompt="${1:-}"
provider="${2:-claude}"

# Silent mode closes Raycast while the script runs, so a Hammerspoon alert shows
# the current step. Alerts are keyed by this script's PID so concurrent runs keep
# their own alerts. hs reads a piped stdin as Lua, so stdin must not be the pipe.
show_step() {
  "$HAMMERSPOON_CLI" -q -c '
    gwaiOrcaStepAlerts = gwaiOrcaStepAlerts or {}
    local run, message, seconds = _cli.args[2], _cli.args[3], tonumber(_cli.args[4])
    if gwaiOrcaStepAlerts[run] then hs.alert.closeSpecific(gwaiOrcaStepAlerts[run], 0) end
    gwaiOrcaStepAlerts[run] = hs.alert.show(message, seconds)
  ' -- "$$" "$1" "$STEP_ALERT_SECONDS" </dev/null >&2 || {
    printf 'Error: failed to show the aio step in Hammerspoon: %s\n' "$1" >&2
    return 1
  }
}

close_step() {
  "$HAMMERSPOON_CLI" -q -c '
    local run = _cli.args[2]
    if gwaiOrcaStepAlerts and gwaiOrcaStepAlerts[run] then
      hs.alert.closeSpecific(gwaiOrcaStepAlerts[run])
      gwaiOrcaStepAlerts[run] = nil
    end
  ' -- "$$" </dev/null >&2 ||
    printf 'Error: failed to close the aio step alert in Hammerspoon\n' >&2
}

trap close_step EXIT

# Echo every line so Raycast's final HUD still shows gwai-orca's last line.
"$HOME/.local/bin/gwai-orca" --provider "$provider" -- "$prompt" |
  while IFS= read -r step; do
    printf '%s\n' "$step"
    show_step "$step"
  done
