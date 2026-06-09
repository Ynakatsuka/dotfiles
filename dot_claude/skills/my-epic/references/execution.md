# Node Execution

Use this workflow for each approved delivery node. PR leaves produce code changes and draft PRs. Operation nodes execute migration, backfill, initial script, rollout, external console, cleanup, or verification work that is not itself a PR.

## Node type decision

Choose the node type before execution.

| Type | Use when | Output |
|---|---|---|
| PR leaf | Code, tests, docs, config, schema files, or scripts must change and be reviewed | Draft PR |
| Operation | Existing command/script/manual action must be run against an environment | Execution record |
| Verification | Existing state, data, logs, metrics, or dashboards must be checked | Evidence record |
| Decision | Execution depends on a product, rollout, owner, or risk decision | Recorded decision |

## Implementation mode decision

Choose one mode for PR leaves and record it in the leaf execution log.

| Mode | Use when | Notes |
|---|---|---|
| Direct | The leaf is small, file touch map is clear, and the current agent can implement safely | Default |
| Codex-assisted | The leaf is large but bounded, or parallel implementation is useful | Main agent still owns review and gates |
| Explore-only | The implementation path is unclear and codebase research is needed | No edits unless explicitly scoped |

Do not call another local skill as the default path. Keep the workflow self-contained.

## Direct implementation

1. Read the leaf file, `program.md`, and `tree.md`
2. Read target files and nearest relevant tests before editing
3. Search for shared contracts and callers before changing exported behavior
4. Implement only inside the approved file touch map
5. Add or update tests before marking the leaf complete
6. Run Test / Data / Smoke gates
7. Run Spec compliance review, then Code quality review
8. Update the implementation record and execution log

## Operation execution

Use this for approved `operations/{id}-{slug}.md` nodes. Do not treat an operation as a PR unless files must change.

1. Read the operation file, `program.md`, and `tree.md`
2. Confirm all dependency PR leaves and prior operation nodes are complete
3. Show the current account, project, region, tenant, environment, and executor identity when relevant
4. Run dry-run, preview, backup, snapshot, or precondition checks exactly as written
5. Before asking for approval, explain the current situation, confirmed facts, constraints, impact of each option, recommendation, and exact command/action
6. Run only the approved command/action. Do not invent alternate commands, config paths, branches, credentials, endpoints, or manual console steps
7. Capture output, logs, data checks, metrics, dashboards, traces, and other expected evidence
8. If execution fails, stop and report root cause evidence, impact, rollback/abort status, and options
9. Update the execution record and `tree.md` only after required evidence gates pass

Never silently continue after a partial operation. Partial execution must be recorded as blocked or failed with the missing evidence.

## Codex-assisted implementation

If using Codex CLI, pass a self-contained prompt from `leaves/{id}-{slug}.md`.

The prompt must include:

- Repo path and current branch/worktree
- Leaf file path
- Goal and non-goals
- File touch map
- Existing implementation anchors
- Acceptance criteria
- Test / Data / Smoke gates
- No implicit fallback rule
- Required return format

Example command:

```bash
codex exec "<SELF_CONTAINED_PROMPT>"
```

Do not hardcode model names. Let the CLI default decide.

## Prompt skeleton

```text
Implement PR leaf {ID}: {title} in {repo_path}.

Read first:
- docs/epics/{epic}/program.md
- docs/epics/{epic}/tree.md
- docs/epics/{epic}/leaves/{id}-{slug}.md
- {relevant existing files}

File touch map:
- ...

Do not edit outside the approved file touch map unless you stop and report why it is required.

Goal:
- ...

Non-goals:
- ...

Acceptance criteria:
- ...

Verification gates:
- Test:
- Data:
- Smoke:

Rules:
- Do not add fallback behavior, silent retries, broad exception swallowing, mock continuation, or default substitution.
- Do not change public API, schema, CLI/config keys, migration semantics, or documented error behavior beyond this leaf.
- If a required dependency, fixture, environment variable, or external service is missing, stop and report the exact blocker.
- Keep code comments, docstrings, commit messages, and README text in English.

Return:
1. Summary
2. Files changed
3. Tests run
4. Gate results
5. Review gate results
6. Blockers or follow-up
```

## Integration

After PR leaf implementation:

1. Inspect `git diff --stat` and `git diff`
2. Confirm all edits are inside the approved file touch map
3. Run the leaf gates directly
4. Search for related call sites if any public or shared contract was touched
5. Run Spec compliance review before Code quality review
6. Update the implementation record and leaf execution log
7. Update `tree.md` only after all required gates pass

After operation execution:

1. Inspect the operation record and evidence
2. Confirm the executed command/action matches the approved operation node
3. Confirm data / smoke / observability evidence matches expected results
4. Record rollback use or the fact that rollback was not needed
5. Update `tree.md` only after all required evidence gates pass

## Review gates

Run these after implementation and before PR creation. Do not start code quality cleanup until spec compliance passes.

### Spec compliance review

- Built exactly the approved PR goal
- All acceptance criteria are satisfied
- No extra feature or scope creep
- No out-of-scope file changes
- Contract impact matches the approved leaf
- Test / Data / Smoke gates ran or have an explicit blocking reason

### Code quality review

- Existing patterns followed
- Shared contracts and callers checked when touched
- Error semantics preserved
- Tests verify real behavior
- No fallback behavior, silent retry, broad catch, mock continuation, or default substitution added
- Implementation remains reviewable as one PR

## Implementation record

Update the leaf file with:

- Mode: Direct | Codex-assisted | Explore-only
- Summary
- Files changed
- Contracts changed
- Tests run
- Data checks run
- Smoke checks run
- Spec compliance review result
- Code quality review result
- PR URL
- Remaining risks / follow-ups

## PR creation

Create or update a draft PR directly with `gh`.

Preflight:

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git fetch origin "$BASE_BRANCH:$BASE_BRANCH"
git diff "$BASE_BRANCH"..HEAD --stat
git log "$BASE_BRANCH"..HEAD --oneline
```

Existing PR check:

```bash
if gh pr view --json number,title,state 2>/tmp/epic-pr-view.err; then
  echo "Existing PR found."
elif rg -qi "no pull requests|not found" /tmp/epic-pr-view.err; then
  echo "No existing PR for this branch."
else
  cat /tmp/epic-pr-view.err
  exit 1
fi
```

PR body should include:

- Leaf ID and goal
- Tree dependency context
- Test / Data / Smoke gate evidence
- Rollout and rollback notes
- Remaining risks or follow-ups

Use draft PRs until CI, automated reviews, and required gates are green.

## Failure handling

Do not silently retry. One bounded repair loop is allowed only when the cause is clear.

Stop and ask the user when:

- Implementation changes files outside the approved file touch map
- A gate is missing, impossible to run, or depends on unavailable credentials
- Operation execution requires a command/action, environment, account, project, region, tenant, credential, or console step that is not written in the operation node
- Operation execution has partial success, ambiguous output, missing evidence, or unclear rollback status
- A test failure remains after one targeted fix
- The implementation requires fallback behavior
- Implementation requires a new technical decision
- Implementation requires splitting or merging nodes
