#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
skill_root=${1:-"$repo_root/home/dot_claude/skills/my-skill-creator"}
init_script="$skill_root/scripts/init_skill.py"
validate_script="$skill_root/scripts/quick_validate.py"
tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/my-skill-creator-test.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT

expect_failure() {
  local label=$1
  shift
  if "$@" >"$tmp_dir/$label.stdout" 2>"$tmp_dir/$label.stderr"; then
    echo "FAIL: expected failure: $label" >&2
    exit 1
  fi
}

"$init_script" portable-skill --path "$tmp_dir" \
  --resources scripts,references --examples
"$validate_script" "$tmp_dir/portable-skill" --profile standard
uv run "$validate_script" "$tmp_dir/portable-skill" --profile portable

uv run "$init_script" manual-skill --path "$tmp_dir" --manual-only
uv run "$validate_script" "$tmp_dir/manual-skill" --profile portable
grep -Fqx 'disable-model-invocation: true' "$tmp_dir/manual-skill/SKILL.md"
grep -Fqx '  allow_implicit_invocation: false' \
  "$tmp_dir/manual-skill/agents/openai.yaml"

mkdir "$tmp_dir/claude-skill"
cat >"$tmp_dir/claude-skill/SKILL.md" <<'EOF'
---
name: claude-skill
description: Test Claude Code extension validation.
argument-hint: "[path]"
---

# Claude skill
EOF
expect_failure portable-rejects-claude-extension \
  uv run "$validate_script" "$tmp_dir/claude-skill" --profile portable
uv run "$validate_script" "$tmp_dir/claude-skill" --profile claude

mkdir "$tmp_dir/missing-codex-policy"
cat >"$tmp_dir/missing-codex-policy/SKILL.md" <<'EOF'
---
name: missing-codex-policy
description: Test manual-only policy validation.
disable-model-invocation: true
---

# Missing Codex policy
EOF
expect_failure manual-policy-parity \
  uv run "$validate_script" "$tmp_dir/missing-codex-policy" --profile portable

expect_failure invalid-name \
  uv run "$init_script" "Invalid Skill" --path "$tmp_dir"
test ! -e "$tmp_dir/invalid-skill"

echo "test-my-skill-creator: OK"
