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
  "$FAKE_HOME/.agents/skills/local-owned"
printf 'name: my-pr\n' >"$FAKE_HOME/.claude/skills/my-pr/SKILL.md"
printf 'local skill\n' >"$FAKE_HOME/.agents/skills/local-owned/SKILL.md"
printf 'stale-managed\n' >"$FAKE_HOME/.agents/skills/.codex-claude-managed-skills"

ln -s "$FAKE_HOME/.claude/skills/custom" \
  "$FAKE_HOME/.agents/skills/custom"
ln -s "$FAKE_HOME/.claude/skills/stale-managed" \
  "$FAKE_HOME/.agents/skills/stale-managed"

"$CHEZMOI_BIN" -S "$REPO_ROOT/home" execute-template \
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

# OS-specific skills are ignored in .chezmoiignore and filtered again in the
# template; the linked list must match the skills deployed on this OS.
deployed_skills="$("$CHEZMOI_BIN" -S "$REPO_ROOT/home" managed --include=dirs --exclude=remove |
  sed -n 's|^\.claude/skills/\([^/]*\)$|\1|p' | sort)"
linked_skills="$(sed -n '/^skills=(/,/^)/s/^  "\(.*\)"$/\1/p' "$RENDERED" | sort)"
[ -n "$linked_skills" ] && [ "$linked_skills" = "$deployed_skills" ] ||
  fail "linked skills differ from deployed skills: linked=[${linked_skills//$'\n'/ }] deployed=[${deployed_skills//$'\n'/ }]"

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

echo "test-codex-skills-link: OK"
