#!/usr/bin/env bash
# Regression tests for the Codex configuration template and its trust-state preservation.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$REPO_ROOT/home/dot_codex/private_config.toml.tmpl"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

JQ_BIN="$(command -v jq)" || {
  echo "test-codex-config: jq is required" >&2
  exit 1
}
CHEZMOI_BIN="$(command -v chezmoi)" || {
  echo "test-codex-config: chezmoi is required" >&2
  exit 1
}
FIXTURE_HOME="$TMP_DIR/home"
GHQ_REPO="$FIXTURE_HOME/ghq-repo"
EXTERNAL_PROJECT="$TMP_DIR/external project"
SUBDIRECTORY="$GHQ_REPO/subdirectory"
CONFIG_PATH="$FIXTURE_HOME/.codex/config.toml"
CHEZMOI_CONFIG="$TMP_DIR/chezmoi.toml"

mkdir -p "$TMP_DIR/bin" "$FIXTURE_HOME/.codex" "$SUBDIRECTORY" "$EXTERNAL_PROJECT"
: >"$CHEZMOI_CONFIG"
cat >"$TMP_DIR/bin/ghq" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[ "\$#" -eq 2 ] && [ "\$1" = "list" ] && [ "\$2" = "-p" ] || exit 64
printf '%s\n' $(printf '%q' "$GHQ_REPO")
EOF
chmod +x "$TMP_DIR/bin/ghq"

export PATH="$TMP_DIR/bin:$PATH"
OVERRIDE_DATA="$("$JQ_BIN" -cn --arg home_dir "$FIXTURE_HOME" \
  '{chezmoi: {homeDir: $home_dir}}')"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

render_config() {
  "$CHEZMOI_BIN" --config "$CHEZMOI_CONFIG" --source "$REPO_ROOT" \
    execute-template --override-data "$OVERRIDE_DATA" <"$TEMPLATE"
}

parse_toml() {
  "$CHEZMOI_BIN" --config "$CHEZMOI_CONFIG" --source "$REPO_ROOT" \
    execute-template --override-data "$OVERRIDE_DATA" --with-stdin \
    '{{ .chezmoi.stdin | fromToml | toJson }}' <"$1"
}

assert_jq() {
  local label="$1" filter="$2" document="$3"
  "$JQ_BIN" -e "$filter" <<<"$document" >/dev/null 2>&1 || fail "$label"
}

assert_project_trust() {
  local label="$1" project="$2" expected="$3" document="$4"
  "$JQ_BIN" -e --arg project "$project" --arg expected "$expected" \
    '.projects[$project].trust_level == $expected' <<<"$document" >/dev/null 2>&1 ||
    fail "$label"
}

# A missing deployed file still renders valid TOML with the fixed defaults.
render_config >"$TMP_DIR/missing.toml"
missing_json="$(parse_toml "$TMP_DIR/missing.toml")"
assert_jq "missing config defaults" \
  '.model == "gpt-5.6-sol" and .model_reasoning_effort == "xhigh" and .web_search == "live"' \
  "$missing_json"
assert_project_trust "missing config home trust" "$FIXTURE_HOME" trusted "$missing_json"
assert_project_trust "missing config ghq repo trust" "$GHQ_REPO" trusted "$missing_json"

# A desktop preference is preserved even when no projects table exists.
printf '%s\n' '[desktop]' 'realtimeVoiceScreenContextEnabled = false' >"$CONFIG_PATH"
render_config >"$TMP_DIR/desktop.toml"
desktop_json="$(parse_toml "$TMP_DIR/desktop.toml")"
assert_jq "desktop preference=false was not preserved" '.desktop.realtimeVoiceScreenContextEnabled == false' "$desktop_json"

cat >"$CONFIG_PATH" <<EOF
[desktop]
realtimeVoiceScreenContextEnabled = false

[hooks.state]
[hooks.state."fixture-hook"]
trusted_hash = "sha256:fixture"

[projects."$FIXTURE_HOME"]
trust_level = "untrusted"

[projects."$GHQ_REPO"]
trust_level = "untrusted"

[projects."$EXTERNAL_PROJECT"]
trust_level = "untrusted"

[projects."$SUBDIRECTORY"]
trust_level = "untrusted"
EOF

# Parse the complete render so duplicate table emission cannot go unnoticed.
render_config >"$TMP_DIR/full.toml"
full_json="$(parse_toml "$TMP_DIR/full.toml")"
assert_jq "desktop preference=false was not preserved with hook state" '.desktop.realtimeVoiceScreenContextEnabled == false' "$full_json"
assert_jq "hook hash was not preserved" '.hooks.state["fixture-hook"].trusted_hash == "sha256:fixture"' "$full_json"
assert_project_trust "managed home trust changed" "$FIXTURE_HOME" trusted "$full_json"
assert_project_trust "managed ghq repo trust changed" "$GHQ_REPO" trusted "$full_json"
assert_project_trust "external project trust was lost" "$EXTERNAL_PROJECT" untrusted "$full_json"
assert_project_trust "ghq subdirectory trust was lost" "$SUBDIRECTORY" untrusted "$full_json"

# The rendered file is a fixed point when it is deployed and rendered again.
cp "$TMP_DIR/full.toml" "$CONFIG_PATH"
render_config >"$TMP_DIR/full-second.toml"
cmp -s "$TMP_DIR/full.toml" "$TMP_DIR/full-second.toml" ||
  fail "config template is not byte-identical on the second render"

printf '%s\n' 'desktop = [' >"$CONFIG_PATH"
if render_config >"$TMP_DIR/malformed.toml" 2>"$TMP_DIR/malformed.err"; then
  fail "malformed deployed TOML was silently accepted"
fi
grep -q 'fromToml' "$TMP_DIR/malformed.err" || fail "malformed config failed for a reason other than TOML parsing"

echo "test-codex-config: OK"
