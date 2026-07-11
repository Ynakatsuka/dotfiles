#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/home/dot_local/bin/executable_dotfiles-mise-up"
TMP_DIR="$(mktemp -d)"
ORIGINAL_PATH="$PATH"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/bin" "$TMP_DIR/gh-config" "$TMP_DIR/home/.local/bin"

cat >"$TMP_DIR/bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ -z "${GITHUB_TOKEN:-}" ] || {
  echo "FAIL: fake mise received GITHUB_TOKEN" >&2
  exit 1
}

printf '%s\n' "$*" >>"$MISE_TEST_CALLS"

case "${1:-}" in
  doctor)
    case "$MISE_TEST_DOCTOR_RESULT" in
      true) printf '%s\n' '{"self_update_available":true}' ;;
      false) printf '%s\n' '{"self_update_available":false}' ;;
      missing) printf '%s\n' '{"version":"test"}' ;;
      invalid) printf '%s\n' '{"self_update_available":"false"}' ;;
      malformed) printf '%s\n' '{' ;;
      failure) exit 1 ;;
      *) exit 64 ;;
    esac
    ;;
  self-update)
    ;;
  up)
    printf '%s\n' 'mise up completed'
    ;;
  reshim)
    ;;
  *)
    exit 64
    ;;
esac
EOF
chmod +x "$TMP_DIR/bin/mise"

cat >"$TMP_DIR/bin/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$TMP_DIR/bin/gh"

cat >"$TMP_DIR/home/.local/bin/dotfiles-agent-env-check" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' 'environment checked' >>"$MISE_TEST_CALLS"
EOF
chmod +x "$TMP_DIR/home/.local/bin/dotfiles-agent-env-check"

if ! JQ_BIN="$(PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" command -v jq)"; then
  echo "FAIL: jq is required to run this test" >&2
  exit 1
fi
ln -s "$JQ_BIN" "$TMP_DIR/bin/jq"

unset GH_TOKEN GITHUB_TOKEN
export GH_CONFIG_DIR="$TMP_DIR/gh-config"
export HOME="$TMP_DIR/home"
export PATH="$TMP_DIR/bin:/usr/bin:/bin"
export MISE_TEST_CALLS="$TMP_DIR/mise-calls"

assert_called() {
  local expected=$1
  grep -Fxq "$expected" "$MISE_TEST_CALLS" || {
    echo "FAIL: expected call was not made: $expected" >&2
    exit 1
  }
}

assert_not_called() {
  local unexpected=$1
  if grep -Fxq "$unexpected" "$MISE_TEST_CALLS"; then
    echo "FAIL: unexpected call was made: $unexpected" >&2
    exit 1
  fi
}

run_success_case() {
  local doctor_result=$1 output
  export MISE_TEST_DOCTOR_RESULT="$doctor_result"
  : >"$MISE_TEST_CALLS"

  output="$(bash "$SCRIPT" --yes)"

  assert_called "doctor --json"
  assert_called "up --yes"
  assert_called "reshim --force"
  assert_called "environment checked"
  printf '%s\n' "$output"
}

output="$(run_success_case false)"
assert_not_called "self-update -y"
grep -Fq '[INFO] mise is managed by the system package manager; skipping self-update' <<<"$output" || {
  echo "FAIL: package-manager ownership was not reported" >&2
  exit 1
}

run_success_case true >/dev/null
assert_called "self-update -y"

for invalid_result in missing invalid malformed failure; do
  export MISE_TEST_DOCTOR_RESULT="$invalid_result"
  : >"$MISE_TEST_CALLS"
  if bash "$SCRIPT" >"$TMP_DIR/stdout" 2>"$TMP_DIR/stderr"; then
    echo "FAIL: invalid doctor result succeeded: $invalid_result" >&2
    exit 1
  fi
  assert_called "doctor --json"
  assert_not_called "self-update -y"
  assert_not_called "up"
  assert_not_called "reshim --force"
done

PATH="$ORIGINAL_PATH"
echo "test-dotfiles-mise-up: OK"
