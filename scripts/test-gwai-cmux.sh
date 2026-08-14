#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
gwai_cmux_script=${GWAI_CMUX_SCRIPT:-$repo_root/home/dot_local/bin/executable_gwai-cmux}
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-cmux-test.XXXXXX")
background_pid=""

cleanup() {
  if [[ -n "$background_pid" ]] && kill -0 "$background_pid" 2>/dev/null; then
    kill "$background_pid"
    wait "$background_pid" 2>/dev/null || true
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

mkdir -p "$tmp_dir/base" "$tmp_dir/worktree"

script_prefix=$(awk '/^create_prompt_file[(][)]/ { exit } { print }' \
  "$gwai_cmux_script")
eval "$script_prefix"

gw-create-worktree() {
  sleep 5 &
  printf '%s\n' "$!" >"$tmp_dir/background.pid"
  printf 'Worktree ready: %s\n' "$tmp_dir/worktree"
  printf 'WORKTREE_PATH=%s\n' "$tmp_dir/worktree"
  printf 'WORKTREE_CREATED=1\n'
}

git() {
  printf 'worktree %s\n' "$tmp_dir/worktree"
  printf 'HEAD deadbeef\n'
  printf 'branch refs/heads/fix-test\n'
}

created_worktree_dir=""
started_at=$(date +%s)
create_worktree "$tmp_dir/base" fix-test
elapsed_seconds=$(($(date +%s) - started_at))

[[ -f "$tmp_dir/background.pid" ]] || fail "helper did not start its background child"
background_pid=$(<"$tmp_dir/background.pid")
kill -0 "$background_pid" 2>/dev/null ||
  fail "create_worktree waited for the helper background child"
[[ "$elapsed_seconds" -lt 4 ]] ||
  fail "create_worktree took ${elapsed_seconds}s while the helper child was detached"
[[ "$created_worktree_dir" == "$tmp_dir/worktree" ]] ||
  fail "unexpected worktree path: $created_worktree_dir"

printf 'test-gwai-cmux: OK\n'
