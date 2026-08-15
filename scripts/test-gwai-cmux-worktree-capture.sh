#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
gwai_cmux_script="${GWAI_CMUX_SCRIPT:-$repo_root/home/dot_local/bin/executable_gwai-cmux}"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-cmux-worktree-capture-test.XXXXXX")
test_dir=$(cd "$test_dir" && pwd -P)
background_pid=""

cleanup() {
  if [[ -n "$background_pid" ]] && kill -0 "$background_pid" 2>/dev/null; then
    kill "$background_pid"
    wait "$background_pid" 2>/dev/null || true
  fi
  rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bin_dir="$test_dir/bin"
base_dir="$test_dir/base"
worktree_dir="$test_dir/worktree"
run_output="$test_dir/run-output"
cmux_log="$test_dir/cmux.log"
zsh_log="$test_dir/zsh.log"
background_pid_file="$test_dir/background.pid"
mkdir -p "$bin_dir" "$base_dir"
git init -q "$base_dir"
git -C "$base_dir" config user.name 'gwai-cmux test'
git -C "$base_dir" config user.email 'gwai-cmux@example.invalid'
printf 'base\n' >"$base_dir/base.txt"
git -C "$base_dir" add base.txt
git -C "$base_dir" commit -qm 'test: add base file'

cat >"$bin_dir/cmux" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$TEST_CMUX_LOG"
MOCK

cat >"$bin_dir/gw-create-worktree" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

sleep 5 &
printf '%s\n' "$!" >"$TEST_BACKGROUND_PID_FILE"
printf 'helper progress (stdout)\n'
printf 'helper progress (stderr)\n' >&2
git -C "$TEST_BASE_DIR" worktree add -q -b "$1" "$TEST_WORKTREE_DIR"
printf 'WORKTREE_PATH=%s\n' "$TEST_WORKTREE_DIR"
MOCK

cat >"$bin_dir/zsh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >"$TEST_ZSH_LOG"
MOCK

chmod +x "$bin_dir/cmux" "$bin_dir/gw-create-worktree" "$bin_dir/zsh"

started_at=$(date +%s)
set +e
PATH="$bin_dir:/usr/bin:/bin" \
  CMUX_BIN="$bin_dir/cmux" \
  CMUX_WORKSPACE_ID='' \
  TEST_BACKGROUND_PID_FILE="$background_pid_file" \
  TEST_BASE_DIR="$base_dir" \
  TEST_CMUX_LOG="$cmux_log" \
  TEST_WORKTREE_DIR="$worktree_dir" \
  TEST_ZSH_LOG="$zsh_log" \
  bash "$gwai_cmux_script" \
  --inside-tab \
  --provider codex \
  --base-dir "$base_dir" \
  --branch-name fix-worktree-capture \
  'capture race regression' >"$run_output" 2>&1
run_status=$?
set -e
elapsed_seconds=$(($(date +%s) - started_at))

((run_status == 0)) || {
  printf '%s\n' "$(<"$run_output")" >&2
  fail "gwai-cmux exited with status $run_status"
}
((elapsed_seconds < 4)) ||
  fail "gwai-cmux waited for the helper's background child (${elapsed_seconds}s)"

[[ -s "$background_pid_file" ]] || fail "helper did not start its background child"
background_pid=$(<"$background_pid_file")
kill -0 "$background_pid" 2>/dev/null ||
  fail "helper background child was not still running"

grep -Fqx -- 'rename-workspace --title fix-worktree-capture' "$cmux_log" ||
  fail "cmux workspace rename was not requested"
grep -Fq -- "cd $worktree_dir && cdx capture\\ race\\ regression" "$zsh_log" ||
  fail "start_agent did not receive the expected worktree path"
grep -Fq -- 'helper progress (stdout)' "$run_output" ||
  fail "helper stdout was not visible"
grep -Fq -- 'helper progress (stderr)' "$run_output" ||
  fail "helper stderr was not visible"

printf 'test-gwai-cmux-worktree-capture: OK\n'
