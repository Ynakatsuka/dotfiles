#!/usr/bin/env bash
# Render {{ .agent }} settings from the managed template.
# Orca registers its agent status hooks in this file only at app startup, so keep
# hook groups that run ~/.orca/agent-hooks/ scripts and replace everything else.
# Dropping them silences Orca's status and restart restore until Orca restarts.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: jq is required to manage {{ .agent }} settings\n' >&2
  exit 1
fi

managed=$(
  cat <<'MANAGED_SETTINGS'
{{ .managed }}
MANAGED_SETTINGS
)

current=$(cat)
if [[ -z "$current" ]]; then
  current='{}'
fi

printf '%s' "$current" | jq --argjson managed "$managed" '
  def orca_group:
    any(.hooks[]?; (.command? // "") | contains("/.orca/agent-hooks/"));

  ((.hooks // {})
    | with_entries(.value = [.value[]? | select(orca_group)])
    | with_entries(select(.value | length > 0))) as $orca
  | $managed
  | reduce ($orca | to_entries[]) as $event (.;
      .hooks[$event.key] = ((.hooks[$event.key] // []) + $event.value))
'
