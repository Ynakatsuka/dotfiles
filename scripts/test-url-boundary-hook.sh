#!/usr/bin/env bash
# Regression tests for the check-url-boundaries Claude Stop hook.
# Terminals extend a link through text written directly after a URL, so the hook
# blocks a final reply that glues Japanese or full-width brackets onto a URL.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/home/dot_claude/hooks/executable_check-url-boundaries.py"

fail() {
  echo "test-url-boundary-hook: $*" >&2
  exit 1
}

# Print the hook's stdout for a final reply and stop_hook_active value.
run_hook() {
  local reply=$1 active=$2
  python3 -c '
import json, sys
print(json.dumps({
    "hook_event_name": "Stop",
    "stop_hook_active": sys.argv[2] == "true",
    "last_assistant_message": sys.argv[1],
}))' "$reply" "$active" | python3 "$HOOK"
}

glued='- #69 https://github.com/Ynakatsuka/dotfiles/pull/69（base は #62 のブランチ）'
output=$(run_hook "$glued" false)
[[ $(python3 -c 'import json, sys; print(json.load(sys.stdin)["decision"])' <<<"$output") == block ]] ||
  fail "glued URL was not blocked: $output"
[[ "$output" == *'https://github.com/Ynakatsuka/dotfiles/pull/69（base'* ]] ||
  fail "block reason does not quote the glued URL: $output"

output=$(run_hook 'https://example.com/a。https://example.com/b です' false)
[[ "$output" == *'https://example.com/a。'* && "$output" != *'https://example.com/b '* ]] ||
  fail "only the glued URL should be reported: $output"

separated='- #69 https://github.com/Ynakatsuka/dotfiles/pull/69 （base は #62 のブランチ）
https://example.com/end
（次の行）'
output=$(run_hook "$separated" false)
[[ -z "$output" ]] || fail "URL followed by whitespace was blocked: $output"

delimited='[PR #69](https://github.com/Ynakatsuka/dotfiles/pull/69)（base）
[https://example.com/a](https://example.com/a)です
<https://example.com/b>です'
output=$(run_hook "$delimited" false)
[[ -z "$output" ]] || fail "Markdown or angle-bracket link was blocked: $output"

output=$(run_hook "$glued" true)
[[ -z "$output" ]] || fail "hook blocked again while stop_hook_active was true: $output"

output=$(printf '%s' '{"hook_event_name":"Stop","stop_hook_active":false}' | python3 "$HOOK")
[[ -z "$output" ]] || fail "reply without text was blocked: $output"

echo "test-url-boundary-hook: ok"
