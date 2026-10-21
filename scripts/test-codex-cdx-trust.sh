#!/usr/bin/env bash
# Regression test: cdx trusts its project for one run without writing config.toml.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_ZSH="$REPO_ROOT/home/private_dot_config/zsh/codex.zsh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# Dots, quotes, and a symlinked parent exercise TOML escaping and both path forms.
PROJECT="$TMP_DIR/my.project \"quoted\""
LINK="$TMP_DIR/link"
mkdir -p "$PROJECT/sub" "$TMP_DIR/home"
git -C "$PROJECT" init -q
ln -s "$PROJECT" "$LINK"
CODEX_HOME_DIR="$TMP_DIR/codex-home"
ARGS_FILE="$TMP_DIR/codex.args"
: >"$TMP_DIR/chezmoi.toml"

(
  cd "$LINK/sub"
  HOME="$TMP_DIR/home" CODEX_HOME="$CODEX_HOME_DIR" TEST_CODEX_ZSH="$CODEX_ZSH" TEST_ARGS="$ARGS_FILE" \
    zsh -f -c 'source "$TEST_CODEX_ZSH"; codex() { printf "%s\n" "$@" >"$TEST_ARGS"; }; cdx --user-arg'
)

[ ! -e "$CODEX_HOME_DIR" ] || fail "cdx wrote to CODEX_HOME"

args=()
while IFS= read -r line; do
  args+=("$line")
done <"$ARGS_FILE"
expected_flags=(--dangerously-bypass-approvals-and-sandbox --dangerously-bypass-hook-trust -c)
[ "${#args[@]}" -eq 5 ] || fail "unexpected codex arguments: ${args[*]}"
for index in 0 1 2; do
  [ "${args[$index]}" = "${expected_flags[$index]}" ] || fail "unexpected codex arguments: ${args[*]}"
done
[ "${args[4]}" = "--user-arg" ] || fail "user arguments were not passed last: ${args[*]}"

# Codex parses the -c value as TOML; decode it the same way.
trusted_json="$(printf '%s\n' "${args[3]}" |
  chezmoi --config "$TMP_DIR/chezmoi.toml" execute-template --with-stdin '{{ .chezmoi.stdin | fromToml | toJson }}')" ||
  fail "trust override is not valid TOML: ${args[3]}"
physical_project="$(cd "$PROJECT" && pwd -P)"
jq -e --arg logical "$LINK/sub" --arg physical "$physical_project/sub" --arg root "$physical_project" \
  '.projects == {($logical): {trust_level: "trusted"}, ($physical): {trust_level: "trusted"}, ($root): {trust_level: "trusted"}}' \
  <<<"$trusted_json" >/dev/null || fail "unexpected trusted projects: $trusted_json"

echo "test-codex-cdx-trust: OK"
