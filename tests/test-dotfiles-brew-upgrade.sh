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
  "outdated --cask --quiet")
    read -r -a casks <<<"${BREW_TEST_OUTDATED_CASKS:-google-chrome docker-desktop}"
    printf '%s\n' "${casks[@]}"
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

# Normal run skips google-chrome and stablyai/orca/orca, and does not force-upgrade Orca.
export BREW_TEST_OUTDATED_CASKS="google-chrome stablyai/orca/orca docker-desktop"
: >"$BREW_TEST_CALLS"
bash "$SCRIPT"

assert_called "upgrade --cask docker-desktop"
assert_not_called "upgrade --cask google-chrome"
assert_not_called "upgrade --cask stablyai/orca/orca"

# Without Orca IDE CLI on PATH, the unrelated "orca" cask token is still upgraded.
export BREW_TEST_OUTDATED_CASKS="orca docker-desktop"
: >"$BREW_TEST_CALLS"
bash "$SCRIPT"

assert_called "upgrade --cask orca docker-desktop"

# With Orca IDE CLI installed, the "orca" cask token is skipped too.
mkdir -p "$TMP_DIR/Orca.app/Contents/Resources/bin"
printf '#!/usr/bin/env bash\n' >"$TMP_DIR/Orca.app/Contents/Resources/bin/orca"
chmod +x "$TMP_DIR/Orca.app/Contents/Resources/bin/orca"
ln -s "$TMP_DIR/Orca.app/Contents/Resources/bin/orca" "$TMP_DIR/bin/orca"
: >"$BREW_TEST_CALLS"
bash "$SCRIPT"

assert_called "upgrade --cask docker-desktop"
assert_not_called "upgrade --cask orca docker-desktop"
assert_not_called "upgrade --cask orca"
assert_not_called "upgrade --cask stablyai/orca/orca"

echo "test-dotfiles-brew-upgrade: OK"
