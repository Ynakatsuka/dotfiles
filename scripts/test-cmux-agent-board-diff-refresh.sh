#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SCRIPT="$REPO_ROOT/home/dot_local/libexec/cmux/executable_agent-board-diff-refresh"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-agent-board-diff-refresh-test.XXXXXX")
test_dir=$(cd "$test_dir" && pwd -P)
trap 'rm -rf "$test_dir"' EXIT

git_repo="$test_dir/repository"
nested_repo="$git_repo/nested-repository"
unborn_repo="$test_dir/unborn-repository"
source_file="$test_dir/agent-board.swift"
target_file="$test_dir/state/agent-board.swift"
lock_file="$test_dir/state/agent-board-diff-refresh.lock"
cache_file="$test_dir/state/agent-board-diff-cache.json"
mock_cmux="$test_dir/cmux"
mock_git_dir="$test_dir/git-bin"
mock_git="$mock_git_dir/git"
git_calls="$test_dir/git-calls"
usage_cache_file="$test_dir/state/agent-board-usage.json"
calls_file="$test_dir/calls"
cmux_mode_file="$test_dir/cmux-mode"

git init -q "$git_repo"
git -C "$git_repo" config user.email 'test@example.com'
git -C "$git_repo" config user.name 'Test User'
mkdir -p "$git_repo/src/lib"
printf 'before\n' >"$git_repo/tracked.txt"
printf 'nested before\n' >"$git_repo/src/lib/code.txt"
printf '/nested-repository/\n' >"$git_repo/.gitignore"
git -C "$git_repo" add tracked.txt src/lib/code.txt .gitignore
git -C "$git_repo" commit -qm 'initial commit'
printf 'after\n' >"$git_repo/tracked.txt"
printf 'nested after\n' >"$git_repo/src/lib/code.txt"
printf 'new line one\nnew line two\n' >"$git_repo/untracked.txt"
ln -s missing-target "$git_repo/broken-link"
ln -s . "$git_repo/directory-link"

git init -q "$nested_repo"
git -C "$nested_repo" config user.email 'test@example.com'
git -C "$nested_repo" config user.name 'Test User'
printf 'nested before\n' >"$nested_repo/nested.txt"
git -C "$nested_repo" add nested.txt
git -C "$nested_repo" commit -qm 'initial nested commit'
printf 'nested after\n' >"$nested_repo/nested.txt"

git init -q "$unborn_repo"
printf 'line one\nline two\n' >"$unborn_repo/created.txt"
git -C "$unborn_repo" add created.txt
printf 'line three\n' >>"$unborn_repo/created.txt"
printf 'untracked\n' >"$unborn_repo/untracked.txt"

cat >"$source_file" <<'SWIFT'
func staticBefore() -> String { return "before" }
// BEGIN CMUX_DIFF_DATA (managed by cmux-agent-board-diff-refresh)
stale generated content
// END CMUX_DIFF_DATA
func staticAfter() -> String { return "after" }
SWIFT

sed \
  -e "s|@REPOSITORY@|$git_repo|g" \
  -e "s|@NESTED_REPOSITORY@|$nested_repo|g" \
  -e "s|@UNBORN_REPOSITORY@|$unborn_repo|g" \
  -e "s|@CALLS_FILE@|$calls_file|g" \
  -e "s|@MODE_FILE@|$cmux_mode_file|g" \
  >"$mock_cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$*" == '--json workspace list' ]]; then
  if [[ -f '@MODE_FILE@' ]] && [[ "$(< '@MODE_FILE@')" == 'malformed-json' ]]; then
    printf '{not json\n'
    exit 0
  fi
  printf '{"workspaces":[{"current_directory":"@REPOSITORY@"},{"current_directory":"@REPOSITORY@"},{"current_directory":"@NESTED_REPOSITORY@"},{"current_directory":"@UNBORN_REPOSITORY@"},{"current_directory":"/tmp/not-a-git-directory"}]}'
  exit 0
fi

if [[ "$*" == 'sidebar reload agent-board' ]]; then
  printf '%s\n' "$*" >>'@CALLS_FILE@'
  exit 0
fi

printf 'unexpected cmux arguments: %s\n' "$*" >&2
exit 1
MOCK
chmod +x "$mock_cmux"

mkdir -p "$mock_git_dir"
cat >"$mock_git" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${GIT_OPTIONAL_LOCKS:-}" != '0' ]]; then
  printf 'git read did not disable optional locks\n' >&2
  exit 1
fi
printf '%s\n' "$*" >>"$MOCK_GIT_CALLS"
exec /usr/bin/git "$@"
MOCK
chmod +x "$mock_git"

mkdir -p "$(dirname "$usage_cache_file")"
printf '%s\n' '{"schema_version":4,"refreshed_at":1000,"providers":{"codex":{"status":"ok","account":"codex@example.com","account_name":"Codex Personal","five_hour":23.5,"seven_day":67,"fable_week":null,"five_hour_reset_at":2000,"seven_day_reset_at":3000,"fable_week_reset_at":null,"detail":""},"claude":{"status":"ok","account":"claude@example.com","account_name":"Claude Team","five_hour":12,"seven_day":34,"fable_week":56.5,"five_hour_reset_at":4000,"seven_day_reset_at":5000,"fable_week_reset_at":5000,"detail":"age 1m"},"cursor":{"status":"ok","account":"cursor@example.com","account_name":"Cursor Personal","five_hour":null,"seven_day":null,"fable_week":null,"five_hour_reset_at":null,"seven_day_reset_at":null,"fable_week_reset_at":null,"detail":"monthly only"}}}' >"$usage_cache_file"

run_refresh() {
  PATH="$mock_git_dir:$PATH" \
    MOCK_GIT_CALLS="$git_calls" \
    CMUX_BIN="$mock_cmux" \
    CMUX_AGENT_BOARD_SOURCE="$source_file" \
    CMUX_AGENT_BOARD_TARGET="$target_file" \
    CMUX_AGENT_BOARD_LOCK="$lock_file" \
    CMUX_AGENT_BOARD_CACHE="$cache_file" \
    CMUX_AGENT_BOARD_USAGE_CACHE="$usage_cache_file" \
    "$SCRIPT"
}

run_refresh
grep -Fq 'func diffTotalsOf(_ dir) -> String {' "$target_file"
grep -Fq 'func diffTreeOf(_ dir) -> String {' "$target_file"
grep -Fq "if d == \"$git_repo\" || d.hasPrefix(\"$git_repo/\") { return \"5|4|2\" }" "$target_file"
grep -Fq "D| |src;D|   |lib;F|     |M|1|1|code.txt|src/lib/code.txt|c3JjL2xpYi9jb2RlLnR4dA;F| |N|-|-|broken-link|broken-link|YnJva2VuLWxpbms;F| |N|-|-|directory-link|directory-link|ZGlyZWN0b3J5LWxpbms;F| |M|1|1|tracked.txt|tracked.txt|dHJhY2tlZC50eHQ;F| |N|2|0|untracked.txt|untracked.txt|dW50cmFja2VkLnR4dA" "$target_file"
grep -Fq "if d == \"$git_repo\" || d.hasPrefix(\"$git_repo/\") { return \"$git_repo\" }" "$target_file"
grep -Fq "if d == \"$nested_repo\" || d.hasPrefix(\"$nested_repo/\") { return \"1|1|1\" }" "$target_file"
grep -Fq "if d == \"$unborn_repo\" || d.hasPrefix(\"$unborn_repo/\") { return \"2|4|0\" }" "$target_file"
grep -Fq "F| |N|3|0|created.txt|created.txt|Y3JlYXRlZC50eHQ;F| |N|1|0|untracked.txt|untracked.txt|dW50cmFja2VkLnR4dA" "$target_file"
grep -Fq 'func usageValue(_ provider, _ field) -> String {' "$target_file"
grep -Fq 'func usageProgress(_ provider, _ field) -> Double {' "$target_file"
grep -Fq 'func usageResetAt(_ provider, _ field) -> Double {' "$target_file"
grep -Fq 'if p == "codex" && f == "five_hour" { return "23.5%" }' "$target_file"
grep -Fq 'if p == "codex" && f == "account_name" { return "Codex Personal" }' "$target_file"
grep -Fq 'if p == "codex" && f == "five_hour" { return 0.235 }' "$target_file"
grep -Fq 'if p == "codex" && f == "five_hour" { return 2000.0 }' "$target_file"
grep -Fq 'if p == "claude" && f == "fable_week" { return "56.5%" }' "$target_file"
grep -Fq 'if p == "claude" && f == "fable_week" { return 0.565 }' "$target_file"
grep -Fq 'if p == "claude" && f == "fable_week" { return 5000.0 }' "$target_file"
grep -Fq 'if p == "claude" && f == "detail" { return "age 1m" }' "$target_file"
grep -Fq 'if p == "cursor" && f == "detail" { return "monthly only" }' "$target_file"
jq -e --arg git_repo "$git_repo" '
  .version == 1
  and (.repositories[$git_repo].entries | any(.path == "untracked.txt"))
' "$cache_file" >/dev/null
grep -Fq 'status --porcelain=v1 -z -uall --no-renames' "$git_calls"
[[ "$(grep -cF 'rev-parse --show-toplevel' "$git_calls")" == '3' ]]
nested_line=$(grep -nF "if d == \"$nested_repo\"" "$target_file" | head -n 1 | cut -d: -f1)
parent_line=$(grep -nF "if d == \"$git_repo\"" "$target_file" | head -n 1 | cut -d: -f1)
((nested_line < parent_line))
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == '1' ]]

: >"$git_calls"
cache_tmp="$(mktemp "$test_dir/diff-cache.XXXXXX")"
jq --arg stale_toplevel "$test_dir/stale-repository" \
  '.repositories[$stale_toplevel] = {scanned_at: 0, entries: []}' \
  "$cache_file" >"$cache_tmp"
mv "$cache_tmp" "$cache_file"
run_refresh
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == '1' ]]
grep -Fq 'status --porcelain=v1 -z -uno --no-renames' "$git_calls"
if grep -Fq -- '-uall' "$git_calls"; then
  printf 'fresh untracked scan ran before the cache expired\n' >&2
  exit 1
fi
jq -e --arg stale_toplevel "$test_dir/stale-repository" \
  '(.repositories | has($stale_toplevel)) | not' "$cache_file" >/dev/null

cache_tmp="$(mktemp "$test_dir/diff-cache.XXXXXX")"
jq '(.repositories[] | .scanned_at) = 0' "$cache_file" >"$cache_tmp"
mv "$cache_tmp" "$cache_file"
: >"$git_calls"

git -C "$git_repo" checkout -- tracked.txt src/lib/code.txt
git -C "$nested_repo" checkout -- nested.txt
rm "$git_repo/untracked.txt"
rm "$git_repo/broken-link" "$git_repo/directory-link"
run_refresh
grep -Fq 'status --porcelain=v1 -z -uall --no-renames' "$git_calls"
if grep -Fq "$git_repo" "$target_file"; then
  printf 'clean repository data remained in runtime sidebar\n' >&2
  exit 1
fi
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == '2' ]]

mv "$usage_cache_file" "$test_dir/usage-cache-before-missing.json"
run_refresh
grep -Fq 'if p == "codex" && f == "detail" { return "error" }' "$target_file"
grep -Fq 'if p == "claude" && f == "detail" { return "error" }' "$target_file"
grep -Fq 'if p == "cursor" && f == "detail" { return "error" }' "$target_file"
mv "$test_dir/usage-cache-before-missing.json" "$usage_cache_file"
run_refresh
grep -Fq 'if p == "codex" && f == "five_hour" { return "23.5%" }' "$target_file"

cp "$target_file" "$test_dir/runtime-before-failure.swift"
printf 'malformed-json\n' >"$cmux_mode_file"
if run_refresh >/dev/null 2>&1; then
  printf 'malformed cmux JSON unexpectedly succeeded\n' >&2
  exit 1
fi
cmp -s "$test_dir/runtime-before-failure.swift" "$target_file"
rm "$cmux_mode_file"

cp "$cache_file" "$test_dir/cache-before-invalid.json"
printf '%s\n' '{"version":999,"repositories":{}}' >"$cache_file"
if run_refresh >/dev/null 2>&1; then
  printf 'invalid untracked cache unexpectedly succeeded\n' >&2
  exit 1
fi
cmp -s "$test_dir/runtime-before-failure.swift" "$target_file"
mv "$test_dir/cache-before-invalid.json" "$cache_file"

cat >"$source_file" <<'SWIFT'
func staticBefore() -> String { return "before" }
func staticAfter() -> String { return "after" }
SWIFT
if run_refresh >/dev/null 2>&1; then
  printf 'missing CMUX_DIFF_DATA marker unexpectedly succeeded\n' >&2
  exit 1
fi
cmp -s "$test_dir/runtime-before-failure.swift" "$target_file"

printf 'cmux Agent Board diff refresh tests passed\n'
