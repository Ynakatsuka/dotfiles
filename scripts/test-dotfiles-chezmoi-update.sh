#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_dotfiles-chezmoi-update"
CONFIG="$REPO_ROOT/home/private_dot_config/mise/config.toml"
TMP_DIR="$(mktemp -d)"
TARGET_RELATIVE=".config/cmux/sidebars/agent-board.swift"
TARGET=""
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/home"

cat >"$TMP_DIR/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$CHEZMOI_TEST_CALLS"

case "${1:-}" in
  verify)
    [ "${2:-}" = "$CHEZMOI_TEST_TARGET" ] || exit 64
    [ "$CHEZMOI_TEST_VERIFY_RESULT" = "success" ]
    ;;
  git)
    [ "${2:-}" = "pull" ] && [ "${3:-}" = "--" ] && [ "${4:-}" = "--ff-only" ] || exit 64
    ;;
  diff)
    [ "${2:-}" = "--no-pager" ] || exit 64
    ;;
  apply)
    [ "${2:-}" = "-v" ] || exit 64
    ;;
  *)
    exit 64
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/chezmoi"

export HOME="$TMP_DIR/home"
export PATH="$TMP_DIR/bin:/usr/bin:/bin"
export CHEZMOI_TEST_CALLS="$TMP_DIR/chezmoi-calls"
TARGET="$HOME/$TARGET_RELATIVE"
export CHEZMOI_TEST_TARGET="$TARGET"

test -x "$SCRIPT" || {
  echo "FAIL: dotfiles-chezmoi-update must be executable" >&2
  exit 1
}

assert_calls() {
  local expected=$1 actual
  actual="$(<"$CHEZMOI_TEST_CALLS")"
  [ "$actual" = "$expected" ] || {
    echo "FAIL: unexpected chezmoi calls" >&2
    printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
    exit 1
  }
}

reset_case() {
  rm -f "$TARGET"
  : >"$CHEZMOI_TEST_CALLS"
}

reset_case
mkdir -p "$(dirname "$TARGET")"
printf 'local change\n' >"$TARGET"
export CHEZMOI_TEST_VERIFY_RESULT=failure
if "$SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
  echo "FAIL: differing deployed Agent Board was accepted" >&2
  exit 1
fi
assert_calls "verify $TARGET"
grep -Fq 'will not be overwritten' "$TMP_DIR/stderr" || {
  echo "FAIL: overwrite protection was not explained" >&2
  exit 1
}
grep -Fq "chezmoi diff -- $TARGET" "$TMP_DIR/stderr" || {
  echo "FAIL: review command was not reported" >&2
  exit 1
}

reset_case
mkdir -p "$(dirname "$TARGET")"
touch "$TARGET"
export CHEZMOI_TEST_VERIFY_RESULT=success
"$SCRIPT"
assert_calls $'verify '"$TARGET"$'\ngit pull -- --ff-only\ndiff --no-pager\napply -v'

reset_case
export CHEZMOI_TEST_VERIFY_RESULT=failure
"$SCRIPT"
assert_calls $'git pull -- --ff-only\ndiff --no-pager\napply -v'

for task in update-dotfiles maintenance; do
  task_body="$(awk -v task="$task" '
    $0 == "[tasks." task "]" { in_task = 1; next }
    in_task && /^\[tasks\./ { exit }
    in_task { print }
  ' "$CONFIG")"
  grep -Fq 'dotfiles-chezmoi-update' <<<"$task_body" || {
    echo "FAIL: $task does not invoke dotfiles-chezmoi-update" >&2
    exit 1
  }
  if grep -Eq 'chezmoi (git pull|apply)' <<<"$task_body"; then
    echo "FAIL: $task still directly runs chezmoi pull/apply" >&2
    exit 1
  fi
done

echo "test-dotfiles-chezmoi-update: OK"
