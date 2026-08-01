#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_cmux-agent-status-sync"
SIDEBAR_SOURCE="$REPO_ROOT/home/private_dot_config/cmux/sidebars/agent-board.swift"
SYNC_MODULE="$REPO_ROOT/home/dot_hammerspoon/cmux_agent_status_sync.lua"
HAMMERSPOON_INIT="$REPO_ROOT/home/dot_hammerspoon/init.lua"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CMUX_BIN="$TMP_DIR/bin/cmux"
SYNC_SCRIPT="$TMP_DIR/cmux-agent-status-sync"
JQ_BIN="$(command -v jq)"
CUSTOM_IDLE_SUFFIX='⁣⁤⁢⁣⁤⁢⁣⁤'
AUTO_IDLE_SUFFIX='⁣⁢⁤⁣⁢⁤⁣⁢'

grep -Fq 'func managedDescriptionBranch(_ workspace) -> String {' "$SIDEBAR_SOURCE" || {
  echo 'FAIL: Agent Board sidebar does not parse the managed branch description' >&2
  exit 1
}
grep -Fq 'let managedBranch = managedDescriptionBranch(workspace)' "$SIDEBAR_SOURCE" || {
  echo 'FAIL: Agent Board sidebar does not read the managed branch after workspace.branch' >&2
  exit 1
}
official_branch_line="$(grep -n -m 1 'if workspace.branch != nil && workspace.branch != "" {' "$SIDEBAR_SOURCE" | cut -d: -f1)"
managed_branch_line="$(grep -n -m 1 'let managedBranch = managedDescriptionBranch(workspace)' "$SIDEBAR_SOURCE" | cut -d: -f1)"
[ "$managed_branch_line" -gt "$official_branch_line" ] || {
  echo 'FAIL: Agent Board sidebar checks the managed branch before workspace.branch' >&2
  exit 1
}

test -f "$SYNC_MODULE" || {
  echo 'FAIL: cmux Agent Board sync module is missing' >&2
  exit 1
}
grep -Fqx 'local cmuxAgentStatusSync = require("cmux_agent_status_sync")' "$HAMMERSPOON_INIT" || {
  echo 'FAIL: Hammerspoon does not load the cmux Agent Board sync module' >&2
  exit 1
}
grep -Fqx 'cmuxAgentStatusSync.start()' "$HAMMERSPOON_INIT" || {
  echo 'FAIL: Hammerspoon does not start the cmux Agent Board sync module' >&2
  exit 1
}
for required_line in \
  '"--name", "sidebar.metadata.updated",' \
  '"--name", "sidebar.metadata.cleared",' \
  '"--no-ack",' \
  '"--no-heartbeat",' \
  '    runSync()' \
  '            fail("Event stream exited unexpectedly: " .. detail)'; do
  grep -Fq "$required_line" "$SYNC_MODULE" || {
    printf 'FAIL: cmux sync module is missing required behavior: %s\n' "$required_line" >&2
    exit 1
  }
done
for required_line in \
  'local branchSyncInterval = 30' \
  'branchTimer = hs.timer.doEvery(branchSyncInterval, runBranchSync)' \
  'syncTask = hs.task.new(syncPath, completion, arguments)' \
  'runTask({ "--branch-only" })' \
  'pendingBranchSync = false' \
  'running = not terminal and eventTask ~= nil and branchTimer ~= nil,'; do
  grep -Fq "$required_line" "$SYNC_MODULE" || {
    printf 'FAIL: cmux sync module is missing branch-only scheduling behavior: %s\n' "$required_line" >&2
    exit 1
  }
done
awk '
  /runSync = function\(\)/ { in_run_sync = 1; next }
  in_run_sync && /pendingBranchSync = false/ { clears_pending_branch = 1 }
  in_run_sync && /runTask\(\{\}\)/ { exit(clears_pending_branch ? 0 : 1) }
  END { exit(clears_pending_branch ? 0 : 1) }
' "$SYNC_MODULE" || {
  echo 'FAIL: full sync does not clear a pending branch-only sync' >&2
  exit 1
}

mkdir -p "$TMP_DIR/bin"

cat >"$CMUX_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

list_workspaces() {
    printf '%s\n' 'list-workspaces' >>"$CMUX_TEST_WORKSPACE_CALLS"
    workspace_call_count="$(<"$CMUX_TEST_WORKSPACE_CALLS_COUNT")"
    workspace_call_count=$((workspace_call_count + 1))
    printf '%s' "$workspace_call_count" >"$CMUX_TEST_WORKSPACE_CALLS_COUNT"
    [ "${CMUX_TEST_WORKSPACES_RESULT:-success}" = success ] || exit 1
    if [ "$workspace_call_count" -eq 1 ]; then
      printf '%s\n' "${CMUX_TEST_WORKSPACES_INITIAL:-$CMUX_TEST_WORKSPACES}"
    else
      printf '%s\n' "${CMUX_TEST_WORKSPACES_LATEST:-$CMUX_TEST_WORKSPACES}"
    fi
}

case "${1:-}" in
  --id-format)
    [ "${2:-}" = both ] || exit 64
    [ "${3:-}" = list-workspaces ] || exit 64
    [ "${4:-}" = --json ] || exit 64
    list_workspaces
    ;;
  list-workspaces)
    exit 64
    ;;
  list-status)
    workspace_ref="${3:-}"
    printf 'list-status %s\n' "$workspace_ref" >>"$CMUX_TEST_STATUS_CALLS"
    case "$workspace_ref" in
      workspace-id-7) [ "${CMUX_TEST_STATUS_RESULT_WORKSPACE_7:-${CMUX_TEST_STATUS_RESULT:-success}}" = success ] || exit 1 ;;
      workspace-id-8) [ "${CMUX_TEST_STATUS_RESULT_WORKSPACE_8:-${CMUX_TEST_STATUS_RESULT:-success}}" = success ] || exit 1 ;;
      *) exit 64 ;;
    esac
    case "$workspace_ref" in
      workspace-id-7) printf '%s\n' "${CMUX_TEST_STATUS_WORKSPACE_7:-}" ;;
      workspace-id-8) printf '%s\n' "${CMUX_TEST_STATUS_WORKSPACE_8:-}" ;;
    esac
    ;;
  rpc)
    [ "${2:-}" = extension.sidebar.snapshot ] || exit 64
    [ "${3:-}" = '{}' ] || exit 64
    [ "${CMUX_TEST_SNAPSHOT_RESULT:-success}" = success ] || exit 1
    snapshot_call_count="$(<"$CMUX_TEST_SNAPSHOT_CALLS")"
    snapshot_call_count=$((snapshot_call_count + 1))
    printf '%s' "$snapshot_call_count" >"$CMUX_TEST_SNAPSHOT_CALLS"
    if [ "$snapshot_call_count" -eq 1 ]; then
      printf '%s\n' "$CMUX_TEST_SNAPSHOT_INITIAL"
    else
      printf '%s\n' "$CMUX_TEST_SNAPSHOT_LATEST"
    fi
    ;;
  workspace-action)
    printf '%s\n' "$*" >>"$CMUX_TEST_ACTIONS"
    [ "${CMUX_TEST_ACTION_RESULT:-success}" = success ] || exit 1
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$CMUX_BIN"

sed \
  -e "s|readonly CMUX_BIN=\"/opt/homebrew/bin/cmux\"|readonly CMUX_BIN=\"$CMUX_BIN\"|" \
  -e "s|readonly JQ_BIN=\"/opt/homebrew/bin/jq\"|readonly JQ_BIN=\"$JQ_BIN\"|" \
  "$SOURCE_SCRIPT" >"$SYNC_SCRIPT"
chmod +x "$SYNC_SCRIPT"

export CMUX_TEST_ACTIONS="$TMP_DIR/actions"
export CMUX_TEST_STATUS_CALLS="$TMP_DIR/status-calls"
export CMUX_TEST_WORKSPACE_CALLS="$TMP_DIR/workspace-calls"
export CMUX_TEST_WORKSPACE_CALLS_COUNT="$TMP_DIR/workspace-calls-count"
export CMUX_TEST_SNAPSHOT_CALLS="$TMP_DIR/snapshot-calls"

reset_case() {
  : >"$CMUX_TEST_ACTIONS"
  : >"$CMUX_TEST_STATUS_CALLS"
  : >"$CMUX_TEST_WORKSPACE_CALLS"
  printf '0' >"$CMUX_TEST_WORKSPACE_CALLS_COUNT"
  printf '0' >"$CMUX_TEST_SNAPSHOT_CALLS"
  unset CMUX_TEST_WORKSPACES_RESULT CMUX_TEST_WORKSPACES_INITIAL CMUX_TEST_WORKSPACES_LATEST CMUX_TEST_STATUS_RESULT CMUX_TEST_STATUS_RESULT_WORKSPACE_7 CMUX_TEST_STATUS_RESULT_WORKSPACE_8 CMUX_TEST_ACTION_RESULT CMUX_TEST_SNAPSHOT_RESULT
  CMUX_TEST_SNAPSHOT_INITIAL="$(jq -cn '{workspaces:[{id:"workspace-id-7",ref:"workspace:7",description:"",branch_summary:"feature/agent-board"}]}')"
  CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
  export CMUX_TEST_SNAPSHOT_INITIAL CMUX_TEST_SNAPSHOT_LATEST
}

assert_action() {
  local expected=$1 actual
  actual="$(<"$CMUX_TEST_ACTIONS")"
  [ "$actual" = "$expected" ] || {
    printf 'FAIL: unexpected cmux action\nexpected: %s\nactual: %s\n' "$expected" "$actual" >&2
    exit 1
  }
}

assert_no_action() {
  [ ! -s "$CMUX_TEST_ACTIONS" ] || {
    printf 'FAIL: unexpected cmux action: %s\n' "$(<"$CMUX_TEST_ACTIONS")" >&2
    exit 1
  }
}

assert_no_status_call() {
  [ ! -s "$CMUX_TEST_STATUS_CALLS" ] || {
    printf 'FAIL: branch-only sync listed agent status: %s\n' "$(<"$CMUX_TEST_STATUS_CALLS")" >&2
    exit 1
  }
}

assert_no_workspace_call() {
  [ ! -s "$CMUX_TEST_WORKSPACE_CALLS" ] || {
    printf 'FAIL: branch-only sync listed workspaces: %s\n' "$(<"$CMUX_TEST_WORKSPACE_CALLS")" >&2
    exit 1
  }
}

set_workspace() {
  local title=$1 description=$2
  export CMUX_TEST_WORKSPACES
  CMUX_TEST_WORKSPACES="$(jq -cn --arg title "$title" --arg description "$description" \
    '{workspaces:[{id:"workspace-id-7",ref:"workspace:7",title:$title,has_custom_title:true,description:$description}]}')"
  CMUX_TEST_WORKSPACES_INITIAL="$CMUX_TEST_WORKSPACES"
  CMUX_TEST_WORKSPACES_LATEST="$CMUX_TEST_WORKSPACES"
  export CMUX_TEST_WORKSPACES_INITIAL CMUX_TEST_WORKSPACES_LATEST
  CMUX_TEST_SNAPSHOT_INITIAL="$(jq -cn --arg description "$description" \
    '{workspaces:[{id:"workspace-id-7",ref:"workspace:7",description:$description,branch_summary:"feature/agent-board"}]}')"
  CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
  export CMUX_TEST_SNAPSHOT_INITIAL CMUX_TEST_SNAPSHOT_LATEST
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_STATUS_WORKSPACE_7=$'codex=Idle\nclaude_code=Idle'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action $'workspace-action --action set-description --description agent-board-branch:feature/agent-board --workspace workspace-id-7\nworkspace-action --action rename --title Project'"${CUSTOM_IDLE_SUFFIX}"' --workspace workspace-id-7'
grep -Fq 'added custom-title idle marker' "$TMP_DIR/stdout" || {
  echo 'FAIL: idle status did not add a marker' >&2
  exit 1
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_STATUS_WORKSPACE_7=$'codex=Idle\nclaude_code=Idle'
"$SYNC_SCRIPT" --dry-run >"$TMP_DIR/stdout"
assert_no_action
grep -Fq 'would update Agent Board branch description' "$TMP_DIR/stdout" || {
  echo 'FAIL: dry-run did not report the pending branch description update' >&2
  exit 1
}
grep -Fq 'would add custom-title idle marker' "$TMP_DIR/stdout" || {
  echo 'FAIL: dry-run did not report the pending idle marker update' >&2
  exit 1
}

reset_case
set_workspace 'Project' $'Personal note\nSecond line\n\n'
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action $'workspace-action --action set-description --description Personal note\nSecond line\n\n\nagent-board-branch:feature/agent-board --workspace workspace-id-7'

reset_case
set_workspace 'Project' $'Personal note\nagent-board-branch:old-branch\nSecond line'
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action $'workspace-action --action set-description --description Personal note\nSecond line\nagent-board-branch:feature/agent-board --workspace workspace-id-7'

reset_case
set_workspace 'Project' $'Personal note\nagent-board-branch:old-branch\nSecond line'
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":"Personal note\nagent-board-branch:old-branch\nSecond line","branch_summary":null}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action $'workspace-action --action set-description --description Personal note\nSecond line --workspace workspace-id-7'

reset_case
set_workspace 'Project' 'agent-board-branch:old-branch'
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":"agent-board-branch:old-branch","branch_summary":""}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action 'workspace-action --action clear-description --workspace workspace-id-7'

reset_case
set_workspace 'Project' $'Personal note\nagent-board-branch:feature/agent-board'
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_no_action

reset_case
set_workspace 'Project' 'agent-board-branch:feature/agent-board'
export CMUX_TEST_STATUS_RESULT=failure
"$SYNC_SCRIPT" --branch-only >"$TMP_DIR/stdout"
assert_no_action
assert_no_status_call
assert_no_workspace_call

reset_case
set_workspace 'Project' ''
export CMUX_TEST_SNAPSHOT_LATEST='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":"User note","branch_summary":"feature/agent-board"}]}'
"$SYNC_SCRIPT" --branch-only >"$TMP_DIR/stdout"
assert_action $'workspace-action --action set-description --description User note\nagent-board-branch:feature/agent-board --workspace workspace-id-7'
assert_no_status_call
assert_no_workspace_call

reset_case
set_workspace 'Project' ''
export CMUX_TEST_SNAPSHOT_LATEST='{"workspaces":[]}'
"$SYNC_SCRIPT" --branch-only >"$TMP_DIR/stdout"
assert_no_action
assert_no_status_call
assert_no_workspace_call
grep -Fq 'workspace disappeared before branch update' "$TMP_DIR/stdout" || {
  echo 'FAIL: disappeared workspace was not reported' >&2
  exit 1
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_SNAPSHOT_LATEST='{"workspaces":[{"id":"workspace-id-reused","ref":"workspace:7","description":"","branch_summary":"feature/agent-board"}]}'
"$SYNC_SCRIPT" --branch-only >"$TMP_DIR/stdout"
assert_no_action
assert_no_status_call
assert_no_workspace_call
grep -Fq 'workspace:7: workspace disappeared before branch update' "$TMP_DIR/stdout" || {
  echo 'FAIL: ref reuse during branch update was not treated as disappearance' >&2
  exit 1
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
export CMUX_TEST_ACTION_RESULT=failure
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: branch description action failure was accepted' >&2
  exit 1
fi
assert_action 'workspace-action --action set-description --description agent-board-branch:feature/agent-board --workspace workspace-id-7'
grep -Fq 'failed to update description' "$TMP_DIR/stderr" || {
  echo 'FAIL: branch description action failure was not reported' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES="{\"workspaces\":[{\"id\":\"workspace-id-7\",\"ref\":\"workspace:7\",\"title\":\"Project${AUTO_IDLE_SUFFIX}\",\"has_custom_title\":false,\"description\":null}]}"
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":null,"branch_summary":null}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
export CMUX_TEST_STATUS_WORKSPACE_7=''
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action 'workspace-action --action clear-name --workspace workspace-id-7'
grep -Fq 'cleared auto-title idle marker' "$TMP_DIR/stdout" || {
  echo 'FAIL: missing status did not remove a stale marker' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES="{\"workspaces\":[{\"id\":\"workspace-id-7\",\"ref\":\"workspace:7\",\"title\":\"Project${CUSTOM_IDLE_SUFFIX}\",\"has_custom_title\":true,\"description\":null}]}"
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":null,"branch_summary":null}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
export CMUX_TEST_STATUS_WORKSPACE_7=$'codex=Idle\nclaude_code=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action 'workspace-action --action rename --title Project --workspace workspace-id-7'
grep -Fq 'removed custom-title idle marker' "$TMP_DIR/stdout" || {
  echo 'FAIL: mixed statuses were classified as idle' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES="{\"workspaces\":[{\"id\":\"workspace-id-7\",\"ref\":\"workspace:7\",\"title\":\"Project${CUSTOM_IDLE_SUFFIX}\",\"has_custom_title\":true,\"description\":null}]}"
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":null,"branch_summary":null}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_action 'workspace-action --action rename --title Project --workspace workspace-id-7'
grep -Fq 'removed custom-title idle marker' "$TMP_DIR/stdout" || {
  echo 'FAIL: running status was classified as idle' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","title":"Project","has_custom_title":true,"description":null}]}'
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Idle'
export CMUX_TEST_STATUS_RESULT=failure
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: status command failure was accepted' >&2
  exit 1
fi
grep -Fq 'failed to list status' "$TMP_DIR/stderr" || {
  echo 'FAIL: status command failure was not reported' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","title":"Gone","has_custom_title":true,"description":null},{"id":"workspace-id-8","ref":"workspace:8","title":"Remaining","has_custom_title":true,"description":null}]}'
export CMUX_TEST_WORKSPACES_LATEST='{"workspaces":[{"id":"workspace-id-reused","ref":"workspace:7","title":"Reused","has_custom_title":true,"description":null},{"id":"workspace-id-8","ref":"workspace:8","title":"Remaining","has_custom_title":true,"description":null}]}'
export CMUX_TEST_WORKSPACES="$CMUX_TEST_WORKSPACES_INITIAL"
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":null,"branch_summary":null},{"id":"workspace-id-8","ref":"workspace:8","description":null,"branch_summary":null}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
export CMUX_TEST_STATUS_RESULT_WORKSPACE_7=failure
export CMUX_TEST_STATUS_WORKSPACE_8='codex=Running'
"$SYNC_SCRIPT" >"$TMP_DIR/stdout"
assert_no_action
grep -Fq 'workspace:7: workspace disappeared before status update' "$TMP_DIR/stdout" || {
  echo 'FAIL: disappeared workspace during status update was not reported' >&2
  exit 1
}
grep -Fqx 'list-status workspace-id-7' "$CMUX_TEST_STATUS_CALLS" || {
  echo 'FAIL: status sync did not attempt the disappeared workspace first' >&2
  exit 1
}
grep -Fqx 'list-status workspace-id-8' "$CMUX_TEST_STATUS_CALLS" || {
  echo 'FAIL: status sync did not continue with the remaining workspace' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES_RESULT=failure
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: workspace list command failure was accepted' >&2
  exit 1
fi
grep -Fq 'failed to list cmux workspaces' "$TMP_DIR/stderr" || {
  echo 'FAIL: workspace list command failure was not reported' >&2
  exit 1
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Idle'
export CMUX_TEST_SNAPSHOT_RESULT=failure
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: snapshot command failure was accepted' >&2
  exit 1
fi
grep -Fq 'failed to retrieve cmux sidebar snapshot' "$TMP_DIR/stderr" || {
  echo 'FAIL: snapshot command failure was not reported' >&2
  exit 1
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Idle'
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":"invalid"}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: invalid snapshot data was accepted' >&2
  exit 1
fi
grep -Fq 'invalid cmux sidebar snapshot' "$TMP_DIR/stderr" || {
  echo 'FAIL: invalid snapshot data was not reported' >&2
  exit 1
}

reset_case
set_workspace 'Project' ''
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Idle'
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
"$SYNC_SCRIPT" --branch-only >"$TMP_DIR/stdout"
assert_no_action
assert_no_status_call
assert_no_workspace_call

reset_case
export CMUX_TEST_WORKSPACES='{"workspaces":"invalid"}'
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Idle'
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: invalid workspace data was accepted' >&2
  exit 1
fi
grep -Fq 'invalid workspace list' "$TMP_DIR/stderr" || {
  echo 'FAIL: invalid workspace data was not reported' >&2
  exit 1
}

reset_case
export CMUX_TEST_WORKSPACES='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","title":"Project","has_custom_title":true,"description":null}]}'
export CMUX_TEST_STATUS_WORKSPACE_7='codex=Idle'
export CMUX_TEST_ACTION_RESULT=failure
export CMUX_TEST_SNAPSHOT_INITIAL='{"workspaces":[{"id":"workspace-id-7","ref":"workspace:7","description":null,"branch_summary":null}]}'
export CMUX_TEST_SNAPSHOT_LATEST="$CMUX_TEST_SNAPSHOT_INITIAL"
if "$SYNC_SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo 'FAIL: workspace action failure was accepted' >&2
  exit 1
fi
assert_action "workspace-action --action rename --title Project${CUSTOM_IDLE_SUFFIX} --workspace workspace-id-7"

echo 'test-cmux-agent-status-sync: OK'
