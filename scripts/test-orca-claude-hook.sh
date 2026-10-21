#!/usr/bin/env bash
# Regression tests for orca-claude-stop-held and orca-claude-hook.
# Orca announces a Claude turn as complete when the turn only waits for background
# work; the guard drops that Stop, and the hook must leave the workspace status alone.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_HOME="$TMP_DIR/home"
BIN_DIR="$FAKE_HOME/.local/bin"
HOOK_SCRIPT="$FAKE_HOME/.orca/agent-hooks/claude-hook.sh"
ORCA_LOG="$TMP_DIR/orca.log"
mkdir -p "$BIN_DIR" "$(dirname "$HOOK_SCRIPT")" "$TMP_DIR/path"
cp "$REPO_ROOT/home/dot_local/bin/executable_orca-claude-stop-held" "$BIN_DIR/orca-claude-stop-held"
cp "$REPO_ROOT/home/dot_local/bin/executable_orca-claude-hook" "$BIN_DIR/orca-claude-hook"
chmod +x "$BIN_DIR/orca-claude-stop-held" "$BIN_DIR/orca-claude-hook"

# Version-manager shims read config from $HOME, which these tests replace.
real_jq=$(mise which jq 2>/dev/null || command -v jq) || {
  echo "test-orca-claude-hook: jq is required" >&2
  exit 1
}
ln -s "$real_jq" "$TMP_DIR/path/jq"
export PATH="$TMP_DIR/path:$PATH"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Fake Orca CLI: logs every call, because the hook must not change the workspace.
cat >"$TMP_DIR/path/orca" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$ORCA_LOG"
echo '{"ok":true}'
EOF
chmod +x "$TMP_DIR/path/orca"

held() {
  "$BIN_DIR/orca-claude-stop-held" <<<"$1"
}

expect_held() {
  local label=$1 payload=$2
  held "$payload" || fail "$label should be held"
}

expect_not_held() {
  local label=$1 payload=$2 status=0
  held "$payload" || status=$?
  [[ "$status" -eq 1 ]] || fail "$label should not be held (exit $status)"
}

running_shell='{"id":"b1","type":"shell","status":"running"}'
expect_held 'Stop with a running shell' "{\"hook_event_name\":\"Stop\",\"background_tasks\":[$running_shell]}"
expect_held 'Stop with a running monitor' '{"hook_event_name":"Stop","background_tasks":[{"type":"monitor","status":"pending"}]}'
expect_not_held 'Stop with finished work' '{"hook_event_name":"Stop","background_tasks":[{"type":"shell","status":"completed"}],"session_crons":[]}'
expect_not_held 'Stop without background work' '{"hook_event_name":"Stop","background_tasks":[]}'
expect_not_held 'Stop from an older Claude build' '{"hook_event_name":"Stop"}'
expect_not_held 'Stop with only an idle teammate' '{"hook_event_name":"Stop","background_tasks":[{"type":"teammate","status":"running"}]}'
expect_not_held 'interrupted Stop' "{\"hook_event_name\":\"Stop\",\"is_interrupt\":true,\"background_tasks\":[$running_shell]}"
expect_not_held 'StopFailure' "{\"hook_event_name\":\"StopFailure\",\"background_tasks\":[$running_shell]}"
expect_not_held 'subagent Stop' "{\"hook_event_name\":\"Stop\",\"agent_id\":\"a1\",\"background_tasks\":[$running_shell]}"
status=0
held 'not json' 2>/dev/null || status=$?
[[ "$status" -eq 2 ]] || fail "unreadable payload should exit 2 (exit $status)"

# Shaped like Orca's managed script: the guard must sit right after the payload read.
cat >"$HOOK_SCRIPT" <<'EOF'
#!/bin/sh
printf "{}\n"
payload=$({ command -p cat 2>/dev/null || cat; })
if [ -z "$payload" ]; then
  exit 0
fi
printf '%s\n' "$payload" >>"$ORCA_FORWARDED"
EOF
chmod 755 "$HOOK_SCRIPT"

run_hook() {
  HOME="$FAKE_HOME" ORCA_WORKTREE_ID=repo::/work CLAUDE_CODE_ENTRYPOINT=cli \
    ORCA_LOG="$ORCA_LOG" "$BIN_DIR/orca-claude-hook" <<<"$1"
}

: >"$ORCA_LOG"
output=$(run_hook '{"hook_event_name":"SessionStart","source":"startup"}')
[[ -z "$output" ]] || fail "SessionStart wrote to stdout: $output"
[[ "$(grep -c 'dotfiles:orca-claude-stop-held' "$HOOK_SCRIPT")" -eq 1 ]] || fail 'guard was not installed once'
[[ "$(sed -n 4p "$HOOK_SCRIPT")" == '# dotfiles:orca-claude-stop-held (installed by ~/.local/bin/orca-claude-hook)' ]] ||
  fail 'guard is not right after the payload read'
[[ -x "$HOOK_SCRIPT" ]] || fail 'patched Orca script lost its executable bit'
run_hook '{"hook_event_name":"SessionStart","source":"resume"}'
[[ "$(grep -c 'dotfiles:orca-claude-stop-held' "$HOOK_SCRIPT")" -eq 1 ]] || fail 'guard was installed twice'

forward() {
  local forwarded="$TMP_DIR/forwarded"
  : >"$forwarded"
  HOME="$FAKE_HOME" ORCA_FORWARDED="$forwarded" /bin/sh "$HOOK_SCRIPT" <<<"$1" >/dev/null
  [[ -s "$forwarded" ]]
}
forward "{\"hook_event_name\":\"Stop\",\"background_tasks\":[$running_shell]}" && fail 'Orca received a held Stop'
forward '{"hook_event_name":"Stop","background_tasks":[]}' || fail 'Orca did not receive a final Stop'
forward "{\"hook_event_name\":\"PostToolUse\",\"tool_name\":\"Bash\",\"background_tasks\":[$running_shell]}" ||
  fail 'Orca did not receive a tool event'

# An Orca build that reads the payload differently must fail loudly, not run unguarded.
sed -i.bak 's/^payload=.*/payload=$(cat)/' "$HOOK_SCRIPT" && rm -f "$HOOK_SCRIPT.bak"
sed -i.bak '/dotfiles:orca-claude-stop-held/,+1d' "$HOOK_SCRIPT" && rm -f "$HOOK_SCRIPT.bak"
if run_hook '{"hook_event_name":"SessionStart"}' 2>"$TMP_DIR/err"; then
  fail 'unexpected Orca script shape was accepted'
fi
grep -Fq 'Orca changed how claude-hook.sh reads the payload' "$TMP_DIR/err" || fail 'shape error was not reported'

# The sidebar groups workspaces by status, so a prompt must not move the workspace.
rm -f "$HOOK_SCRIPT"
output=$(run_hook '{"hook_event_name":"UserPromptSubmit","prompt":"go"}')
[[ -z "$output" ]] || fail "UserPromptSubmit wrote to stdout: $output"
[[ ! -s "$ORCA_LOG" ]] || fail "the hook called the Orca CLI: $(cat "$ORCA_LOG")"

echo 'test-orca-claude-hook: OK'
