#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO_ROOT/home/dot_claude/hooks/executable_rtk-rewrite.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/home"

cat >"$TMP_DIR/bin/rtk" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version)
    echo "rtk 0.43.0"
    ;;
  rewrite)
    printf '%s\n' "$*" >>"$RTK_TEST_CALLS"
    shift
    printf 'rtk %s\n' "$*"
    exit 0
    ;;
  *)
    exit 64
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/rtk"

export HOME="$TMP_DIR/home"
export PATH="$TMP_DIR/bin:/usr/bin:/bin"
export RTK_TEST_CALLS="$TMP_DIR/rtk-calls"

run_hook() {
  local command=$1
  jq -cn --arg command "$command" '{
    hook_event_name: "PreToolUse",
    tool_name: "Bash",
    tool_input: {command: $command, description: "test"}
  }' | bash "$HOOK"
}

assert_bypassed() {
  local command=$1 output
  : >"$RTK_TEST_CALLS"
  output="$(run_hook "$command")"
  [ -z "$output" ] || {
    echo "FAIL: compound find was rewritten: $command" >&2
    exit 1
  }
  [ ! -s "$RTK_TEST_CALLS" ] || {
    echo "FAIL: RTK was called for compound find: $command" >&2
    exit 1
  }
}

assert_rewritten() {
  local command=$1 output rewritten
  : >"$RTK_TEST_CALLS"
  output="$(run_hook "$command")"
  rewritten="$(jq -r '.hookSpecificOutput.updatedInput.command' <<<"$output")"
  [ "$rewritten" = "rtk $command" ] || {
    echo "FAIL: simple command was not rewritten: $command" >&2
    exit 1
  }
  [ -s "$RTK_TEST_CALLS" ] || {
    echo "FAIL: RTK was not called for simple command: $command" >&2
    exit 1
  }
}

assert_bypassed 'find . -type f -o -type l'
assert_bypassed 'find . -type f -exec echo {} \;'
assert_bypassed 'find . \( -name "*.py" \)'
assert_bypassed "find . '(' -name '*.py' ')'"
assert_bypassed 'find . "(" -name "*.py" ")"'
assert_bypassed 'printf x | find . -delete'
assert_rewritten 'find . -type f -name "*.py"'
assert_rewritten 'git status --short'

echo "test-rtk-rewrite-hook: OK"
