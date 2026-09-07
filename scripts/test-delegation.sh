#!/usr/bin/env bash
# Contract tests for the bulk-read and code-write delegation scripts and the
# shared bulk-read-guard PreToolUse hook. Uses a fake `codex` so no model is
# called.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BULK_READ="$REPO_ROOT/home/dot_local/bin/executable_bulk-read"
GUARD="$REPO_ROOT/home/dot_local/bin/executable_bulk-read-guard"
CODE_WRITE="$REPO_ROOT/home/dot_local/bin/executable_code-write"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/work"
cat >"$TMP_DIR/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >"$CODEX_TEST_ARGS"
cat >"$CODEX_TEST_PROMPT"
out=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--output-last-message" ]; then
    out=$2
    break
  fi
  shift
done
[ -n "$out" ] || exit 64
if grep -q 'FAIL_THE_READER' "$CODEX_TEST_PROMPT"; then
  echo "ERROR: You've hit your usage limit." >&2
  exit 3
fi
if grep -q '^<spec>$' "$CODEX_TEST_PROMPT"; then
  target="$(sed -n 's/^<target path="\([^"]*\)".*/\1/p' "$CODEX_TEST_PROMPT")"
  if ! grep -q 'SKIP_THE_WRITE' "$CODEX_TEST_PROMPT"; then
    printf 'def test_generated():\n    assert True\n' >"$target"
  fi
  echo "Wrote one generated test." >"$out"
  exit 0
fi
echo "Service.java defines the entry point." >"$out"
echo "progress noise that must not reach stdout"
EOF
chmod +x "$TMP_DIR/bin/codex"

export PATH="$TMP_DIR/bin:/usr/bin:/bin"
export CODEX_TEST_ARGS="$TMP_DIR/codex-args"
export CODEX_TEST_PROMPT="$TMP_DIR/codex-prompt"

cd "$TMP_DIR/work"
printf 'alpha\nbeta\ngamma\n' >small.txt
seq 1 400 >big.txt
printf 'bin\0ary\n' >blob.bin

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# --- bulk-read ------------------------------------------------------------------

: >"$CODEX_TEST_ARGS"
if bash "$BULK_READ" --question "q" missing.txt 2>/dev/null; then
  fail "bulk-read accepted a missing file"
fi
[ ! -s "$CODEX_TEST_ARGS" ] || fail "bulk-read called codex for a missing file"

if bash "$BULK_READ" small.txt 2>/dev/null; then
  fail "bulk-read accepted a call without --question"
fi

answer="$(bash "$BULK_READ" --question "What does small.txt contain?" small.txt 2>/dev/null)"
[ "$answer" = "Service.java defines the entry point." ] ||
  fail "bulk-read stdout is not the reader's final message: $answer"
grep -q -- '--model gpt-5.6-luna' "$CODEX_TEST_ARGS" || fail "bulk-read did not select gpt-5.6-luna"
grep -q -- 'model_reasoning_effort="max"' "$CODEX_TEST_ARGS" || fail "bulk-read did not set max reasoning effort"
grep -q -- '--sandbox read-only' "$CODEX_TEST_ARGS" || fail "bulk-read did not run read-only"
grep -q -- '--disable hooks' "$CODEX_TEST_ARGS" || fail "bulk-read did not disable hooks in the reader"
grep -q '<question>' "$CODEX_TEST_PROMPT" || fail "prompt lacks the question block"
grep -q 'What does small.txt contain?' "$CODEX_TEST_PROMPT" || fail "prompt lacks the question text"
grep -q '<file path="small.txt" lines="3">' "$CODEX_TEST_PROMPT" || fail "prompt lacks the file wrapper"
grep -q '^gamma$' "$CODEX_TEST_PROMPT" || fail "prompt lacks the file content"

set +e
failure_output="$(bash "$BULK_READ" --question "FAIL_THE_READER" small.txt 2>&1)"
failure_status=$?
set -e
[ "$failure_status" -eq 3 ] || fail "bulk-read did not propagate the reader's exit code: $failure_status"
grep -q 'codex exec failed with exit code 3' <<<"$failure_output" || fail "bulk-read did not report the failure: $failure_output"
grep -q "ERROR: You've hit your usage limit." <<<"$failure_output" || fail "bulk-read hid the reader's error: $failure_output"

# --- code-write -----------------------------------------------------------------

: >"$CODEX_TEST_ARGS"
if bash "$CODE_WRITE" --target out.py 2>/dev/null; then
  fail "code-write accepted a call without --spec"
fi
if bash "$CODE_WRITE" --spec "s" 2>/dev/null; then
  fail "code-write accepted a call without --target"
fi
if bash "$CODE_WRITE" --spec "s" --target missing-dir/out.py 2>/dev/null; then
  fail "code-write accepted a target in a missing directory"
fi
if bash "$CODE_WRITE" --spec "s" --target out.py --reference nope.py 2>/dev/null; then
  fail "code-write accepted a missing reference file"
fi
[ ! -s "$CODEX_TEST_ARGS" ] || fail "code-write called codex for invalid arguments"

printf 'def test_existing():\n    assert 1 == 1\n' >ref_test.py
write_output="$(bash "$CODE_WRITE" --spec "Write a test for the greeter." --target out_test.py --reference ref_test.py 2>/dev/null)"
grep -q '^code-write: wrote out_test.py (2 lines)$' <<<"$write_output" ||
  fail "code-write did not report the written target: $write_output"
grep -q 'Wrote one generated test.' <<<"$write_output" || fail "code-write stdout lacks the writer summary: $write_output"
grep -q 'def test_generated' out_test.py || fail "code-write target was not written"
grep -q -- '--model gpt-5.6-luna' "$CODEX_TEST_ARGS" || fail "code-write did not select gpt-5.6-luna"
grep -q -- '--sandbox workspace-write' "$CODEX_TEST_ARGS" || fail "code-write did not allow workspace writes"
grep -q -- '--disable hooks' "$CODEX_TEST_ARGS" || fail "code-write did not disable hooks in the writer"
grep -q 'Write a test for the greeter.' "$CODEX_TEST_PROMPT" || fail "prompt lacks the spec"
grep -q '<target path="out_test.py" exists="false" />' "$CODEX_TEST_PROMPT" || fail "prompt lacks the target marker"
grep -q '<reference path="ref_test.py" lines="2">' "$CODEX_TEST_PROMPT" || fail "prompt lacks the reference wrapper"
grep -q 'def test_existing' "$CODEX_TEST_PROMPT" || fail "prompt lacks the reference content"

write_output="$(bash "$CODE_WRITE" --spec "Extend it." --target out_test.py 2>/dev/null)"
grep -q '<target path="out_test.py" exists="true" lines="2">' "$CODEX_TEST_PROMPT" || fail "prompt lacks the existing target content"

set +e
failure_output="$(bash "$CODE_WRITE" --spec "SKIP_THE_WRITE" --target never.py 2>&1)"
failure_status=$?
set -e
[ "$failure_status" -eq 1 ] || fail "code-write did not fail when nothing was written: $failure_status"
grep -q 'did not write never.py' <<<"$failure_output" || fail "code-write did not report the missing write: $failure_output"

# --- bulk-read-guard -------------------------------------------------------------

run_guard() {
  local tool_name=$1 tool_input=$2
  jq -cn --arg tool_name "$tool_name" --argjson tool_input "$tool_input" --arg cwd "$TMP_DIR/work" '{
    hook_event_name: "PreToolUse",
    tool_name: $tool_name,
    tool_input: $tool_input,
    cwd: $cwd
  }' | bash "$GUARD"
}

assert_denied() {
  local label=$1 output
  output="$(run_guard "$2" "$3")"
  [ -n "$output" ] || fail "$label was passed through instead of denied"
  jq -e '.hookSpecificOutput.permissionDecision == "deny"' <<<"$output" >/dev/null 2>&1 ||
    fail "$label was not denied: $output"
  jq -e '.hookSpecificOutput.permissionDecisionReason | contains("bulk-read --question")' <<<"$output" >/dev/null 2>&1 ||
    fail "$label deny reason does not point to bulk-read: $output"
}

assert_allowed() {
  local label=$1 output
  output="$(run_guard "$2" "$3")"
  [ -z "$output" ] || fail "$label was not passed through: $output"
}

assert_denied "Read of a large file" Read '{"file_path":"'"$TMP_DIR"'/work/big.txt"}'
assert_denied "Read with a limit wider than the threshold" Read '{"file_path":"'"$TMP_DIR"'/work/big.txt","offset":1,"limit":2000}'
assert_allowed "Read with a bounded range" Read '{"file_path":"'"$TMP_DIR"'/work/big.txt","offset":1,"limit":100}'
assert_allowed "Read near the end of a large file" Read '{"file_path":"'"$TMP_DIR"'/work/big.txt","offset":300}'
assert_allowed "Read of a small file" Read '{"file_path":"'"$TMP_DIR"'/work/small.txt"}'
assert_allowed "Read of a binary file" Read '{"file_path":"'"$TMP_DIR"'/work/blob.bin"}'

assert_denied "cat of a large file" Bash '{"command":"cat big.txt"}'
assert_denied "rtk cat of a large file" Bash '{"command":"rtk cat big.txt"}'
assert_denied "cat inside a pipeline" Bash '{"command":"cat big.txt | grep x"}'
assert_denied "cat of files that together exceed the threshold" Bash '{"command":"cat big.txt small.txt"}'
assert_allowed "bounded sed of a large file" Bash "{\"command\":\"sed -n '1,40p' big.txt\"}"
assert_allowed "cat of a small file" Bash '{"command":"cat small.txt | head"}'
assert_allowed "heredoc write into a large file" Bash "{\"command\":\"cat <<'EOF' > big.txt\\nline\\nEOF\"}"
assert_allowed "cat of a missing file" Bash '{"command":"cat nope.txt"}'
assert_allowed "unrelated tool" Write '{"file_path":"'"$TMP_DIR"'/work/big.txt","content":"x"}'

echo "test-delegation: OK"
