#!/usr/bin/env bash
# Collect WIP data for the current git branch.
# Outputs sections delimited by "=== SECTION_NAME ===" markers.
# Usage: bash collect.sh

set -euo pipefail

# --- Cleanup expired handoff files ---
mkdir -p .tmp/wip
TODAY=$(date +%Y-%m-%d)
for f in .tmp/wip/*.md; do
  [ -f "$f" ] || continue
  EXPIRES=$(grep -m1 '^expires:' "$f" 2>/dev/null | sed 's/expires: *//' || true)
  if [ -n "$EXPIRES" ] && [[ "$EXPIRES" < "$TODAY" ]]; then
    rm -f "$f"
  fi
done

# --- Branch info ---
echo "=== BRANCH ==="
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
echo "$BRANCH"

# --- Recent commits (up to 20, on this branch only) ---
echo "=== LOG ==="
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git log --oneline --no-merges -20 "${DEFAULT_BRANCH}..HEAD" 2>/dev/null || git log --oneline -10

# --- Staged changes ---
echo "=== STAGED ==="
git diff --cached --stat 2>/dev/null || echo "none"

# --- Unstaged changes ---
echo "=== UNSTAGED ==="
git diff --stat 2>/dev/null || echo "none"

# --- Untracked files ---
echo "=== UNTRACKED ==="
git ls-files --others --exclude-standard 2>/dev/null || echo "none"

# --- Diff summary against default branch ---
echo "=== DIFF_SUMMARY ==="
git diff "${DEFAULT_BRANCH}...HEAD" --stat 2>/dev/null || echo "none"

# --- SDD document (if branch name maps to one) ---
echo "=== SDD ==="
SDD_NAME="${BRANCH#sdd/}"
SDD_NAME="${SDD_NAME#feat/}"
SDD_NAME="${SDD_NAME#feature/}"
SDD_NAME="${SDD_NAME#fix/}"

if [ "$SDD_NAME" != "$BRANCH" ] && [ -f "docs/specs/${SDD_NAME}/requirements.md" ]; then
  echo "--- requirements.md ---"
  cat "docs/specs/${SDD_NAME}/requirements.md"
  if [ -f "docs/specs/${SDD_NAME}/tasks.md" ]; then
    echo ""
    echo "--- tasks.md ---"
    cat "docs/specs/${SDD_NAME}/tasks.md"
  fi
elif [ -f ".sdd/${SDD_NAME}.md" ]; then
  cat ".sdd/${SDD_NAME}.md"
else
  echo "none"
fi

echo "=== END ==="
