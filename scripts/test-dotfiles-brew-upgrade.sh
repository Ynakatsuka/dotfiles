#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_dotfiles-brew-upgrade"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin"

cat >"$TMP_DIR/bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"$BREW_TEST_CALLS"

case "$*" in
  "list --cask stablyai/orca/orca")
    [ "$BREW_TEST_ORCA_INSTALLED" = true ]
    ;;
  "outdated --cask --quiet")
    printf '%s\n' google-chrome docker-desktop
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/brew"

export BREW_TEST_CALLS="$TMP_DIR/brew-calls"
export PATH="$TMP_DIR/bin:/usr/bin:/bin"

assert_called() {
  local expected=$1
  grep -Fxq "$expected" "$BREW_TEST_CALLS" || {
    echo "FAIL: expected call was not made: $expected" >&2
    exit 1
  }
}

assert_not_called() {
  local unexpected=$1
  if grep -Fxq "$unexpected" "$BREW_TEST_CALLS"; then
    echo "FAIL: unexpected call was made: $unexpected" >&2
    exit 1
  fi
}

export BREW_TEST_ORCA_INSTALLED=true
: >"$BREW_TEST_CALLS"
bash "$SCRIPT"

assert_called "upgrade --cask stablyai/orca/orca"
assert_called "upgrade --cask docker-desktop"
assert_not_called "upgrade --cask google-chrome"

export BREW_TEST_ORCA_INSTALLED=false
: >"$BREW_TEST_CALLS"
bash "$SCRIPT"

assert_not_called "upgrade --cask stablyai/orca/orca"

echo "test-dotfiles-brew-upgrade: OK"
