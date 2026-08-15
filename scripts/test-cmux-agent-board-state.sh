#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SCRIPT="$REPO_ROOT/home/dot_local/libexec/cmux/executable_agent-board-state"
readonly SIDEBAR="$REPO_ROOT/home/dot_local/share/cmux/agent-board.swift"
readonly SHELL_HOOKS="$REPO_ROOT/home/private_dot_config/zsh/cmux-agent-board.zsh"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-agent-board-state-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mock_cmux="$test_dir/cmux"
calls_file="$test_dir/calls"
flock_calls="$test_dir/flock-calls"
read_calls="$test_dir/read-calls"

cat >"$mock_cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == '--json tree --workspace workspace-id' ]]; then
  printf '%s\n' "$*" >>"$MOCK_READ_CALLS"
  jq -n \
    --arg workspace_title "${MOCK_WORKSPACE_TITLE:-workspace}" \
    --arg surface_title "${MOCK_SURFACE_TITLE:-surface}" '
      {
        caller: {surface_ref: "surface:1"},
        windows: [{workspaces: [{
          id: "workspace-id",
          ref: "workspace:1",
          title: $workspace_title,
          panes: [{surfaces: [{
            id: "surface-id",
            ref: "surface:1",
            title: $surface_title
          }]}]
        }]}]
      }
    '
  exit 0
fi

if [[ "${1:-}" == 'workspace-action' || "${1:-}" == 'tab-action' ]]; then
  printf '%s\n' "$*" >>"$MOCK_CALLS_FILE"
  exit 0
fi

printf 'unexpected cmux arguments: %s\n' "$*" >&2
exit 1
MOCK
chmod +x "$mock_cmux"

cat >"$test_dir/flock" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$MOCK_FLOCK_CALLS"
MOCK
chmod +x "$test_dir/flock"

run_state() {
  PATH="$test_dir:$PATH" \
    MOCK_CALLS_FILE="$calls_file" \
    MOCK_FLOCK_CALLS="$flock_calls" \
    MOCK_READ_CALLS="$read_calls" \
    CMUX_WORKSPACE_ID='workspace-id' \
    CMUX_SURFACE_ID='surface-id' \
    CMUX_AGENT_BOARD_TITLE_LOCK_DIR="$test_dir/title-locks" \
    bash "$SCRIPT" "$@"
}

working_marker=$'\342\201\240\342\200\213\342\201\240'
stopped_marker=$'\342\201\240\342\200\214\342\201\240'
input_marker=$'\342\201\240\342\200\215\342\201\240'

run_state working >/dev/null
grep -Fq -- "tab-action --surface surface-id --action rename --title surface${working_marker}" "$calls_file"
[[ $(wc -l <"$read_calls") -eq 1 ]]
grep -Fxq -- '--json tree --workspace workspace-id' "$read_calls"
if grep -Fq 'workspace-action' "$calls_file"; then
  printf 'clean workspace title was unexpectedly renamed\n' >&2
  exit 1
fi

force_flock_env="$test_dir/force-flock.bash"
cat >"$force_flock_env" <<'ENV'
command() {
  if [[ "${1:-}" == "-v" && "${2:-}" == "lockf" ]]; then
    return 1
  fi
  builtin command "$@"
}
ENV
: >"$calls_file"
BASH_ENV="$force_flock_env" run_state working >/dev/null
grep -Fxq -- '-w 5 9' "$flock_calls"

: >"$calls_file"
MOCK_SURFACE_TITLE="surface${working_marker}" run_state working >/dev/null
[[ ! -s "$calls_file" ]]

MOCK_WORKSPACE_TITLE="workspace${working_marker}" \
  MOCK_SURFACE_TITLE="surface${working_marker}" \
  run_state input >/dev/null
grep -Fq -- "tab-action --surface surface-id --action rename --title surface${input_marker}" "$calls_file"
grep -Fq -- 'workspace-action --workspace workspace-id --action rename --title workspace' "$calls_file"

: >"$calls_file"
MOCK_SURFACE_TITLE="surface${stopped_marker}" run_state clear >/dev/null
grep -Fq -- 'tab-action --surface surface-id --action rename --title surface' "$calls_file"

: >"$calls_file"
MOCK_WORKSPACE_TITLE="workspace${stopped_marker}" run_state clear >/dev/null
grep -Fq -- 'workspace-action --workspace workspace-id --action rename --title workspace' "$calls_file"
if grep -Fq 'tab-action' "$calls_file"; then
  printf 'marker-free surface was unexpectedly renamed during workspace migration\n' >&2
  exit 1
fi

: >"$calls_file"
run_state stopped >/dev/null
grep -Fq -- "tab-action --surface surface-id --action rename --title surface${stopped_marker}" "$calls_file"

: >"$calls_file"
MOCK_SURFACE_TITLE="surface${working_marker}" run_state idle >/dev/null
grep -Fq -- "tab-action --surface surface-id --action rename --title surface" "$calls_file"

shell_home="$test_dir/home"
shell_calls="$test_dir/shell-calls"
mkdir -p "$shell_home/.local/libexec/cmux"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" "$1" >>"$MOCK_SHELL_CALLS"' \
  >"$shell_home/.local/libexec/cmux/agent-board-state"
chmod +x "$shell_home/.local/libexec/cmux/agent-board-state"

HOME="$shell_home" MOCK_SHELL_CALLS="$shell_calls" \
  CMUX_WORKSPACE_ID='workspace-id' CMUX_SURFACE_ID='surface-id' \
  zsh -dfc '
    set -e
    source "$1"
    _cmux_agent_board_command_finished
    [[ ! -e "$MOCK_SHELL_CALLS" ]]
    _cmux_agent_board_command_started
    _cmux_agent_board_command_finished
  ' _ "$SHELL_HOOKS"
grep -Fxq 'working' "$shell_calls"
grep -Fxq 'idle' "$shell_calls"
grep -Fq '"$_zsh_config_dir/cmux-agent-board.zsh"' "$REPO_ROOT/home/dot_zshrc"

if CMUX_WORKSPACE_ID='' PATH="$test_dir:$PATH" bash "$SCRIPT" idle >/dev/null 2>&1; then
  printf 'missing workspace ID unexpectedly succeeded\n' >&2
  exit 1
fi

if CMUX_WORKSPACE_ID='workspace-id' CMUX_SURFACE_ID='' PATH="$test_dir:$PATH" \
  bash "$SCRIPT" stopped >/dev/null 2>&1; then
  printf 'missing surface ID unexpectedly succeeded\n' >&2
  exit 1
fi

jq -e '
  .hooks.SessionStart[0].hooks[0].command | contains("agent-board-state\" stopped")
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null
jq -e '
  .hooks.PermissionRequest[0].hooks[0].command | contains("agent-board-state\" input")
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null
jq -e '
  [.hooks.PreToolUse[]
    | select(any(.hooks[]; .command | contains("agent-board-state\" working")))
    | .matcher] == ["^(?!AskUserQuestion$).*"]
  and
  [.hooks.PreToolUse[]
    | select(any(.hooks[]; .command | contains("agent-board-state\" input")))
    | .matcher] == ["AskUserQuestion"]
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null
jq -e '
  .hooks.UserPromptSubmit[0].hooks[0].command | contains("agent-board-state\" working")
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null
jq -e '
  .hooks.Stop[0].hooks[0].command | contains("agent-board-state\" stopped")
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null
jq -e '
  .hooks.SessionEnd[0].hooks[0].command | contains("agent-board-state\" clear")
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null

rendered_codex_hooks=$(chezmoi execute-template <"$REPO_ROOT/home/dot_codex/hooks.json.tmpl")
jq -e '
  any(.hooks.SessionStart[]?.hooks[]?; .command | contains("agent-board-state\" stopped"))
  and
  any(.hooks.Stop[]?.hooks[]?; .command | contains("agent-board-state\" stopped"))
  and
  any(.hooks.SessionEnd[]?.hooks[]?; .command | contains("agent-board-state\" clear"))
  and
  ([.hooks[][]?.hooks[]?
   | select(.command | contains("agent-board-state"))] as $state_hooks
   | ($state_hooks | length) == 6
   and all($state_hooks[];
     if (.command | contains("agent-board-state\" clear"))
     then .timeout == 3
     else .timeout == 5
     end))
' <<<"$rendered_codex_hooks" >/dev/null

grep -Fq "if title.hasSuffix(\"${stopped_marker}\") { return \"stopped\" }" "$SIDEBAR"
python3 - "$SIDEBAR" <<'PY'
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
agent_state = source.split("func agentState", 1)[1].split("func stateTint", 1)[0]
tab_state = source.split("func tabState", 1)[1].split("func workspaceRow", 1)[0]
assert agent_state.rstrip().endswith('return "idle"\n}')
assert "workspace.tabs.contains" in agent_state
assert 'managedTitleState($0.title) == "stopped"' in agent_state
assert "managedTitleState(tab.title)" in tab_state
assert 'if state == "stopped" { return "#FFD60A" }' in source
assert "workspaceStatusText" not in source
assert "workspaceMemoText" not in source
assert "cmux-workspace-note" not in source
assert "noteButton" not in source
assert "statusPill" not in source
assert '"surface.create"' in source
assert "cmux/agent-board-diff-open" in source
assert 'initial_command: "~/.local/libexec/cmux/agent-board-diff-open \\(pathToken) && exit"' in source
assert 'cmux("file.open"' not in source
assert "func diffTreeRow" in source
assert "func diffTreeList" in source
assert "diffTreeOf(workspace.directory)" in source
assert 'Image(systemName: "folder.fill")' in source
assert "func unreadIndicator()" not in source
assert "unreadBadge" not in source
assert "workspace.unread" not in source
assert "unreadTotal" not in source
assert 'Text("\\(count)")' not in source
PY

printf 'cmux Agent Board state tests passed\n'
