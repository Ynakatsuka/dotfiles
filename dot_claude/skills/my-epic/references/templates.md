# Epic Templates

Use these templates for files under `docs/epics/{epic}/`.

## program.md

```markdown
# {Initiative title}

## Goal contract
- **Problem**:
- **Outcome**:
- **Success metrics**:
- **Primary users**:

## Scope
### In scope
-

### Non-goals
-

## Constraints
- **Technical**:
- **Product**:
- **Operational**:
- **Security / privacy**:

## Existing evidence
- **Docs / ADRs**:
- **Related code**:
- **Related tests**:
- **Related issues / PRs**:

## Decision brief
- **Current understanding**:
- **Confirmed facts**:
- **Why a decision is needed now**:
- **Impact of each option**:
- **Recommendation**:
- **Question to ask**:

## Confirmation plan
| ID | Unknown | Why ask now | Options | Branch plan | Recommendation | Status |
|---|---|---|---|---|---|---|
| Q-001 |  |  | A: / B: / C: | If A: / If B: / If C: |  | open |

## Public contracts at risk
- **API**:
- **Schema / migrations**:
- **CLI / config**:
- **Events / queues**:

## Rollout and rollback
- **Rollout plan**:
- **Rollback plan**:
- **Feature flags**:
- **Cleanup trigger**:

## Open decisions
| ID | Decision | Options | Recommendation | Status |
|---|---|---|---|---|
| D-001 |  |  |  | open |

## Closure summary
<!-- Fill in Phase 6. -->
```

## decisions.md

```markdown
# Decisions

## D-001: {decision title}

- **Status**: proposed | accepted | rejected | superseded
- **Context**:
- **Options considered**:
  1.
  2.
- **Decision**:
- **Why**:
- **Trade-offs**:
- **Rejected alternatives**:
- **Revisit trigger**:
```

## tree.md

````markdown
# Delivery Tree

## Overview
- **Root goal**:
- **Milestones**:
- **Total nodes**:
- **PR leaves**:
- **Operation nodes**:
- **Critical path**:

## Tree

```text
Root Initiative
└── M1: {milestone}
    ├── PR-001: {leaf title}
    ├── OP-001: {operation title}
    └── VERIFY-001: {verification title}
```

## Dependency DAG

| Node | Type | Depends on | Unlocks | Parallel group | Status |
|---|---|---|---|---|---|
| PR-001 | PR leaf | none | OP-001 | P1 | planned |
| OP-001 | Operation | PR-001 | VERIFY-001 | serial | planned |

## Progress matrix

| Node | Type | Approval | Execution | Test gate | Data gate | Smoke / evidence gate | Review gates | PR |
|---|---|---|---|---|---|---|---|---|
| PR-001 | PR leaf | pending | not-started | pending | n/a | pending | pending | not-created |
| OP-001 | Operation | pending | not-started | n/a | pending | pending | n/a | n/a |

## File touch matrix

| Node | CREATE | MODIFY | TEST | DO NOT TOUCH | Parallel-safe with |
|---|---|---|---|---|---|
| PR-001 | `src/new.ts` | `src/index.ts` | `tests/new.test.ts` | `src/legacy.ts` | PR-003 |
| OP-001 | n/a | n/a | n/a | application code | none |

## Operation matrix

| Node | Environment | Owner | Action | Preconditions | Evidence | Rollback / abort |
|---|---|---|---|---|---|---|
| OP-001 | staging |  | Run script | PR-001 merged | log line / data check | abort command |

## Milestones

### M1: {milestone}
- **Goal**:
- **Exit criteria**:
- **Nodes**: PR-001, OP-001, VERIFY-001
- **User approval**: pending | approved
````

## leaves/{id}-{slug}.md

````markdown
# {ID}: {Leaf title}

## Status
- **State**: planned | approved | in-progress | blocked | PR-open | merged | skipped
- **Branch / worktree**:
- **PR**:

## PR goal
- **Outcome**:
- **Why this PR exists**:
- **Out of scope**:

## Dependencies
- **Depends on**:
- **Unlocks**:
- **Parallel safety**:

## File touch map
- **CREATE**:
  - `path/to/new_file`
- **MODIFY**:
  - `path/to/existing_file`
- **TEST**:
  - `path/to/test_file`
- **DOCS**:
  - `path/to/doc_file`
- **DO NOT TOUCH**:
  - `path/to/out_of_scope_file`

## Contract impact
- **Public API**: none | additive | breaking
- **Schema / data**: none | additive | migration | backfill
- **CLI / config**: none | additive | breaking
- **Events / queues**: none | additive | breaking

## Acceptance criteria
- [ ] AC-1:

## Verification gates
### Test gate
- [ ] Command:
- [ ] Expected result:

### Data gate
- [ ] Command / query:
- [ ] Expected result:

### Smoke gate
- [ ] Command / scenario:
- [ ] Expected result:

### Observability gate
- [ ] Logs / metrics / traces:
- [ ] Expected result:

### Rollout / rollback gate
- [ ] Rollout:
- [ ] Rollback:

## Review gates
### Spec compliance review
- [ ] Built exactly the approved PR goal
- [ ] All acceptance criteria are satisfied
- [ ] No extra feature or scope creep
- [ ] No out-of-scope file changes
- [ ] Contract impact matches the approved leaf

### Code quality review
- [ ] Existing patterns followed
- [ ] Shared contracts and callers checked when touched
- [ ] Error semantics preserved
- [ ] Tests verify real behavior
- [ ] No fallback behavior, silent retry, broad catch, mock continuation, or default substitution added

## Implementation prompt
```text
You are implementing PR leaf {ID}: {title}.

Goal:
- ...

Non-goals:
- ...

File touch map:
- ...

Acceptance criteria:
- ...

Verification gates to satisfy:
- ...

Constraints:
- Do not add fallback behavior, silent retries, broad exception swallowing, mock continuation, or default substitution.
- Stop and report if a public contract, schema, CLI/config key, migration semantics, or documented error behavior must change beyond this leaf.
- Keep comments, docstrings, commit messages, and README text in English.

Return:
- Summary
- Files changed
- Tests run and results
- Review gate results
- Any unresolved blockers
```

## Implementation record
- **Mode**: Direct | Codex-assisted | Explore-only
- **Summary**:
- **Files changed**:
- **Contracts changed**:
- **Tests run**:
- **Data checks run**:
- **Smoke checks run**:
- **Spec compliance review**:
- **Code quality review**:
- **PR URL**:
- **Remaining risks / follow-ups**:

## Execution log
| Time | Actor | Action | Result |
|---|---|---|---|
````

## operations/{id}-{slug}.md

````markdown
# {ID}: {Operation title}

## Status
- **State**: planned | approved | in-progress | blocked | complete | skipped
- **Owner / executor**:
- **Environment**:
- **Scheduled time / window**:

## Operation goal
- **Outcome**:
- **Why this operation exists**:
- **Out of scope**:

## Dependencies
- **Depends on**:
- **Unlocks**:
- **Parallel safety**:

## Execution scope
- **Operation type**: migration | backfill | initial script | feature flag | external console | verification | cleanup
- **Target account / project / region / tenant**:
- **Systems touched**:
- **Data / operational impact**:

## Preconditions
- [ ] Required PRs merged:
- [ ] Required credentials / permissions confirmed:
- [ ] Current account / project shown:
- [ ] Dry-run / preview / backup / snapshot completed:
- [ ] User approval recorded:

## Execution steps
### Dry-run / preview
- [ ] Command / action:
- [ ] Expected result:

### Execute
- [ ] Command / action:
- [ ] Expected result:

### Evidence
- [ ] Logs / output:
- [ ] Data checks:
- [ ] Metrics / dashboard / traces:

## Rollback / abort
- **Abort condition**:
- **Rollback command / action**:
- **Irreversible effects**:
- **Escalation owner**:

## Approval gate
- [ ] Current situation explained before asking
- [ ] Facts and constraints shown
- [ ] Impact of running / not running explained
- [ ] Recommendation shown
- [ ] User approved exact command / action

## Execution record
- **Executed by**:
- **Executed at**:
- **Command / action run**:
- **Result**:
- **Evidence links / output**:
- **Rollback used**: yes | no
- **Remaining risks / follow-ups**:

## Execution log
| Time | Actor | Action | Result |
|---|---|---|---|
````
