# my-pr Commands

Use this reference after loading `my-pr` to decide the execution path. Each command is intentionally explicit about whether it may edit files, commit, push, or create/update a PR.

## Command summary

| Command | Purpose | May edit | May commit | May push | PR create/update |
|---|---|---:|---:|---:|---:|
| default | Full PR workflow | yes | yes | yes | yes |
| `create` | Create/update PR without local correctness review | yes | yes | yes | yes |
| `review` | Collect and integrate review findings only | no | no | no | no |
| `fix` | Fix Required findings, verify, and commit | yes | yes | no | no |
| `simplify` | Run integrated simplify apply only | yes | yes | no | no |
| `verify` | Verify existing PR checks/reviews only | yes | yes | yes | no |

## Migration from previous behavior

- `review` used to fix and commit Required findings. Use `fix` for that behavior.
- default, `create`, and `verify` used to mark draft PRs ready after verification. They now leave the PR as draft; run `gh pr ready <PR_NUMBER>` explicitly when ready-for-review is intended.

## default

Run the full workflow:

1. Safety gate
2. Base and PR state
3. Parallel quality review
   - integrated simplify review
   - Claude Code review
   - Codex review via `/my-agent codex`
4. Integrate findings
5. Fix Required findings
6. Commit fixes
7. Create/update draft PR
8. Verify checks and automated review comments

Use this when the user asks for PR creation without a subcommand.

## `create`

Create/update a PR while skipping the local Claude/Codex correctness review stage.

1. Safety gate
2. Base and PR state
3. Integrated simplify apply
4. Commit simplification changes if any
5. Create/update draft PR
6. Verify checks and automated review comments

`create` still runs simplify. It skips only the local code review stage.

## `review`

Run local quality review in read-only mode.

1. Safety gate
2. Base and PR state
3. Parallel quality review
   - integrated simplify review
   - Claude Code review
   - Codex review via `/my-agent codex`
4. Integrate findings
5. Stop

`review` is read-only. It must not edit files, run fix verification, commit, push, or create/update a PR.

## `fix`

Fix only Required findings, verify, and commit without pushing.

1. Safety gate
2. Base and PR state
3. Parallel quality review in read-only mode
   - integrated simplify review
   - Claude Code review
   - Codex review via `/my-agent codex`
4. Integrate findings
5. Fix Required findings only
6. Run the verification plan for the fixes
7. Commit fixes if any
8. Stop

`fix` must not apply Recommended findings, push, or create/update a PR. If a Required finding needs a public API, schema, CLI, config, persistence, or documented error semantic change, stop and report instead of editing.

## `simplify`

Run only integrated simplify apply. This is a simplification-only command.

1. Safety gate
2. Base and PR state
3. Integrated simplify apply
4. Commit simplification changes if any
5. Stop

`simplify` does not run Claude/Codex correctness review, fix non-simplification findings, push, or create/update a PR.

## `verify`

Operate on an existing PR only.

1. Resolve PR number and head branch
2. Poll checks
3. If checks fail, inspect logs, fix root cause, test, commit, push, and poll again
4. Inspect automated review threads, review bodies, and top-level comments
5. Fix actionable HIGH/critical and valuable MEDIUM/warning findings
6. Commit and push fixes if any

`verify` must not create/update a PR or mark a PR ready. It may edit, commit, and push fixes for the existing PR branch.
