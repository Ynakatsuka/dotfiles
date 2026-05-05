# PR Verify and Ready

Use this reference for the default, `create`, and `verify` command verification phase.

## Scope

`verify` operates on an existing PR. It may edit, commit, and push fixes for that PR branch. It must not create a new PR.

## PR identity

```bash
PR_NUMBER=$(gh pr view --json number -q .number)
HEAD_BRANCH=$(gh pr view --json headRefName -q .headRefName)
```

## Completion conditions

All conditions must be true before marking ready:

1. If GitHub checks exist, all target PR checks are `pass` or `skipping`.
2. No check is `fail`, `cancel`, or timed out.
3. Automated review comments have no actionable findings left.
4. Fixes are committed and pushed to the remote PR branch.
5. `gh pr ready "$PR_NUMBER"` succeeds.

## Checks polling

Use the polling script instead of `gh pr checks --watch`.

```bash
dot_claude/skills/my-pr/scripts/poll-pr-checks.sh "$PR_NUMBER"
```

If the script reports failed checks, inspect logs, fix root cause, test, commit, run push destination safety, push, then poll again.

```bash
gh pr checks "$PR_NUMBER"
gh run list --branch "$HEAD_BRANCH" --limit 10
gh run view <RUN_ID> --log-failed
```

## Automated review data

Fetch review bodies, top-level comments, and review threads.

```bash
dot_claude/skills/my-pr/scripts/fetch-review-threads.sh "$PR_NUMBER"
```

Classify findings:

| Finding | Action |
|---|---|
| HIGH / critical / 🔴 | Fix |
| MEDIUM / warning / 🟡 | Fix when it improves correctness, maintainability, or operational stability |
| LOW / nit / style | Do not fix |
| Preference | Do not fix |

If actionable findings exist, fix them, test, commit, run push destination safety, push, and return to checks polling.

## Push destination safety

Before every push, verify that the push destination is safe and that the current branch matches the PR head branch.

```bash
CURRENT_BRANCH=$(git branch --show-current)
test "$CURRENT_BRANCH" = "$HEAD_BRANCH"
dot_claude/skills/my-pr/scripts/check-push-destination.sh
```

If no push destination is configured, push only to the matching remote branch after the current branch check succeeds.

```bash
git push -u origin HEAD:"$CURRENT_BRANCH"
```

If the push destination is a protected branch mismatch, stop and ask the user before pushing.

## Ready

Only after checks and actionable review findings are clear:

```bash
gh pr ready "$PR_NUMBER"
gh pr view "$PR_NUMBER" --json isDraft,reviewDecision,mergeStateStatus,statusCheckRollup
```

Confirm `isDraft=false` before reporting completion.
