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
- Never stage or commit `.tmp/my-pr/` review artifacts.
- Split commits by purpose: one purpose = one commit.
- Use English Conventional Commits messages.
- Inspect `git diff --cached` before every commit.

## Worktree flow for protected branches

If currently on a protected branch, move the target tracked changes to a worktree before committing.

```bash
ORIG_REPO=$(pwd)
BRANCH="feat/example"
${CLAUDE_SKILL_DIR}/scripts/move-changes-to-worktree.sh "$BRANCH"
```

For task-created untracked files, pass only an explicit list. Do not include unrelated untracked files.

```bash
TASK_CREATED_UNTRACKED_FILES="path/created-by-this-task.txt" \
  ${CLAUDE_SKILL_DIR}/scripts/move-changes-to-worktree.sh "$BRANCH"
```

If paths contain spaces or many files are involved, write a newline-delimited list and pass it with `MY_PR_UNTRACKED_FILE_LIST`.

```bash
MY_PR_UNTRACKED_FILE_LIST=/path/to/task-created-untracked-files.txt \
  ${CLAUDE_SKILL_DIR}/scripts/move-changes-to-worktree.sh "$BRANCH"
```

If unrelated tracked changes exist, restrict the transfer with `MY_PR_PATHSPEC_FILE`.

```bash
MY_PR_PATHSPEC_FILE=/path/to/task-pathspecs.txt \
  ${CLAUDE_SKILL_DIR}/scripts/move-changes-to-worktree.sh "$BRANCH"
```

The script transfers changes by binary patches, verifies the worktree diff matches the original staged/unstaged patches, and does not clean the original repository.
Explicitly listed untracked symlinks are rejected so the script cannot dereference a link to a file outside the repository.

Clean the original protected branch only after reviewing the script output and confirming the worktree contains the intended changes.

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

If the move script fails, do not clean or reconstruct changes from memory. Stop and report the exact failure.

Do not include unrelated untracked files in `TASK_CREATED_UNTRACKED_FILES`. If the original repository still has changes after cleanup, stop and investigate before continuing.

## Upstream safety

On non-protected branches, ensure the upstream is not protected.

```bash
ERR_FILE=$(mktemp -t my-pr-upstream.XXXXXX.err)
trap 'rm -f "$ERR_FILE"' EXIT
if UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>"$ERR_FILE"); then
  UPSTREAM_BRANCH="${UPSTREAM#origin/}"
  case "$UPSTREAM_BRANCH" in
    main|master|staging|production|develop|release/*)
      echo "ERROR: upstream branch is protected: $UPSTREAM_BRANCH"
      exit 1
      ;;
  esac
elif rg -qi "no upstream|no such branch|upstream" "$ERR_FILE"; then
  echo "No upstream branch is configured yet."
else
  cat "$ERR_FILE"
  exit 1
fi
```

## Push destination safety

Before every push, verify the destination branch.

```bash
${CLAUDE_SKILL_DIR}/scripts/check-push-destination.sh
```

If the script reports a protected branch mismatch, stop and ask the user before pushing.
