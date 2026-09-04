#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
gwai_orca_script="${GWAI_ORCA_SCRIPT:-$repo_root/home/dot_local/bin/executable_gwai-orca}"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-orca-test.XXXXXX")
test_dir=$(cd "$test_dir" && pwd -P)

cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_args_equal() {
  local actual_file="$1"
  shift
  local -a expected=("$@")
  local -a actual=()
  local index

  while IFS= read -r -d '' argument; do
    actual+=("$argument")
  done <"$actual_file"

  [[ "${#actual[@]}" -eq "${#expected[@]}" ]] ||
    fail "unexpected argument count in $actual_file: ${#actual[@]}"

  for index in "${!expected[@]}"; do
    [[ "${actual[$index]}" == "${expected[$index]}" ]] ||
      fail "unexpected argument $index in $actual_file"
  done
}

bin_dir="$test_dir/bin"
orca_data_file="$test_dir/orca-data.json"
orca_command_log="$test_dir/orca-command.log"
orca_show_args="$test_dir/orca-show.args"
orca_create_args="$test_dir/orca-create.args"
run_output="$test_dir/run-output"
mkdir -p "$bin_dir"

cat >"$bin_dir/claude" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "${TEST_CLAUDE_OUTPUT:-fix create-orca-worktree}"
MOCK

cat >"$bin_dir/orca" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s %s\n' "$1" "$2" >>"$TEST_ORCA_COMMAND_LOG"

case "$1 $2" in
'worktree show')
  printf '%s\0' "$@" >"$TEST_ORCA_SHOW_ARGS"
  printf '{"ok":true,"result":{"worktree":{"repoId":"%s","id":"%s"}}}\n' \
    "$TEST_ORCA_SHOW_REPO_ID" "$TEST_ORCA_SHOW_WORKTREE_ID"
  ;;
'worktree create')
  printf '%s\0' "$@" >"$TEST_ORCA_CREATE_ARGS"
  if [[ "${TEST_ORCA_CREATE_OK:-true}" == 'true' ]]; then
    printf '{"ok":true,"result":{"worktree":{"id":"new-worktree"}}}\n'
  else
    printf '{"ok":false,"error":{"message":"mocked Orca create failure"}}\n'
  fi
  ;;
*)
  printf 'unexpected Orca command: %s\n' "$*" >&2
  exit 1
  ;;
esac
MOCK

chmod +x "$bin_dir/claude" "$bin_dir/orca"

printf '%s\n' '{"workspaceSession":{"activeRepoId":"repo-123","activeWorktreeId":"worktree-456"}}' >"$orca_data_file"

set +e
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  ORCA_DATA_FILE="$orca_data_file" \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_SHOW_ARGS="$orca_show_args" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  TEST_ORCA_SHOW_REPO_ID='repo-123' \
  TEST_ORCA_SHOW_WORKTREE_ID='another-worktree' \
  bash "$gwai_orca_script" --provider codex 'must not create' >"$run_output" 2>&1
failure_status=$?
set -e

((failure_status != 0)) || fail 'mismatched active worktree unexpectedly succeeded'
[[ ! -e "$orca_create_args" ]] || fail 'worktree create ran after active worktree validation failed'
assert_args_equal "$orca_show_args" \
  worktree show --worktree 'worktree:worktree-456' --json

prompt=$'Create an Orca worktree with spaces\nand a second line.'
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  ORCA_DATA_FILE="$orca_data_file" \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_SHOW_ARGS="$orca_show_args" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  TEST_ORCA_SHOW_REPO_ID='repo-123' \
  TEST_ORCA_SHOW_WORKTREE_ID='worktree-456' \
  bash "$gwai_orca_script" --provider claude -- "$prompt" >"$run_output" 2>&1

assert_args_equal "$orca_show_args" \
  worktree show --worktree 'worktree:worktree-456' --json
assert_args_equal "$orca_create_args" \
  worktree create \
  --repo 'id:repo-123' \
  --parent-worktree 'worktree:worktree-456' \
  --name 'fix-create-orca-worktree' \
  --agent claude \
  --prompt "$prompt" \
  --activate \
  --json

[[ "$(grep -Fxc 'worktree create' "$orca_command_log")" -eq 1 ]] ||
  fail 'successful worktree create did not run exactly once'

set +e
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  ORCA_DATA_FILE="$orca_data_file" \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_SHOW_ARGS="$orca_show_args" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  TEST_ORCA_SHOW_REPO_ID='repo-123' \
  TEST_ORCA_SHOW_WORKTREE_ID='worktree-456' \
  TEST_ORCA_CREATE_OK='false' \
  bash "$gwai_orca_script" --provider codex 'surface Orca create failure' >"$run_output" 2>&1
create_failure_status=$?
set -e

((create_failure_status != 0)) || fail 'Orca create response with ok:false unexpectedly succeeded'
grep -Fq -- '{"ok":false,"error":{"message":"mocked Orca create failure"}}' "$run_output" ||
  fail 'Orca create failure response was not written to stderr'

set +e
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  ORCA_DATA_FILE="$orca_data_file" \
  TEST_CLAUDE_OUTPUT='invalid branch name' \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_SHOW_ARGS="$orca_show_args" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  TEST_ORCA_SHOW_REPO_ID='repo-123' \
  TEST_ORCA_SHOW_WORKTREE_ID='worktree-456' \
  bash "$gwai_orca_script" --provider codex 'reject invalid generated branch name' >"$run_output" 2>&1
invalid_branch_status=$?
set -e

((invalid_branch_status != 0)) || fail 'invalid generated branch name unexpectedly succeeded'
[[ "$(grep -Fxc 'worktree create' "$orca_command_log")" -eq 2 ]] ||
  fail 'unexpected worktree create count'

printf 'test-gwai-orca: OK\n'
