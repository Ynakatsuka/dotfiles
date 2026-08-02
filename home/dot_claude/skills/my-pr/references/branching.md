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
bash "$HOME/.claude/skills/my-pr/scripts/move-changes-to-worktree.sh" "feat/example"
```

Preserve the exact `ORIG_REPO`, `WORKTREE_DIR`, and `BRANCH` values printed by the script. Do not expect shell variables from this invocation to exist during cleanup.

For task-created untracked files, pass only an explicit list. Do not include unrelated untracked files.

```bash
TASK_CREATED_UNTRACKED_FILES="path/created-by-this-task.txt" \
  bash "$HOME/.claude/skills/my-pr/scripts/move-changes-to-worktree.sh" "feat/example"
```

If paths contain spaces or many files are involved, write a newline-delimited list and pass it with `MY_PR_UNTRACKED_FILE_LIST`.

```bash
MY_PR_UNTRACKED_FILE_LIST=/path/to/task-created-untracked-files.txt \
  bash "$HOME/.claude/skills/my-pr/scripts/move-changes-to-worktree.sh" "feat/example"
```

If unrelated tracked changes exist, restrict the transfer with `MY_PR_PATHSPEC_FILE`.

```bash
MY_PR_PATHSPEC_FILE=/path/to/task-pathspecs.txt \
  bash "$HOME/.claude/skills/my-pr/scripts/move-changes-to-worktree.sh" "feat/example"
```

For a short pathspec list whose paths contain no whitespace, pass a whitespace-separated list with `MY_PR_PATHS` instead. The value is split on whitespace, so it cannot express paths containing spaces; use `MY_PR_PATHSPEC_FILE` for those. When both are set, `MY_PR_PATHSPEC_FILE` takes precedence and `MY_PR_PATHS` is ignored.

```bash
MY_PR_PATHS="src/feature.py tests/test_feature.py" \
  bash "$HOME/.claude/skills/my-pr/scripts/move-changes-to-worktree.sh" "feat/example"
```

The script transfers changes by binary patches, verifies the worktree diff matches the original staged/unstaged patches, and intentionally does not clean the original repository by itself.
Explicitly listed untracked symlinks are rejected so the script cannot dereference a link to a file outside the repository.

After a successful transfer, the orchestrator must clean the task-owned changes from the original protected branch before continuing. Do this only after reviewing the script output and confirming the worktree contains the intended changes.

Set `STAGED_FILES`, `CHANGED_FILES`, and `TASK_CREATED_UNTRACKED_FILES` to exact task-owned paths only. Do not run cleanup commands with empty, unverified, or unrelated path lists. If ownership is unclear, stop and report before deleting or restoring anything.

```bash
ORIG_REPO="/absolute/original/repository/path"
STAGED_FILES=("path/to/staged-file")
CHANGED_FILES=("path/to/changed-file")
TASK_CREATED_UNTRACKED_FILES=("path/to/task-created-file")

git -C "$ORIG_REPO" reset HEAD -- "${STAGED_FILES[@]}"
git -C "$ORIG_REPO" checkout -- "${CHANGED_FILES[@]}" "${STAGED_FILES[@]}"

# Delete only untracked files that were created during the current task and copied to the worktree.
for f in "${TASK_CREATED_UNTRACKED_FILES[@]}"; do
  rm -f "$ORIG_REPO/$f"
done

git -C "$ORIG_REPO" status --short
```

Do not continue to base branch resolution, review, simplify, commit, push, or PR creation until the original protected branch has no remaining task-owned staged, unstaged, or untracked changes. If unrelated changes remain, leave them untouched and report them. If task-owned changes remain after cleanup, stop and investigate instead of reconstructing changes from memory.

If the move script fails, do not clean or reconstruct changes from memory. Stop and report the exact failure.

Do not include unrelated untracked files in `TASK_CREATED_UNTRACKED_FILES`. If ownership is uncertain, stop and report before deleting.

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
elif grep -Eqi "no upstream|no such branch|upstream" "$ERR_FILE"; then
  echo "No upstream branch is configured yet."
else
  cat "$ERR_FILE"
  exit 1
fi
```

## Base fetch safety

When resolving the PR base branch, fetch only the remote-tracking ref. Do not update a local protected branch ref as a fetch side effect.

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
```

Do not run `git fetch origin "$BASE_BRANCH:$BASE_BRANCH"`. That can advance a checked-out protected branch ref from another worktree without updating its worktree/index, leaving the merged remote changes as staged or unstaged reverse diffs.

## Push destination safety

Before every push, verify the destination branch.

```bash
bash "$HOME/.claude/skills/my-pr/scripts/check-push-destination.sh"
```

If the script reports a protected branch mismatch, stop and ask the user before pushing.
