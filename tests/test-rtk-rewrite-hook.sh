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
    echo "rtk ${RTK_TEST_VERSION:-0.49.0}"
    ;;
  rewrite)
    printf '%s\n' "$*" >>"$RTK_TEST_CALLS"
    shift
    printf 'rtk %s\n' "$*"
    if [[ "$1" == find\ * || "$1" == *'| find '* ]]; then
      exit 3
    fi
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
  }' >"$TMP_DIR/input.json"
  bash "$HOOK" <"$TMP_DIR/input.json"
}

assert_rewritten() {
  local command=$1 expected_decision=$2 output rewritten decision
  : >"$RTK_TEST_CALLS"
  output="$(run_hook "$command")"
  rewritten="$(jq -r '.hookSpecificOutput.updatedInput.command' <<<"$output")"
  [ "$rewritten" = "rtk $command" ] || {
    echo "FAIL: command was not rewritten: $command" >&2
    exit 1
  }
  [ -s "$RTK_TEST_CALLS" ] || {
    echo "FAIL: RTK was not called: $command" >&2
    exit 1
  }
  decision="$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$output")"
  [ "$decision" = "$expected_decision" ] || {
    echo "FAIL: wrong permission decision for $command: $decision" >&2
    exit 1
  }
}

assert_rewritten 'find . -type f -o -type l' ''
assert_rewritten 'find . -not -name "*.py"' ''
assert_rewritten 'find . -type f -exec echo {} \;' ''
assert_rewritten 'find . -type f -execdir echo {} \;' ''
assert_rewritten 'find . \( -name "*.py" \)' ''
assert_rewritten "find . '(' -name '*.py' ')'" ''
assert_rewritten 'find . "(" -name "*.py" ")"' ''
assert_rewritten 'printf x | find . -delete' ''
assert_rewritten 'find . -type f -name "*.py"' ''
assert_rewritten 'git status --short' allow
RTK_TEST_VERSION=1.0.0 assert_rewritten 'git status --short' allow

assert_version_bypassed() {
  local version=$1 warning=$2 output
  : >"$RTK_TEST_CALLS"
  output="$(RTK_TEST_VERSION="$version" run_hook 'find . -type f -o -type l' 2>"$TMP_DIR/version.err")"
  [ -z "$output" ] || {
    echo "FAIL: RTK $version command was rewritten" >&2
    exit 1
  }
  [ ! -s "$RTK_TEST_CALLS" ] || {
    echo "FAIL: RTK $version rewrite was called" >&2
    exit 1
  }
  grep -q "$warning" "$TMP_DIR/version.err" || {
    echo "FAIL: RTK $version warning is missing" >&2
    exit 1
  }
}
assert_version_bypassed 0.43.0 'need >= 0.49.0'
assert_version_bypassed 0.48.9 'need >= 0.49.0'
assert_version_bypassed unknown 'cannot determine rtk version'

echo "test-rtk-rewrite-hook: OK"
