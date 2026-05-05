# my-pr Commands

Use this reference after loading `my-pr` to decide the execution path. Each command is intentionally explicit about whether it may edit files, commit, push, create a PR, or mark a PR ready.

## Command summary

| Command | Purpose | May edit | May commit | May push | PR create/update | Ready |
|---|---|---:|---:|---:|---:|---:|
| default | Full PR workflow | yes | yes | yes | yes | yes |
| `create` | Create/update PR without local code review | yes | yes | yes | yes | yes |
| `review` | Run quality review and fix Required findings only | yes | yes | no | no | no |
| `simplify` | Run integrated simplify only | yes | yes | no | no | no |
| `verify` | Verify existing PR checks/reviews and mark ready | yes | yes | yes | no | yes |

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
9. Mark PR ready

Use this when the user asks for PR creation without a subcommand.

## `create`

Create/update a PR while skipping the local Claude/Codex code review stage.

1. Safety gate
2. Base and PR state
3. Integrated simplify apply
4. Commit simplification changes if any
5. Create/update draft PR
6. Verify checks and automated review comments
7. Mark PR ready

`create` still runs simplify. It skips only the local code review stage.

## `review`

Run local quality review and apply Required fixes without PR creation or push.

1. Safety gate
2. Base and PR state
3. Parallel quality review
   - integrated simplify review
   - Claude Code review
   - Codex review via `/my-agent codex`
4. Integrate findings
5. Fix Required findings
6. Commit fixes if any
7. Stop

`review` is not read-only. It may edit files and commit fixes. It must not push or create/update a PR.

## `simplify`

Run only integrated simplify apply.

1. Safety gate
2. Base and PR state
3. Integrated simplify apply
4. Commit simplification changes if any
5. Stop

`simplify` does not run Claude/Codex correctness review. It must not push or create/update a PR.

## `verify`

Operate on an existing PR only.

1. Resolve PR number and head branch
2. Poll checks
3. If checks fail, inspect logs, fix root cause, test, commit, push, and poll again
4. Inspect automated review threads, review bodies, and top-level comments
5. Fix actionable HIGH/critical and valuable MEDIUM/warning findings
6. Commit and push fixes if any
7. Mark PR ready only when checks and actionable review findings are clear

`verify` must not create a PR. It may edit, commit, and push fixes for the existing PR branch.
