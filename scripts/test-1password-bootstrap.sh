#!/usr/bin/env bash
# Exercise the 1Password installer and Linux bootstrap routing without host changes.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BASH_BIN=$BASH
TEST_DIR="$(mktemp -d)"
cleanup() {
  local result=$?
  if [ "$result" -ne 0 ] && [ -f "$TEST_DIR/output" ]; then
    sed -n '1,100p' "$TEST_DIR/output" >&2
  fi
  rm -rf "$TEST_DIR"
  exit "$result"
}
trap cleanup EXIT
REPO_DIR="$TEST_DIR/repo"
BIN_DIR="$TEST_DIR/bin"
MODULE_DIR="$REPO_DIR/bootstrap/linux/modules"
INSTALLER="$MODULE_DIR/15_1password.sh"
MAIN="$REPO_DIR/bootstrap/linux/main.sh"
TEST_CALLS="$TEST_DIR/calls"
TEST_OUTPUT="$TEST_DIR/output"

mkdir -p "$BIN_DIR" "$TEST_DIR/tmp" "$REPO_DIR/bootstrap/lib" "$MODULE_DIR"
cp "$ROOT_DIR/bootstrap/lib/common.sh" "$REPO_DIR/bootstrap/lib/common.sh"
cp "$ROOT_DIR/bootstrap/linux/modules/15_1password.sh" "$INSTALLER"
cp "$ROOT_DIR/bootstrap/linux/main.sh" "$MAIN"
cat >>"$REPO_DIR/bootstrap/lib/common.sh" <<'EOF'

require_ubuntu() { return 0; }
require_ubuntu_2204() { return 0; }
has_nvidia_gpu() { return 1; }
confirm() { return 1; }
run_mise_install() { printf 'run_mise_install\n' >>"$TEST_CALLS"; }
EOF

cat >"$BIN_DIR/dpkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${TEST_ARCH:-amd64}"
EOF
cat >"$BIN_DIR/dpkg-query" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'install ok installed\n'
[ "${TEST_INSTALLED:-0}" = 1 ]
EOF
cat >"$BIN_DIR/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'curl'
  printf ' %s' "$@"
  printf '\n'
} >>"$TEST_CALLS"
[ "${TEST_FAIL:-}" != curl ] || exit 7
while [ $# -gt 0 ]; do
  if [ "$1" = -o ]; then
    shift
    package_file="$1"
    case "$package_file" in "$TEST_DIR"/*) ;; *) exit 78 ;; esac
    printf 'dummy package\n' >"$package_file"
    exit 0
  fi
  shift
done
exit 64
EOF
cat >"$BIN_DIR/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'sudo'
  printf ' %s' "$@"
  printf '\n'
} >>"$TEST_CALLS"
case "$*" in
  'apt-get update') [ "${TEST_FAIL:-}" != apt-update ] ;;
  'apt-get install -y '*)
    package_file="${4:-}"
    [ -f "$package_file" ] && [ -r "$package_file" ] || exit 1
    printf 'package-readable:%s\n' "$package_file" >>"$TEST_CALLS"
    [ "${TEST_FAIL:-}" != apt-install ]
    ;;
  *) exit 64 ;;
esac
EOF
cat >"$BIN_DIR/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 64
EOF
cat >"$BIN_DIR/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case " $* " in
  *' extension list '*) printf 'dlvhdr/gh-dash\n' ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$BIN_DIR/"*

for module in 00_base 05_expressvpn 20_docker 25_nvidia_container 10_gpu_nvidia 30_clis 40_dotfiles 99_cleanup; do
  cat >"$MODULE_DIR/$module.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '%s' "${0##*/}"
  printf ' %s' "$@"
  printf '\n'
} >>"$TEST_CALLS"
EOF
  chmod +x "$MODULE_DIR/$module.sh"
done

export TEST_DIR TEST_CALLS TEST_ARCH=amd64 TEST_INSTALLED=0
export PATH="$BIN_DIR:/usr/bin:/bin"
export TMPDIR="$TEST_DIR/tmp"
: >"$TEST_CALLS"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_contains() {
  grep -Fq "$2" "$1" || fail "missing '$2' in $1"
}

assert_not_contains() {
  if grep -Fq "$2" "$1"; then
    fail "unexpected '$2' in $1"
  fi
}

assert_no_calls() {
  [ ! -s "$TEST_CALLS" ] || fail 'unexpected calls were logged'
}

package_from_curl() {
  sed -n 's/^curl .* -o //p' "$TEST_CALLS"
}

assert_package_cleaned() {
  local package_file="$1"
  [ -n "$package_file" ] || fail 'package path was not logged'
  [ ! -e "$package_file" ] || fail "package was not removed: $package_file"
  [ ! -e "${package_file%/*}" ] || fail "package directory was not removed: ${package_file%/*}"
}

run_installer() {
  "$BASH_BIN" "$INSTALLER" "$@" >"$TEST_OUTPUT" 2>&1
}

: >"$TEST_CALLS"
run_installer --dry-run
assert_contains "$TEST_OUTPUT" 'https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb'
assert_contains "$TEST_OUTPUT" 'apt-get install -y'
assert_no_calls
downloaded="$(find "$TEST_DIR" -type f -name 1password.deb -print)"
[ -z "$downloaded" ] || fail 'dry-run created a package file'

: >"$TEST_CALLS"
if run_installer --unknown; then fail 'installer accepted an unknown option'; fi
assert_no_calls

: >"$TEST_CALLS"
TEST_ARCH=arm64 TEST_INSTALLED=1
export TEST_ARCH TEST_INSTALLED
if run_installer; then fail 'installer accepted arm64'; fi
assert_contains "$TEST_OUTPUT" "requires amd64 (detected: arm64)"
assert_no_calls

: >"$TEST_CALLS"
TEST_ARCH=amd64 TEST_INSTALLED=1
export TEST_ARCH TEST_INSTALLED
run_installer
assert_no_calls

: >"$TEST_CALLS"
TEST_INSTALLED=0
export TEST_INSTALLED
unset TEST_FAIL
run_installer
package_file="$(sed -n 's/^sudo apt-get install -y //p' "$TEST_CALLS")"
[ "${package_file##*/}" = 1password.deb ] || fail 'install package path was not logged'
assert_contains "$TEST_CALLS" "package-readable:$package_file"
awk '/^curl / { curl_line = NR } /^sudo apt-get update$/ { update_line = NR } /^sudo apt-get install -y / { install_line = NR } /^package-readable:/ { readable_line = NR } END { exit !(curl_line > 0 && update_line > curl_line && install_line > update_line && readable_line > install_line) }' "$TEST_CALLS" || fail 'install calls were out of order'
assert_package_cleaned "$package_file"

: >"$TEST_CALLS"
TEST_FAIL=curl
export TEST_FAIL
if run_installer; then fail 'installer ignored curl failure'; fi
package_file="$(package_from_curl)"
assert_not_contains "$TEST_CALLS" 'sudo '
assert_package_cleaned "$package_file"

: >"$TEST_CALLS"
TEST_FAIL=apt-update
export TEST_FAIL
if run_installer; then fail 'installer ignored apt update failure'; fi
package_file="$(package_from_curl)"
assert_contains "$TEST_CALLS" 'sudo apt-get update'
assert_not_contains "$TEST_CALLS" 'sudo apt-get install -y'
assert_package_cleaned "$package_file"

: >"$TEST_CALLS"
TEST_FAIL=apt-install
export TEST_FAIL
if run_installer; then fail 'installer ignored apt install failure'; fi
package_file="$(sed -n 's/^sudo apt-get install -y //p' "$TEST_CALLS")"
assert_contains "$TEST_CALLS" "package-readable:$package_file"
assert_package_cleaned "$package_file"
unset TEST_FAIL

# The existing Linux orchestrator expands empty arrays under nounset, which
# requires Bash 4.4+. macOS ships Bash 3.2; installer cases still run there.
if [ "${BASH_VERSINFO[0]}" -lt 4 ] ||
  { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
  printf 'test-1password-bootstrap: installer OK (routing requires Bash 4.4+)\n'
  exit 0
fi

cat >"$INSTALLER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
{
  printf '%s' "${0##*/}"
  printf ' %s' "$@"
  printf '\n'
} >>"$TEST_CALLS"
EOF
chmod +x "$INSTALLER"

run_main() {
  : >"$TEST_CALLS"
  "$BASH_BIN" "$MAIN" "$@" >"$TEST_OUTPUT" 2>&1
}

run_main --plan full --dry-run
assert_contains "$TEST_CALLS" '15_1password.sh --dry-run'
run_main --plan standard --dry-run
assert_not_contains "$TEST_CALLS" '15_1password.sh'
run_main --plan minimal --dry-run
assert_not_contains "$TEST_CALLS" '15_1password.sh'
run_main --with-1password --dry-run
assert_contains "$TEST_CALLS" '15_1password.sh --dry-run'

if run_main --user-only --with-1password; then fail 'user-only accepted --with-1password'; fi
assert_no_calls
if run_main --plan standard --with-1password; then fail 'standard plan accepted --with-1password'; fi
assert_no_calls

printf 'test-1password-bootstrap: OK\n'
