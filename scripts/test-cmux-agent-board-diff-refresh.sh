#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_cmux-agent-board-diff-refresh"

test_dir=$(mktemp -d "${TMPDIR:-/tmp}/cmux-agent-board-diff-refresh-test.XXXXXX")
test_dir=$(cd "$test_dir" && pwd -P)
trap 'rm -rf "$test_dir"' EXIT

git_repo="$test_dir/repository"
nested_repo="$git_repo/nested-repository"
unborn_repo="$test_dir/unborn-repository"
source_file="$test_dir/agent-board.swift"
target_file="$test_dir/state/agent-board.swift"
lock_file="$test_dir/state/agent-board-diff-refresh.lock"
mock_cmux="$test_dir/cmux"
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
  printf '{"workspaces":[{"current_directory":"@REPOSITORY@"},{"current_directory":"@NESTED_REPOSITORY@"},{"current_directory":"@UNBORN_REPOSITORY@"},{"current_directory":"/tmp/not-a-git-directory"}]}'
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

run_refresh() {
  CMUX_BIN="$mock_cmux" \
    CMUX_AGENT_BOARD_SOURCE="$source_file" \
    CMUX_AGENT_BOARD_TARGET="$target_file" \
    CMUX_AGENT_BOARD_LOCK="$lock_file" \
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
nested_line=$(grep -nF "if d == \"$nested_repo\"" "$target_file" | head -n 1 | cut -d: -f1)
parent_line=$(grep -nF "if d == \"$git_repo\"" "$target_file" | head -n 1 | cut -d: -f1)
((nested_line < parent_line))
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == '1' ]]

run_refresh
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == '1' ]]

git -C "$git_repo" checkout -- tracked.txt src/lib/code.txt
git -C "$nested_repo" checkout -- nested.txt
rm "$git_repo/untracked.txt"
rm "$git_repo/broken-link" "$git_repo/directory-link"
run_refresh
if grep -Fq "$git_repo" "$target_file"; then
  printf 'clean repository data remained in runtime sidebar\n' >&2
  exit 1
fi
[[ "$(wc -l <"$calls_file" | tr -d ' ')" == '2' ]]

cp "$target_file" "$test_dir/runtime-before-failure.swift"
printf 'malformed-json\n' >"$cmux_mode_file"
if run_refresh >/dev/null 2>&1; then
  printf 'malformed cmux JSON unexpectedly succeeded\n' >&2
  exit 1
fi
cmp -s "$test_dir/runtime-before-failure.swift" "$target_file"
rm "$cmux_mode_file"

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
