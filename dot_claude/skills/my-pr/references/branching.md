# Branching and Push Safety

Use this reference for the Safety gate and push safety phases.

## Protected branches

Protected branch names and patterns:

- `main`
- `master`
- `staging`
- `production`
- `develop`
- `release/*`

Never commit or push directly to a protected branch unless the user explicitly asked and the repository policy allows it.

## Initial state

```bash
CURRENT_BRANCH=$(git branch --show-current)
git status --short
git diff --stat
git diff --cached --stat
```

## Scope isolation

- Target only files changed in the current conversation.
- Do not touch unrelated staged, unstaged, or untracked files.
- Split commits by purpose: one purpose = one commit.
- Use English Conventional Commits messages.
- Inspect `git diff --cached` before every commit.

## Worktree flow for protected branches

If currently on a protected branch, move the target changes to a worktree before committing.

```bash
ORIG_REPO=$(pwd)
BRANCH="feat/example"
SANITIZED_BRANCH="${BRANCH//\//-}"
WORKTREE_DIR="${ORIG_REPO}-worktree/${SANITIZED_BRANCH}"
git worktree add "$WORKTREE_DIR" -b "$BRANCH" HEAD
```

Copy only related files.

```bash
cd "$WORKTREE_DIR"
for f in $CHANGED_FILES $STAGED_FILES $UNTRACKED_FILES; do
  mkdir -p "$(dirname "$f")"
  cp "$ORIG_REPO/$f" "./$f"
done
git diff --stat
```

Clean the original protected branch after copying, but preserve unrelated untracked files.

```bash
git -C "$ORIG_REPO" reset HEAD -- $STAGED_FILES
git -C "$ORIG_REPO" checkout -- $CHANGED_FILES $STAGED_FILES

# Delete only untracked files that were created during the current task and copied to the worktree.
# If ownership is uncertain, leave the file in place and report it instead of deleting it.
for f in $TASK_CREATED_UNTRACKED_FILES; do
  rm -f "$ORIG_REPO/$f"
done

git -C "$ORIG_REPO" status --short
```

Do not include unrelated untracked files in `TASK_CREATED_UNTRACKED_FILES`. If the original repository still has changes, stop and investigate before continuing.

## Upstream safety

On non-protected branches, ensure the upstream is not protected.

```bash
if UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/tmp/my-pr-upstream.err); then
  UPSTREAM_BRANCH="${UPSTREAM#origin/}"
  case "$UPSTREAM_BRANCH" in
    main|master|staging|production|develop|release/*)
      echo "ERROR: upstream branch is protected: $UPSTREAM_BRANCH"
      exit 1
      ;;
  esac
elif rg -qi "no upstream|no such branch|upstream" /tmp/my-pr-upstream.err; then
  echo "No upstream branch is configured yet."
else
  cat /tmp/my-pr-upstream.err
  exit 1
fi
```

## Push destination safety

Before every push, verify the destination branch.

```bash
dot_claude/skills/my-pr/scripts/check-push-destination.sh
```

If the script reports a protected branch mismatch, stop and ask the user before pushing.
