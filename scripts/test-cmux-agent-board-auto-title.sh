#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SCRIPT="$REPO_ROOT/home/dot_local/libexec/cmux/executable_agent-board-auto-title"
readonly STATE_SCRIPT="$REPO_ROOT/home/dot_local/libexec/cmux/executable_agent-board-state"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-agent-board-auto-title-test.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT

mock_bin="$test_dir/bin"
calls_file="$test_dir/cmux-calls"
codex_calls="$test_dir/codex-calls"
claude_calls="$test_dir/claude-calls"
generator_prompt="$test_dir/generator-prompt"
state_dir="$test_dir/state"
mkdir -p "$mock_bin"

cat >"$mock_bin/cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == "--json tree --workspace ${CMUX_WORKSPACE_ID:-workspace-id}" ]]; then
  jq -n \
    --arg workspace_title "${MOCK_WORKSPACE_TITLE:-workspace}" \
    --arg surface_title "${MOCK_SURFACE_TITLE:-surface}" '
      {
        caller: {surface_ref: "surface:1"},
        windows: [{workspaces: [{
          id: env.CMUX_WORKSPACE_ID,
          ref: "workspace:1",
          title: $workspace_title,
          panes: [{surfaces: [{
            id: env.CMUX_SURFACE_ID,
            ref: "surface:1",
            title: $surface_title
          }]}]
        }]}]
      }
    '
  exit 0
fi

if [[ "${1:-}" == "rpc" && "${2:-}" == "surface.list" ]]; then
  if [[ -n "${MOCK_SURFACE_LIST_COUNT_FILE:-}" ]]; then
    count=0
    if [[ -f "$MOCK_SURFACE_LIST_COUNT_FILE" ]]; then
      count=$(<"$MOCK_SURFACE_LIST_COUNT_FILE")
    fi
    count=$((count + 1))
    printf '%s\n' "$count" >"$MOCK_SURFACE_LIST_COUNT_FILE"
    if [[ "$count" -eq 2 && -n "${MOCK_SECOND_SURFACE_READ_SIGNAL:-}" ]]; then
      : >"$MOCK_SECOND_SURFACE_READ_SIGNAL"
      sleep "${MOCK_SECOND_SURFACE_READ_DELAY:-0}"
    fi
  fi
  jq -n \
    --arg title "${MOCK_SURFACE_TITLE:-surface}" \
    --arg surface_id "${CMUX_SURFACE_ID:-surface-id}" \
    --argjson count "${MOCK_SURFACE_COUNT:-1}" '
      {surfaces:
        ([{id: $surface_id, ref: "surface:1", title: $title}]
        + if $count > 1
          then [{id: "other-surface", ref: "surface:2", title: "other"}]
          else []
          end)}
    '
  exit 0
fi

if [[ "$*" == "workspace list --json" ]]; then
  jq -n \
    --arg title "${MOCK_WORKSPACE_TITLE:-workspace}" \
    --arg workspace_id "${CMUX_WORKSPACE_ID:-workspace-id}" \
    '{workspaces: [{id: $workspace_id, ref: "workspace:1", title: $title}]}'
  exit 0
fi

if [[ "${1:-}" == "workspace-action" ]]; then
  printf '%s\n' "$*" >>"$MOCK_CMUX_CALLS"
  failures="${MOCK_WORKSPACE_RENAME_FAILS:-0}"
  if ((failures > 0)); then
    count=0
    if [[ -f "$MOCK_WORKSPACE_RENAME_COUNT_FILE" ]]; then
      count=$(<"$MOCK_WORKSPACE_RENAME_COUNT_FILE")
    fi
    count=$((count + 1))
    printf '%s\n' "$count" >"$MOCK_WORKSPACE_RENAME_COUNT_FILE"
    if ((count <= failures)); then
      exit 1
    fi
  fi
  exit 0
fi

if [[ "${1:-}" == "tab-action" ]]; then
  printf '%s\n' "$*" >>"$MOCK_CMUX_CALLS"
  exit 0
fi

printf 'unexpected cmux arguments: %s\n' "$*" >&2
exit 1
MOCK
chmod +x "$mock_bin/cmux"

cat >"$mock_bin/codex" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

[[ -z "${CMUX_WORKSPACE_ID:-}" ]]
[[ -z "${CMUX_SURFACE_ID:-}" ]]
[[ -z "${CMUX_TAB_ID:-}" ]]
printf '%s\n' "$*" >>"$MOCK_CODEX_CALLS"
printf '%s' "${!#}" >"$MOCK_GENERATOR_PROMPT"
if [[ "${MOCK_CODEX_FAIL:-}" == "1" ]]; then
  exit 42
fi

output_file=""
while (($# > 0)); do
  if [[ "$1" == "--output-last-message" ]]; then
    shift
    output_file="${1:-}"
    break
  fi
  shift
done
[[ -n "$output_file" ]]
printf '%s\n' "${MOCK_GENERATED_TITLE:-Generated title}" >"$output_file"
MOCK
chmod +x "$mock_bin/codex"

cat >"$mock_bin/claude" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

[[ -z "${CMUX_WORKSPACE_ID:-}" ]]
[[ -z "${CMUX_SURFACE_ID:-}" ]]
[[ -z "${CMUX_TAB_ID:-}" ]]
printf '%s\n' "$*" >>"$MOCK_CLAUDE_CALLS"
cat >"$MOCK_GENERATOR_PROMPT"
if [[ "${MOCK_CLAUDE_FAIL:-}" == "1" ]]; then
  exit 43
fi
printf '%s\n' "${MOCK_GENERATED_TITLE:-Generated title}"
MOCK
chmod +x "$mock_bin/claude"

run_hook() {
  local input="$1"
  printf '%s' "$input" | env \
    PATH="$mock_bin:$PATH" \
    CMUX_BIN="$mock_bin/cmux" \
    CMUX_WORKSPACE_ID="${TEST_WORKSPACE_ID:-workspace-id}" \
    CMUX_SURFACE_ID="${TEST_SURFACE_ID:-surface-id}" \
    CMUX_AGENT_BOARD_AUTO_TITLE_STATE_DIR="$state_dir" \
    CMUX_AGENT_BOARD_TITLE_LOCK_DIR="$test_dir/title-locks" \
    CMUX_AGENT_BOARD_AUTO_TITLE_FOREGROUND=1 \
    CMUX_AGENT_BOARD_AUTO_TITLE_LANG=ja \
    CMUX_AGENT_BOARD_AUTO_TITLE_MAX_LOG_CHARS="${TEST_MAX_LOG_CHARS:-1500}" \
    CMUX_AGENT_BOARD_AUTO_TITLE_WORKSPACE="${TEST_RENAME_WORKSPACE:-0}" \
    CMUX_AGENT_BOARD_AUTO_TITLE_DISABLED="${TEST_DISABLED:-0}" \
    MOCK_CMUX_CALLS="$calls_file" \
    MOCK_CODEX_CALLS="$codex_calls" \
    MOCK_CLAUDE_CALLS="$claude_calls" \
    MOCK_GENERATOR_PROMPT="$generator_prompt" \
    MOCK_GENERATED_TITLE="${TEST_GENERATED_TITLE:-生成タイトル}" \
    MOCK_CODEX_FAIL="${TEST_CODEX_FAIL:-0}" \
    MOCK_CLAUDE_FAIL="${TEST_CLAUDE_FAIL:-0}" \
    MOCK_SURFACE_TITLE="${TEST_SURFACE_TITLE:-surface}" \
    MOCK_SURFACE_COUNT="${TEST_SURFACE_COUNT:-1}" \
    MOCK_WORKSPACE_TITLE="${TEST_WORKSPACE_TITLE:-workspace}" \
    MOCK_WORKSPACE_RENAME_FAILS="${TEST_WORKSPACE_RENAME_FAILS:-0}" \
    MOCK_WORKSPACE_RENAME_COUNT_FILE="$test_dir/workspace-rename-count" \
    MOCK_SURFACE_LIST_COUNT_FILE="${TEST_SURFACE_LIST_COUNT_FILE:-}" \
    MOCK_SECOND_SURFACE_READ_SIGNAL="${TEST_SECOND_SURFACE_READ_SIGNAL:-}" \
    MOCK_SECOND_SURFACE_READ_DELAY="${TEST_SECOND_SURFACE_READ_DELAY:-0}" \
    python3 "$SCRIPT"
}

working_marker=$'\342\201\240\342\200\213\342\201\240'
stopped_marker=$'\342\201\240\342\200\214\342\201\240'
input_marker=$'\342\201\240\342\200\215\342\201\240'

codex_transcript="$test_dir/codex.jsonl"
cat >"$codex_transcript" <<'JSONL'
{"type":"event_msg","payload":{"type":"user_message","message":"最初の依頼"}}
{"type":"response_item","payload":{"type":"message","role":"user","content":"合成された入力"}}
{"type":"event_msg","payload":{"type":"agent_message","message":"エージェント応答"}}
JSONL

codex_input=$(jq -cn \
  --arg transcript_path "$codex_transcript" \
  '{session_id: "codex-session", turn_id: "turn-1", transcript_path: $transcript_path, prompt: "現在の依頼"}')
TEST_GENERATED_TITLE=$'前置き\nタイトル: 「自動タイトル実装。」' \
  TEST_SURFACE_TITLE="terminal${working_marker}" \
  run_hook "$codex_input"

grep -Fq -- "tab-action --surface surface-id --action rename --title 自動タイトル実装${working_marker}" "$calls_file"
if grep -Fq 'workspace-action' "$calls_file"; then
  printf 'workspace was renamed without opt-in\n' >&2
  exit 1
fi
grep -Fq -- '--model gpt-5.4-mini' "$codex_calls"
grep -Fq '最初の依頼' "$generator_prompt"
grep -Fq '現在の依頼' "$generator_prompt"
if grep -Fq '合成された入力' "$generator_prompt"; then
  printf 'Codex synthesized user input was included\n' >&2
  exit 1
fi
[[ ! -e "$claude_calls" ]]
jq -e '.generated == true and .complete == true and .title == "自動タイトル実装"' \
  "$state_dir/codex-session.json" >/dev/null

: >"$calls_file"
: >"$codex_calls"
run_hook "$codex_input"
[[ ! -s "$calls_file" ]]
[[ ! -s "$codex_calls" ]]

bounded_transcript="$test_dir/bounded.jsonl"
jq -cn --arg message "$(printf 'A%.0s' {1..40})" \
  '{type: "event_msg", payload: {type: "user_message", message: $message}}' \
  >"$bounded_transcript"
bounded_input=$(jq -cn \
  --arg transcript_path "$bounded_transcript" \
  '{session_id: "bounded-session", turn_id: "turn-bounded", transcript_path: $transcript_path, prompt: "CURRENT"}')
TEST_MAX_LOG_CHARS=20 TEST_GENERATED_TITLE='領域確保' run_hook "$bounded_input"
grep -Fq '1. AAAAAA' "$generator_prompt"
grep -Fq '2. CURRENT' "$generator_prompt"

: >"$calls_file"
: >"$codex_calls"
failed_input=$(jq -cn '{session_id: "retry-session", turn_id: "turn-2", prompt: "再試行の依頼"}')
TEST_CODEX_FAIL=1 run_hook "$failed_input"
[[ ! -s "$calls_file" ]]
[[ ! -e "$state_dir/retry-session.json" ]]
[[ ! -e "$claude_calls" ]]
TEST_GENERATED_TITLE='再試行成功' run_hook "$failed_input"
grep -Fq -- 'tab-action --surface surface-id --action rename --title 再試行成功' "$calls_file"
[[ $(grep -c 'exec --ignore-user-config' "$codex_calls") -eq 2 ]]

: >"$calls_file"
claude_transcript="$test_dir/claude.jsonl"
cat >"$claude_transcript" <<'JSONL'
{"type":"user","message":{"content":"Claude の最初の依頼"}}
{"type":"user","toolUseResult":{"ok":true},"message":{"content":"ツール結果"}}
{"type":"user","isSidechain":true,"message":{"content":"サブエージェント入力"}}
JSONL
claude_input=$(jq -cn \
  --arg transcript_path "$claude_transcript" \
  '{session_id: "claude-session", transcript_path: $transcript_path, prompt: "Claude の現在の依頼"}')
TEST_GENERATED_TITLE='これは非常に長い日本語の自動生成タイトルです' \
  TEST_SURFACE_TITLE="terminal${stopped_marker}" \
  run_hook "$claude_input"
grep -Fq -- '--model haiku' "$claude_calls"
grep -Fq 'Claude の最初の依頼' "$generator_prompt"
grep -Fq 'Claude の現在の依頼' "$generator_prompt"
if grep -Eq 'ツール結果|サブエージェント入力' "$generator_prompt"; then
  printf 'Claude non-human input was included\n' >&2
  exit 1
fi
grep -Fq -- "tab-action --surface surface-id --action rename --title これは非常に長い日本語の自…${stopped_marker}" "$calls_file"

: >"$calls_file"
surface_count_file="$test_dir/surface-list-count"
second_read_signal="$test_dir/second-surface-read"
concurrent_input=$(jq -cn '{session_id: "concurrent-session", turn_id: "turn-concurrent", prompt: "競合確認"}')
TEST_GENERATED_TITLE='競合タイトル' \
  TEST_SURFACE_TITLE="terminal${working_marker}" \
  TEST_SURFACE_LIST_COUNT_FILE="$surface_count_file" \
  TEST_SECOND_SURFACE_READ_SIGNAL="$second_read_signal" \
  TEST_SECOND_SURFACE_READ_DELAY=0.5 \
  run_hook "$concurrent_input" &
auto_title_pid=$!
for _ in {1..100}; do
  [[ -e "$second_read_signal" ]] && break
  sleep 0.01
done
[[ -e "$second_read_signal" ]]
PATH="$mock_bin:$PATH" \
  CMUX_WORKSPACE_ID='workspace-id' \
  CMUX_SURFACE_ID='surface-id' \
  CMUX_AGENT_BOARD_TITLE_LOCK_DIR="$test_dir/title-locks" \
  MOCK_CMUX_CALLS="$calls_file" \
  MOCK_SURFACE_TITLE="terminal${working_marker}" \
  bash "$STATE_SCRIPT" stopped >/dev/null &
state_pid=$!
wait "$auto_title_pid"
wait "$state_pid"
tail -n 1 "$calls_file" | grep -Fq -- "tab-action --surface surface-id --action rename --title terminal${stopped_marker}"

: >"$calls_file"
single_input=$(jq -cn '{session_id: "single-workspace", turn_id: "turn-3", prompt: "単一タブ"}')
TEST_RENAME_WORKSPACE=1 TEST_GENERATED_TITLE='単一作業' run_hook "$single_input"
grep -Fq -- 'workspace-action --workspace workspace-id --action rename --title 単一作業' "$calls_file"

marker_index=0
for workspace_marker in "$working_marker" "$stopped_marker" "$input_marker"; do
  marker_index=$((marker_index + 1))
  : >"$calls_file"
  marker_input=$(jq -cn --arg session_id "workspace-marker-$marker_index" \
    '{session_id: $session_id, turn_id: "turn-marker", prompt: "記号保持"}')
  TEST_RENAME_WORKSPACE=1 \
    TEST_GENERATED_TITLE='記号付き作業' \
    TEST_WORKSPACE_TITLE="旧名${workspace_marker}" \
    run_hook "$marker_input"
  grep -Fq -- "workspace-action --workspace workspace-id --action rename --title 記号付き作業${workspace_marker}" \
    "$calls_file"
done

: >"$calls_file"
: >"$codex_calls"
workspace_retry_input=$(jq -cn '{session_id: "workspace-retry", turn_id: "turn-retry", prompt: "再試行"}')
TEST_RENAME_WORKSPACE=1 TEST_WORKSPACE_RENAME_FAILS=1 TEST_GENERATED_TITLE='再試行作業' \
  run_hook "$workspace_retry_input"
jq -e '.generated == true and .tab_applied == true and .complete != true' \
  "$state_dir/workspace-retry.json" >/dev/null
TEST_RENAME_WORKSPACE=1 run_hook "$workspace_retry_input"
[[ $(grep -c 'exec --ignore-user-config' "$codex_calls") -eq 1 ]]
[[ $(grep -c 'workspace-action' "$calls_file") -eq 2 ]]
jq -e '.workspace_applied == true and .complete == true' \
  "$state_dir/workspace-retry.json" >/dev/null

: >"$calls_file"
multi_input=$(jq -cn '{session_id: "multi-workspace", turn_id: "turn-4", prompt: "複数タブ"}')
TEST_RENAME_WORKSPACE=1 TEST_SURFACE_COUNT=2 TEST_GENERATED_TITLE='複数作業' run_hook "$multi_input"
grep -Fq -- 'tab-action --surface surface-id --action rename --title 複数作業' "$calls_file"
if grep -Fq 'workspace-action' "$calls_file"; then
  printf 'multi-surface workspace was renamed\n' >&2
  exit 1
fi

: >"$calls_file"
: >"$codex_calls"
subagent_input=$(jq -cn '{session_id: "subagent", turn_id: "turn-5", agent_id: "agent-1", prompt: "無視"}')
run_hook "$subagent_input"
[[ ! -s "$calls_file" ]]
[[ ! -s "$codex_calls" ]]

TEST_DISABLED=true run_hook "$(jq -cn '{session_id: "disabled", turn_id: "turn-6", prompt: "無視"}')"
[[ ! -s "$codex_calls" ]]

printf 'invalid state' >"$state_dir/corrupt-session.json"
run_hook "$(jq -cn '{session_id: "corrupt-session", turn_id: "turn-corrupt", prompt: "無視"}')"
[[ ! -s "$codex_calls" ]]

printf '%s' "$(jq -cn '{session_id: "outside", turn_id: "turn-7", prompt: "無視"}')" | env \
  PATH="$mock_bin:$PATH" \
  CMUX_AGENT_BOARD_AUTO_TITLE_STATE_DIR="$state_dir" \
  CMUX_AGENT_BOARD_AUTO_TITLE_FOREGROUND=1 \
  MOCK_CODEX_CALLS="$codex_calls" \
  python3 "$SCRIPT"
[[ ! -s "$codex_calls" ]]

jq -e '
  [.hooks.UserPromptSubmit[]?.hooks[]?.command] as $commands
  | ($commands | length) == 2
    and ($commands[0] | contains("agent-board-state\" working"))
    and ($commands[1] | contains("agent-board-auto-title"))
' "$REPO_ROOT/home/dot_claude/settings.json" >/dev/null

rendered_codex_hooks=$(chezmoi execute-template <"$REPO_ROOT/home/dot_codex/hooks.json.tmpl")
jq -e '
  [.hooks.UserPromptSubmit[]?.hooks[]?.command] as $commands
  | ([$commands[] | select(contains("agent-board-auto-title"))] | length) == 1
    and ($commands[-2] | contains("agent-board-state\" working"))
    and ($commands[-1] | contains("agent-board-auto-title"))
' <<<"$rendered_codex_hooks" >/dev/null

render_home="$test_dir/render-home"
mkdir -p "$render_home/.codex"
cat >"$render_home/.codex/hooks.json" <<'JSON'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "mixed",
        "hooks": [
          {"type": "command", "command": "cmux-agent-board-auto-title old"},
          {"type": "command", "command": "keep-me"}
        ]
      },
      {
        "hooks": [
          {"type": "command", "command": "cmux-agent-board-auto-title duplicate"}
        ]
      }
    ]
  }
}
JSON
first_render=$(HOME="$render_home" PATH="/opt/homebrew/bin:/usr/bin:/bin" \
  chezmoi execute-template \
  <"$REPO_ROOT/home/dot_codex/hooks.json.tmpl")
jq -e '
  ([.hooks.UserPromptSubmit[]?.hooks[]?.command
    | select(contains("agent-board-auto-title"))] | length) == 1
  and ([.hooks.UserPromptSubmit[]?.hooks[]?.command
    | select(. == "keep-me")] | length) == 1
' <<<"$first_render" >/dev/null
printf '%s\n' "$first_render" >"$render_home/.codex/hooks.json"
second_render=$(HOME="$render_home" PATH="/opt/homebrew/bin:/usr/bin:/bin" \
  chezmoi execute-template \
  <"$REPO_ROOT/home/dot_codex/hooks.json.tmpl")
diff -u <(jq -S . <<<"$first_render") <(jq -S . <<<"$second_render")

python3 - "$SCRIPT" "$test_dir/state-machine" <<'PY'
import json
import os
import runpy
import sys
from pathlib import Path

script = sys.argv[1]
root = Path(sys.argv[2])
state_dir = root / "state"
lock_dir = root / "locks"
os.environ["CMUX_WORKSPACE_ID"] = "workspace-id"
os.environ["CMUX_SURFACE_ID"] = "surface-id"
os.environ["CMUX_AGENT_BOARD_AUTO_TITLE_STATE_DIR"] = str(state_dir)
os.environ["CMUX_AGENT_BOARD_TITLE_LOCK_DIR"] = str(lock_dir)
os.environ.pop("CMUX_AGENT_BOARD_AUTO_TITLE_WORKSPACE", None)

module = runpy.run_path(script, run_name="cmux_auto_title_state_test")
runtime = module["run"].__globals__
surface = {
    "surfaces": [
        {"id": "surface-id", "ref": "surface:1", "title": "terminal"}
    ]
}
runtime["surface_document"] = lambda _workspace_id: surface

generate_calls = 0
rename_calls = 0
save_calls = 0


def generate_title(_conversation_log, _agent):
    global generate_calls
    generate_calls += 1
    return "Persisted title"


def rename_tab(_surface_id, _title):
    global rename_calls
    rename_calls += 1
    return True


def save_state(target, state):
    global save_calls
    save_calls += 1
    if save_calls == 2:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(state), encoding="utf-8")
    return True


runtime["generate_title"] = generate_title
runtime["rename_tab"] = rename_tab
runtime["save_state"] = save_state
hook_input = {
    "session_id": "save-retry",
    "turn_id": "turn-save",
    "prompt": "persist before apply",
}
module["run"](hook_input)
module["run"](hook_input)
assert generate_calls == 1, generate_calls
assert rename_calls == 2, rename_calls
state = json.loads((state_dir / "save-retry.json").read_text(encoding="utf-8"))
assert state["complete"] is True

os.environ["CMUX_AGENT_BOARD_AUTO_TITLE_MAX_WIDTH"] = "1"
try:
    module["max_width"]()
except ValueError:
    pass
else:
    raise AssertionError("width 1 was accepted")
PY

grep -Fq 'substantially adapted from sh1ma/herdr-auto-title' "$SCRIPT"
grep -Fq 'Copyright (c) 2026 sh1ma' \
  "$REPO_ROOT/home/dot_local/share/licenses/cmux-agent-board-auto-title/LICENSE"

printf 'cmux Agent Board auto-title tests passed\n'
