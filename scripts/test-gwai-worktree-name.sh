#!/usr/bin/env bash
# Verify the shared gwai worktree naming helper with a fake claude.

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
helper="$repo_root/home/dot_local/bin/executable_gwai-worktree-name"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/gwai-worktree-name-test.XXXXXX")

cleanup() {
  rm -rf "$test_dir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

bin_dir="$test_dir/bin"
claude_args="$test_dir/claude.args"
run_output="$test_dir/run-output"
run_error="$test_dir/run-error"
mkdir -p "$bin_dir"

cat >"$bin_dir/claude" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\0' "$@" >"$TEST_CLAUDE_ARGS"
printf '%s\n' "$TEST_CLAUDE_OUTPUT"
exit "${TEST_CLAUDE_STATUS:-0}"
MOCK

cat >"$bin_dir/date" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail

[[ "$*" == '+%y%m%d' ]] || {
  printf 'unexpected date arguments: %s\n' "$*" >&2
  exit 1
}
printf '261017\n'
MOCK

chmod +x "$bin_dir/claude" "$bin_dir/date"

run_helper() {
  PATH="$bin_dir:$PATH" TEST_CLAUDE_ARGS="$claude_args" bash "$helper" "$@" >"$run_output" 2>"$run_error"
}

expect_failure() {
  local expected_error="$1"
  shift

  if run_helper "$@"; then
    fail "helper unexpectedly succeeded: $*"
  fi
  [[ ! -s "$run_output" ]] || fail "helper printed a name on failure: $(<"$run_output")"
  grep -Fq -- "$expected_error" "$run_error" ||
    fail "missing error '$expected_error' in: $(<"$run_error")"
}

# The first candidate has 11 characters and the second has surrounding spaces,
# so the trimmed second candidate must win.
prompt=$'-leading dash stays part of the prompt\nsecond line'
TEST_CLAUDE_OUTPUT=$'パスワードリセット修正\n パスワード再設定修正 \nBQコスト削減' run_helper -- "$prompt" ||
  fail "helper failed: $(<"$run_error")"
[[ "$(<"$run_output")" == '261017-パスワード再設定修正' ]] ||
  fail "unexpected name: $(<"$run_output")"

actual_args=()
while IFS= read -r -d '' argument; do
  actual_args+=("$argument")
done <"$claude_args"
expected_flags=(
  -p --model haiku --effort low
  --setting-sources '' --strict-mcp-config --disable-slash-commands
  --no-session-persistence --tools ''
  --system-prompt 'Follow the user instruction exactly. Output only the requested text.'
)
[[ "${#actual_args[@]}" -eq $((${#expected_flags[@]} + 1)) ]] ||
  fail "unexpected claude argument count: ${#actual_args[@]}"
for index in "${!expected_flags[@]}"; do
  [[ "${actual_args[$index]}" == "${expected_flags[$index]}" ]] ||
    fail "unexpected claude argument $index: ${actual_args[$index]}"
done
[[ "${actual_args[${#actual_args[@]} - 1]}" == *"タスク: ${prompt}" ]] ||
  fail "naming prompt does not end with the task: ${actual_args[${#actual_args[@]} - 1]}"

# A client prefix has its own 10-character limit, so the name part keeps its
# full limit.
TEST_CLAUDE_OUTPUT=$'トヨタ-需要予測モデルレビュー\nトヨタ-需要予測レビュー' run_helper -- 'client task' ||
  fail "helper failed for a client task: $(<"$run_error")"
[[ "$(<"$run_output")" == '261017-トヨタ-需要予測レビュー' ]] ||
  fail "unexpected client name: $(<"$run_output")"

TEST_CLAUDE_OUTPUT=$'パスワードリセット修正\n再設定・修正\n再設定 修正\nサイバーエージェント社-修正\n-需要予測\nA社-B社-修正\nトヨタ - 修正' \
  expect_failure 'no generated worktree name had 10 or fewer allowed characters' 'reject invalid names'

TEST_CLAUDE_OUTPUT='' TEST_CLAUDE_STATUS=1 \
  expect_failure 'worktree name generation failed' 'claude fails'

TEST_CLAUDE_OUTPUT='unused' expect_failure 'exactly one prompt is required'
TEST_CLAUDE_OUTPUT='unused' expect_failure 'exactly one prompt is required' first second
TEST_CLAUDE_OUTPUT='unused' expect_failure 'prompt is empty' ''
TEST_CLAUDE_OUTPUT='unused' expect_failure 'unknown option: --model' --model sonnet 'task'

printf 'test-gwai-worktree-name: OK\n'
