#!/usr/bin/env bash
# Regression test for the Codex skills symlink synchronization template.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

CHEZMOI_BIN="$(command -v chezmoi)" || {
  echo "test-codex-skills-link: chezmoi is required" >&2
  exit 1
}

FAKE_HOME="$TMP_DIR/home"
RENDERED="$TMP_DIR/codex-skills-link"

mkdir -p \
  "$FAKE_HOME/.claude/skills/my-pr" \
  "$FAKE_HOME/.claude/skills/custom" \
  "$FAKE_HOME/.claude/skills/stale-managed" \
  "$FAKE_HOME/.claude/skills/my-team-share" \
  "$FAKE_HOME/.agents/skills/local-owned" \
  "$FAKE_HOME/.codex/skills/.system"
printf 'name: my-pr\n' >"$FAKE_HOME/.claude/skills/my-pr/SKILL.md"
printf 'local skill\n' >"$FAKE_HOME/.agents/skills/local-owned/SKILL.md"
printf 'stale-managed\n' >"$FAKE_HOME/.agents/skills/.codex-claude-managed-skills"

ln -s "$FAKE_HOME/.claude/skills/custom" \
  "$FAKE_HOME/.agents/skills/custom"
ln -s "$FAKE_HOME/.claude/skills/stale-managed" \
  "$FAKE_HOME/.agents/skills/stale-managed"
ln -s "$FAKE_HOME/.claude/skills/my-pr" \
  "$FAKE_HOME/.codex/skills/my-pr"
ln -s "$FAKE_HOME/.claude/skills/my-team-share" \
  "$FAKE_HOME/.codex/skills/my-team-share"
ln -s "$TMP_DIR/unrelated-target" \
  "$FAKE_HOME/.codex/skills/unrelated"

"$CHEZMOI_BIN" execute-template \
  <"$REPO_ROOT/home/run_onchange_after_codex-skills-link.sh.tmpl" \
  >"$RENDERED"
chmod +x "$RENDERED"

HOME="$FAKE_HOME" "$RENDERED" >"$TMP_DIR/rendered-output" 2>&1

[ -L "$FAKE_HOME/.agents/skills/my-pr" ] ||
  fail "managed Codex skill link was not created"
[ "$(readlink "$FAKE_HOME/.agents/skills/my-pr")" = \
  "$FAKE_HOME/.claude/skills/my-pr" ] ||
  fail "managed Codex skill link points to the wrong path"
[ -d "$FAKE_HOME/.agents/skills/local-owned" ] &&
  [ ! -L "$FAKE_HOME/.agents/skills/local-owned" ] ||
  fail "local-owned skill directory was modified or removed"
[ -f "$FAKE_HOME/.agents/skills/local-owned/SKILL.md" ] ||
  fail "local-owned skill was modified or removed"
[ -L "$FAKE_HOME/.agents/skills/custom" ] ||
  fail "user-owned cross-client skill link was removed"
[ "$(readlink "$FAKE_HOME/.agents/skills/custom")" = \
  "$FAKE_HOME/.claude/skills/custom" ] ||
  fail "user-owned cross-client skill link was changed"
[ ! -e "$FAKE_HOME/.agents/skills/stale-managed" ] &&
  [ ! -L "$FAKE_HOME/.agents/skills/stale-managed" ] ||
  fail "stale managed agent skill link was not pruned"
[ -f "$FAKE_HOME/.agents/skills/.codex-claude-managed-skills" ] ||
  fail "managed skill ownership manifest was not written"
grep -qx 'my-pr' "$FAKE_HOME/.agents/skills/.codex-claude-managed-skills" ||
  fail "managed skill ownership manifest lacks my-pr"
if grep -qx 'stale-managed' "$FAKE_HOME/.agents/skills/.codex-claude-managed-skills"; then
  fail "managed skill ownership manifest retained a stale skill"
fi
[ ! -e "$FAKE_HOME/.codex/skills/my-pr" ] &&
  [ ! -L "$FAKE_HOME/.codex/skills/my-pr" ] ||
  fail "legacy Codex skill link was not pruned"
[ ! -e "$FAKE_HOME/.codex/skills/my-team-share" ] &&
  [ ! -L "$FAKE_HOME/.codex/skills/my-team-share" ] ||
  fail "removed legacy Codex skill link was not pruned"
[ -L "$FAKE_HOME/.codex/skills/unrelated" ] ||
  fail "unrelated Codex skill link was removed"
[ "$(readlink "$FAKE_HOME/.codex/skills/unrelated")" = \
  "$TMP_DIR/unrelated-target" ] ||
  fail "unrelated Codex skill link was changed"
[ -d "$FAKE_HOME/.codex/skills/.system" ] &&
  [ ! -L "$FAKE_HOME/.codex/skills/.system" ] ||
  fail "Codex .system directory was modified or removed"

echo "test-codex-skills-link: OK"
