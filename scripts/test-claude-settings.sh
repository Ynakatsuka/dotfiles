#!/usr/bin/env bash
# Regression tests for the Claude settings modify script and its Orca hook preservation.
# Orca installs its Claude status hooks only at app startup; if chezmoi apply drops them,
# Claude panes stop reporting sessions and are not resumed after a restart.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODIFY_TEMPLATE="$REPO_ROOT/home/dot_claude/modify_settings.json.tmpl"
MANAGED_SETTINGS="$REPO_ROOT/home/.chezmoitemplates/claude-settings.json"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CHEZMOI_BIN="$(command -v chezmoi)" || {
  echo "test-claude-settings: chezmoi is required" >&2
  exit 1
}
CHEZMOI_CONFIG="$TMP_DIR/chezmoi.toml"
MODIFY_SCRIPT="$TMP_DIR/modify-settings.sh"
: >"$CHEZMOI_CONFIG"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

"$CHEZMOI_BIN" --config "$CHEZMOI_CONFIG" --source "$REPO_ROOT" \
  execute-template <"$MODIFY_TEMPLATE" >"$MODIFY_SCRIPT"

orca_command='/bin/sh "${HOME-}/.orca/agent-hooks/claude-hook.sh"'
cat >"$TMP_DIR/current.json" <<EOF
{
  "unmanagedKey": true,
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": $(jq -Rn --arg c "$orca_command" '$c'), "timeout": 10}]}
    ],
    "PreToolUse": [
      {"matcher": "*", "hooks": [{"type": "command", "command": $(jq -Rn --arg c "$orca_command" '$c')}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "~/stale-hook.sh"}]}
    ]
  }
}
EOF

output="$(bash "$MODIFY_SCRIPT" <"$TMP_DIR/current.json")"

jq -e --arg c "$orca_command" \
  '[.hooks.SessionStart[]?.hooks[]? | select(.command == $c)] | length == 1' \
  <<<"$output" >/dev/null || fail "Orca SessionStart hook was not preserved"
jq -e --arg c "$orca_command" \
  '[.hooks.PreToolUse[]? | select(.matcher == "*") | .hooks[] | select(.command == $c)] | length == 1' \
  <<<"$output" >/dev/null || fail "Orca PreToolUse hook was not preserved"
jq -e '[.. | .command? // empty | select(. == "~/stale-hook.sh")] | length == 0' \
  <<<"$output" >/dev/null || fail "non-Orca hook from the current file was kept"
jq -e 'has("unmanagedKey") | not' <<<"$output" >/dev/null || fail "unmanaged key was kept"

# Removing the preserved Orca groups must leave exactly the managed settings.
jq -e --slurpfile managed <(jq . "$MANAGED_SETTINGS") '
  .hooks |= (with_entries(.value |= map(select(
    any(.hooks[]?; (.command? // "") | contains("/.orca/agent-hooks/")) | not)))
    | with_entries(select(.value | length > 0)))
  | . == $managed[0]
' <<<"$output" >/dev/null || fail "managed settings were not applied unchanged"

empty_output="$(bash "$MODIFY_SCRIPT" </dev/null)"
jq -e --slurpfile managed <(jq . "$MANAGED_SETTINGS") '. == $managed[0]' \
  <<<"$empty_output" >/dev/null || fail "empty current file did not render the managed settings"

echo "test-claude-settings: OK"
