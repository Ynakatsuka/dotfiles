#!/usr/bin/env bash
# Regression tests for the check-reply-language Claude Stop hook.
# The hook blocks an English final reply once when the user writes Japanese, and
# must leave alone code-only replies, requests for English, and sessions whose
# prompts are not Japanese.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/home/dot_claude/hooks/executable_check-reply-language.py"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
transcript="$tmp_dir/transcript.jsonl"

fail() {
  echo "test-reply-language-hook: $*" >&2
  exit 1
}

# Write a transcript from "<kind>:<text>" arguments, oldest record first.
# Kinds are the user-record shapes Claude Code writes: prompt (typed text),
# blocks (typed text with an attachment), meta (skill body), summary (compaction
# summary), sidechain (subagent prompt), and tool (tool result).
write_transcript() {
  python3 -c '
import json, sys

def record(kind, text):
    entry = {"type": "user", "isSidechain": kind == "sidechain",
             "message": {"role": "user", "content": text}}
    if kind == "blocks":
        entry["message"]["content"] = [
            {"type": "text", "text": text},
            {"type": "image", "source": {"type": "base64", "data": ""}},
        ]
    elif kind == "tool":
        entry["message"]["content"] = [
            {"type": "tool_result", "tool_use_id": "toolu_1", "content": text}
        ]
    elif kind == "meta":
        entry["isMeta"] = True
    elif kind == "summary":
        entry["isCompactSummary"] = True
    elif kind not in ("prompt", "sidechain"):
        raise ValueError(f"unknown record kind: {kind}")
    return entry

def write(transcript, entry):
    # Claude Code writes compact JSON, which the hook relies on to skip records.
    transcript.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + "\n")

with open(sys.argv[1], "w", encoding="utf-8") as transcript:
    for argument in sys.argv[2:]:
        kind, _, text = argument.partition(":")
        write(transcript, record(kind, text))
        # Assistant records sit between prompts and are never user evidence.
        write(transcript, {"type": "assistant", "message": {"content": [
            {"type": "text", "text": "日本語で書いた途中経過"}]}})
' "$transcript" "$@"
}

# Print the hook's stdout for a final reply and stop_hook_active value.
run_hook() {
  local reply=$1 active=${2:-false} path=${3:-$transcript}
  python3 -c '
import json, sys
print(json.dumps({
    "hook_event_name": "Stop",
    "transcript_path": sys.argv[3],
    "stop_hook_active": sys.argv[2] == "true",
    "last_assistant_message": sys.argv[1],
}))' "$reply" "$active" "$path" | python3 "$HOOK"
}

assert_blocked() {
  local label=$1 output
  output=$(run_hook "${@:2}")
  [[ $(python3 -c 'import json, sys; print(json.load(sys.stdin)["decision"])' <<<"$output") == block ]] ||
    fail "$label: expected a block, got: $output"
  [[ "$output" == *"in Japanese"* ]] || fail "$label: block reason does not ask for Japanese: $output"
}

assert_allowed() {
  local label=$1 output
  output=$(run_hook "${@:2}")
  [[ -z "$output" ]] || fail "$label: expected no output, got: $output"
}

english_report='Neither CI failure is a bug in this PR. Both came from runs that tested the previous commit (`b0753105`).

| Job | Error |
|---|---|
| `frontend` | `ResizeObserver is not defined` |

I started all 5 jobs again and will merge once every check passes.'
# Real case: an English report that quotes a Japanese place name.
english_with_names='The schedule screen now shows which racecourses are running on each date. NAR venues such as 帯広 appear in a smaller font, and nothing is committed yet.'
japanese_report='CI の失敗はどちらもこの PR の不具合ではありません。前のコミット（`b0753105`）を対象にした実行でした。

- `frontend`: `ResizeObserver is not defined`
- draft PR を ready for review にして、5 つのジョブを再実行しました。'
code_only='```bash
chezmoi apply ~/.claude/hooks/check-reply-language.py
git status --short
```'
unfenced_command='chezmoi apply ~/.claude/hooks/check-reply-language.py && git status --short --branch'

# Japanese prompts, including the long autonomous run after compaction.
write_transcript 'prompt:日程のスケジュールに開催場を表示したい' 'summary:The user asked in Japanese (日本語) ...' \
  'tool:command output' 'prompt:マージして続けて'
assert_blocked "English report" "$english_report"
assert_blocked "English report quoting Japanese names" "$english_with_names"
assert_blocked "short English progress note" 'Waiting for the completion notification.'
assert_allowed "Japanese report" "$japanese_report"
assert_allowed "code-only reply" "$code_only"
assert_allowed "unfenced command" "$unfenced_command"
assert_allowed "short label" 'LGTM'
assert_allowed "second stop after a block" "$english_report" true

output=$(printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false,"transcript_path":"'"$transcript"'"}' |
  python3 "$HOOK")
[[ -z "$output" ]] || fail "reply without text was blocked: $output"

# Prompts that carry no language evidence keep the earlier Japanese prompt in force.
write_transcript 'prompt:見た目どうなる？' 'prompt:<task-notification><status>completed</status></task-notification>' \
  'prompt:<command-message>prd</command-message>' 'prompt:1' \
  'prompt:Continue the scheduled background work now, report progress, and schedule the next wakeup if more monitoring is needed.'
assert_blocked "scheduled wakeup after Japanese prompts" "$english_report"

write_transcript 'blocks:このスクリーンショットの表示を直して'
assert_blocked "Japanese prompt with an attachment" "$english_report"

# The user asked for English, then kept going without writing Japanese.
write_transcript 'prompt:最初は日本語で相談' 'prompt:PR の説明は英語で書いて' 'prompt:1'
assert_allowed "English requested in Japanese" "$english_report"
write_transcript 'prompt:最初は日本語で相談' 'prompt:Please answer in English from now on.' 'prompt:continue'
assert_allowed "English requested in English" "$english_report"

# A later Japanese prompt puts the check back.
write_transcript 'prompt:PR の説明は英語で書いて' 'prompt:続けて'
assert_blocked "Japanese prompt after an English request" "$english_report"

# Sessions with no Japanese typed by the user: English prompts, or Japanese that
# appears only in a skill body, a subagent prompt, a summary, or tool output.
write_transcript 'prompt:Fix the failing test in the parser.'
assert_allowed "English-only user" "$english_report"
write_transcript 'meta:日本語のスキル本文' 'sidechain:サブエージェントへの依頼文' 'summary:日本語の要約' \
  'tool:日本語のツール出力' 'prompt:Review this change.'
assert_allowed "Japanese only outside typed prompts" "$english_report"

# --no-session-persistence leaves no transcript to read.
assert_allowed "missing transcript" "$english_report" false "$tmp_dir/absent.jsonl"

echo "test-reply-language-hook: ok"
