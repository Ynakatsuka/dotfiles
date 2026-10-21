#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
gwai_orca_source="${GWAI_ORCA_SCRIPT:-$repo_root/home/dot_local/bin/executable_gwai-orca}"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-orca-test.XXXXXX")
test_dir=$(cd "$test_dir" && pwd -P)
mkdir -p "$test_dir/.local/bin"
cp "$gwai_orca_source" "$test_dir/.local/bin/gwai-orca"
gwai_orca_script="$test_dir/.local/bin/gwai-orca"

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
orca_command_log="$test_dir/orca-command.log"
orca_create_args="$test_dir/orca-create.args"
run_output="$test_dir/run-output"
mkdir -p "$bin_dir"

# scripts/test-gwai-worktree-name.sh covers naming; this fake checks the wiring.
cat >"$bin_dir/gwai-worktree-name" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\0' "$@" >"$TEST_NAMER_ARGS"
if [[ "${TEST_NAMER_STATUS:-0}" != 0 ]]; then
  printf 'Error: mocked naming failure\n' >&2
  exit "$TEST_NAMER_STATUS"
fi
printf '261017-パスワード再設定修正\n'
MOCK

cat >"$bin_dir/orca" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s %s\n' "$1" "$2" >>"$TEST_ORCA_COMMAND_LOG"

case "$1 $2" in
'worktree ps')
  # A pinned workspace in another repository must not be chosen over the selected one.
  printf '{"ok":true,"result":{"worktrees":[{"worktreeId":"repo-999::/pinned","repoId":"repo-999","isActive":false,"isPinned":true},{"worktreeId":"repo-123::/selected","repoId":"repo-123","isActive":%s,"isPinned":false}],"truncated":false}}\n' \
    "${TEST_ORCA_PS_ACTIVE:-true}"
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

chmod +x "$bin_dir/gwai-worktree-name" "$bin_dir/orca"
export TEST_NAMER_ARGS="$test_dir/namer.args"

set +e
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  TEST_ORCA_PS_ACTIVE='false' \
  bash "$gwai_orca_script" 'must not create' >"$run_output" 2>&1
failure_status=$?
set -e

((failure_status != 0)) || fail 'missing active workspace unexpectedly succeeded'
[[ ! -e "$orca_create_args" ]] || fail 'worktree create ran without an active workspace'
[[ ! -e "$TEST_NAMER_ARGS" ]] || fail 'naming ran without an active workspace'

prompt=$'Create an Orca worktree with spaces\nand a second line.'
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  bash "$gwai_orca_script" -- "$prompt" >"$run_output" 2>&1

assert_args_equal "$TEST_NAMER_ARGS" -- "$prompt"
assert_args_equal "$orca_create_args" \
  worktree create \
  --repo 'id:repo-123' \
  --no-parent \
  --name '261017-パスワード再設定修正' \
  --agent claude \
  --prompt "$prompt" \
  --activate \
  --json

[[ "$(grep -Fxc 'worktree create' "$orca_command_log")" -eq 1 ]] ||
  fail 'successful worktree create did not run exactly once'

set +e
PATH="$bin_dir:$PATH" \
  ORCA_BIN="$bin_dir/orca" \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
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
  TEST_NAMER_STATUS=1 \
  TEST_ORCA_COMMAND_LOG="$orca_command_log" \
  TEST_ORCA_CREATE_ARGS="$orca_create_args" \
  bash "$gwai_orca_script" --provider codex 'naming fails' >"$run_output" 2>&1
naming_failure_status=$?
set -e

((naming_failure_status != 0)) || fail 'naming failure unexpectedly succeeded'
grep -Fq 'mocked naming failure' "$run_output" || fail 'naming failure was not written to stderr'
[[ "$(grep -Fxc 'worktree create' "$orca_command_log")" -eq 2 ]] ||
  fail 'worktree create ran after naming failed'

printf 'test-gwai-orca: OK\n'
