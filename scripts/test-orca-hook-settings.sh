#!/usr/bin/env bash
# Regression tests for agent settings modify scripts and their Orca hook preservation.
# Orca installs its status hooks only at app startup; if chezmoi apply drops them,
# the agent stops reporting sessions and Orca cannot resume it after a restart.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CHEZMOI_BIN="$(command -v chezmoi)" || {
  echo "test-orca-hook-settings: chezmoi is required" >&2
  exit 1
}
CHEZMOI_CONFIG="$TMP_DIR/chezmoi.toml"
: >"$CHEZMOI_CONFIG"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Removing the preserved Orca groups must leave exactly the managed settings.
assert_managed_without_orca() {
  local label=$1 output=$2 managed_settings=$3
  jq -e --slurpfile managed <(jq . "$managed_settings") '
    .hooks |= (with_entries(.value |= map(select(
      any(.hooks[]?; (.command? // "") | contains("/.orca/agent-hooks/")) | not)))
      | with_entries(select(.value | length > 0)))
    | if .hooks == {} then del(.hooks) else . end
    | . == $managed[0]
  ' <<<"$output" >/dev/null || fail "$label managed settings were not applied unchanged"
}

check_agent_settings() {
  local label=$1 modify_template=$2 managed_settings=$3 orca_event=$4 orca_command=$5
  local script="$TMP_DIR/$label-modify.sh" output empty_output

  "$CHEZMOI_BIN" --config "$CHEZMOI_CONFIG" --source "$REPO_ROOT" \
    execute-template <"$modify_template" >"$script"

  jq -n --arg event "$orca_event" --arg command "$orca_command" '{
    unmanagedKey: true,
    hooks: {
      ($event): [{hooks: [{type: "command", command: $command, timeout: 10}]}],
      StaleEvent: [{matcher: "*", hooks: [{type: "command", command: "~/stale-hook.sh"}]}]
    }
  }' >"$TMP_DIR/$label-current.json"

  output="$(bash "$script" <"$TMP_DIR/$label-current.json")"

  jq -e --arg event "$orca_event" --arg command "$orca_command" \
    '[.hooks[$event][]?.hooks[]? | select(.command == $command)] | length == 1' \
    <<<"$output" >/dev/null || fail "$label Orca $orca_event hook was not preserved"
  jq -e '[.. | .command? // empty | select(. == "~/stale-hook.sh")] | length == 0' \
    <<<"$output" >/dev/null || fail "$label non-Orca hook from the current file was kept"
  jq -e 'has("unmanagedKey") | not' <<<"$output" >/dev/null ||
    fail "$label unmanaged key was kept"
  assert_managed_without_orca "$label" "$output" "$managed_settings"

  empty_output="$(bash "$script" </dev/null)"
  jq -e --slurpfile managed <(jq . "$managed_settings") '. == $managed[0]' \
    <<<"$empty_output" >/dev/null || fail "$label empty current file did not render the managed settings"
}

# Claude merges Orca hooks into events that the managed settings also define.
check_agent_settings claude \
  "$REPO_ROOT/home/dot_claude/modify_settings.json.tmpl" \
  "$REPO_ROOT/home/.chezmoitemplates/claude-settings.json" \
  PreToolUse '/bin/sh "${HOME-}/.orca/agent-hooks/claude-hook.sh"'
check_agent_settings gemini \
  "$REPO_ROOT/home/dot_gemini/modify_settings.json.tmpl" \
  "$REPO_ROOT/home/.chezmoitemplates/gemini-settings.json" \
  BeforeTool "/bin/sh '/Users/example/.orca/agent-hooks/gemini-hook.sh'"

echo "test-orca-hook-settings: OK"
