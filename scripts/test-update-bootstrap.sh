#!/usr/bin/env bash
# Exercise update task ordering and bootstrap installer commands without changes to the host.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/home/private_dot_config/mise/config.toml"
COMMON="$ROOT_DIR/bootstrap/lib/common.sh"
MISE_BIN="$(command -v mise)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

mkdir -p "$TEST_DIR/bin" "$TEST_DIR/home/.local/bin" "$TEST_DIR/project"
ln -s "$MISE_BIN" "$TEST_DIR/bin/mise"

# Load the real task definitions while keeping the fixture free of tool installs.
awk '/^\[tasks\./ { keep = ($0 == "[tasks.update-dotfiles]" || $0 == "[tasks.maintenance]") } keep { print }' \
  "$CONFIG" >"$TEST_DIR/base.toml"
cp "$TEST_DIR/base.toml" "$TEST_DIR/updated.toml"
cat >>"$TEST_DIR/updated.toml" <<'EOF'

[tasks.updated-marker]
run = 'echo updated-config >> "$TEST_CALLS"'
EOF
cat >"$TEST_DIR/project/mise.toml" <<'EOF'
[tasks.update-dotfiles]
run = 'echo local-task >> "$TEST_CALLS"'
EOF

cat >"$TEST_DIR/bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  git)
    [ "$*" = 'git pull -- --ff-only' ]
    echo pull >>"$TEST_CALLS"
    [ "${FAIL_AT:-}" != pull ]
    ;;
  apply)
    [ "$*" = 'apply --force -v' ]
    echo apply-force >>"$TEST_CALLS"
    [ "${FAIL_AT:-}" != apply ]
    cp "$TEST_CONFIG_UPDATED" "$MISE_GLOBAL_CONFIG_FILE"
    ;;
  verify)
    [ "$*" = verify ]
    echo verify >>"$TEST_CALLS"
    [ "${FAIL_AT:-}" != verify ]
    ;;
  source-path)
    printf '%s/.local/bin/%s\n' "$HOME" "${2##*/}"
    ;;
  *) exit 64 ;;
esac
EOF

cat >"$TEST_DIR/home/.local/bin/dotfiles-mise-up" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mise run -C / updated-marker >/dev/null
echo mise-up >>"$TEST_CALLS"
[ "${FAIL_AT:-}" != mise-up ]
EOF
cat >"$TEST_DIR/home/.local/bin/dotfiles-cursor-agent-upgrade" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo cursor-upgrade >>"$TEST_CALLS"
EOF
cat >"$TEST_DIR/bin/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
cat >"$TEST_DIR/home/.local/bin/dotfiles-brew-upgrade" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo brew-upgrade >>"$TEST_CALLS"
EOF
chmod +x "$TEST_DIR/bin/chezmoi" "$TEST_DIR/home/.local/bin/"* "$TEST_DIR/bin/brew"

export HOME="$TEST_DIR/home"
export PATH="$TEST_DIR/bin:/usr/bin:/bin"
export MISE_GLOBAL_CONFIG_FILE="$TEST_DIR/global.toml"
export MISE_TASK_RUN_AUTO_INSTALL=false
export TEST_CONFIG_UPDATED="$TEST_DIR/updated.toml"
export TEST_CALLS="$TEST_DIR/calls"

assert_calls() {
  local expected="$1"
  diff -u <(printf '%s\n' "$expected") "$TEST_CALLS"
}

run_maintenance() {
  cp "$TEST_DIR/base.toml" "$MISE_GLOBAL_CONFIG_FILE"
  : >"$TEST_CALLS"
  (cd "$TEST_DIR/project" && mise run maintenance >"$TEST_DIR/output" 2>&1)
}

cp "$TEST_DIR/base.toml" "$MISE_GLOBAL_CONFIG_FILE"
: >"$TEST_CALLS"
(cd "$TEST_DIR/project" && mise run -C / update-dotfiles >"$TEST_DIR/output" 2>&1)
assert_calls $'pull\napply-force\nupdated-config\nmise-up'

cp "$TEST_DIR/base.toml" "$MISE_GLOBAL_CONFIG_FILE"
: >"$TEST_CALLS"
if (cd "$TEST_DIR/project" && mise run -C / update-dotfiles --unknown >"$TEST_DIR/output" 2>&1); then
  echo 'FAIL: update-dotfiles accepted an unknown argument' >&2
  exit 1
fi
[ ! -s "$TEST_CALLS" ]

run_maintenance
assert_calls $'pull\napply-force\nverify\nupdated-config\nmise-up\ncursor-upgrade\nbrew-upgrade'

export FAIL_AT=pull
if run_maintenance; then
  echo 'FAIL: maintenance continued after chezmoi pull failed' >&2
  exit 1
fi
assert_calls pull

export FAIL_AT=apply
if run_maintenance; then
  echo 'FAIL: maintenance continued after chezmoi apply failed' >&2
  exit 1
fi
assert_calls $'pull\napply-force'

export FAIL_AT=verify
if run_maintenance; then
  echo 'FAIL: maintenance continued after chezmoi verify failed' >&2
  exit 1
fi
assert_calls $'pull\napply-force\nverify'

export FAIL_AT=mise-up
if run_maintenance; then
  echo 'FAIL: maintenance continued after mise upgrade failed' >&2
  exit 1
fi
assert_calls $'pull\napply-force\nverify\nupdated-config\nmise-up'
unset FAIL_AT

mv "$TEST_DIR/bin/brew" "$TEST_DIR/bin/brew.disabled"
run_maintenance
assert_calls $'pull\napply-force\nverify\nupdated-config\nmise-up\ncursor-upgrade'
grep -Fq 'brew not found, skipping Homebrew updates' "$TEST_DIR/output"

installer_output="$(bash -c '. "$1"; enable_dry_run; install_chezmoi_official -c; install_chezmoi_official -lc' _ "$COMMON")"
[[ "$installer_output" == *'[DRY-RUN] bash -c sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"'* ]]
[[ "$installer_output" == *'[DRY-RUN] bash -lc sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"'* ]]

echo 'test-update-bootstrap: OK'
