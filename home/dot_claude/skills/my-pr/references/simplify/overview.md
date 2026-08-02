# Integrated Simplify Workflow

Use this reference from `my-pr` when running the `simplify` subcommand, `create`, or the default/review/fix quality workflow.

## Executor

Use one host-native simplifier role per mode and one self-contained dispatch prompt.

- Review mode uses the read-only `simplifier` role. On Codex, the default, `review`, and `fix` quality stage launches `reviewer` and `simplifier` with `fork_turns: "none"`. Do not override `model` or `reasoning_effort` at spawn time.
- Apply mode uses `simplifier_apply`. On Codex, `create` and `simplify` launch `agent_type: "simplifier_apply"` with `fork_turns: "none"`. Do not override `model` or `reasoning_effort` at spawn time; the role configuration supplies `gpt-5.6-terra` at `medium` effort.
- On Claude Code, use native Agents for review and apply with the same self-contained dispatch prompt. Do not start an external process for simplify.
- If a native role is unavailable or its execution fails, report the failure and stop. Do not substitute another executor or continue with partial simplify evidence.

The dispatch must include the mode, explicit write scope, allowed read-only inputs, applicable language rules, acceptance criteria, and the output contract below. The role must not delegate.

## Modes

| Mode | Behavior |
|---|---|
| `review` | Use the read-only `simplifier` role for analysis of the supplied PR context and full diff or assigned diff chunk. Use read-only tools or bounded shell commands only to read those exact artifact and reference paths. Do not inspect other repository state, write files, or run checks. |
| `apply` | Use `simplifier_apply` to inspect and edit only the explicitly authorized write targets. Identify and apply only Required, behavior-preserving simplifications. Do not apply Recommended items. |

## Performance profile

- The native role configuration controls the model and effort. Do not override either in a dispatch.
- For every full-diff run or chunk, return at most 5 Required and 5 Recommended findings.
- Prioritize high-confidence, behavior-preserving changes with clear maintenance value.
- Apply the line and byte chunking conditions in `references/review.md`. Dispatch each file-boundary chunk with its PR context and assigned diff.
- Avoid repository exploration. In `apply` mode, examine only the dispatch's explicit targets and supplied context.

## Scope and inputs

The orchestrator determines the scope before dispatching. A native subagent must not infer scope from all repository changes or touch unrelated staged, unstaged, or untracked files.

### Review mode

Give the read-only `simplifier` role, in this exact order:

1. The absolute `references/simplify/overview.md` path.
2. The PR context artifact, or an explicit statement that no context exists.
3. The complete review diff artifact or the assigned chunk artifact.
4. The matching language-specific rules from this reference, supplied as absolute paths in the documented order.

Select language-specific rules from `Files covered`, or from changed targets for a full diff, using the mapping below. If no target matches, state `none (no matching language-specific reference)` explicitly. Do not use a current worktree file as a substitute for a supplied artifact or reference.

Use no other repository data. If a required context, diff, or chunk cannot be supplied completely, stop the workflow and report incomplete review evidence; do not inspect the checkout as a substitute.

### Apply mode

Give the subagent two explicit, disjoint path sets:

- `Authorized write targets`: only requested product files and allowed areas that the subagent may edit.
- `Allowed read-only inputs`: the common overview, task context, and applicable language rules, plus any other supplied evidence the subagent may read but must never edit.

The subagent may read both sets. Rules can be read without becoming writable. It may inspect and edit only authorized write targets to decide which Required simplifications exist. It must not change files merely because they appear in the broader PR diff. If either set is missing or ambiguous, return `NEEDS_CONTEXT`. If the sets overlap, or the request requires editing an allowed read-only input, return `BLOCKED`.

The main workflow owns final diff review, project verification, and any commit. The subagent must not commit, push, deploy, apply configuration, or mutate external systems.

## Language-specific references

Supply only the references that match the explicit targets or diff chunk. For review mode, select them from `Files covered`, or from changed targets for a full diff. Pass their absolute paths in this documented order: TypeScript / JavaScript, Python, then Shell / Bash / Zsh.

| Target | Reference |
|---|---|
| TypeScript / JavaScript | `references/simplify/typescript.md` |
| Python | `references/simplify/python.md` |
| Shell / Bash / Zsh | `references/simplify/shell.md` |

If no language-specific reference exists, state `none (no matching language-specific reference)` in the dispatch and use this file's common rules only.

## Classification

Place each candidate in exactly one category. Keep at most 5 Required and 5 Recommended candidates per run or chunk. If more candidates exist, keep the safest, highest-value items and omit style-only or preference-only items.

### Required

Safe, behavior-preserving changes with clear maintenance value.

- duplicated logic that can reuse an existing helper
- unnecessary wrappers, adapters, arguments, state, or configuration
- unreachable code, unused imports, unused variables, or dead branches
- excessive nesting or hard-to-read boolean expressions
- naming that obscures contracts or responsibilities
- comments that duplicate or contradict implementation
- fallbacks, default substitutions, broad catches, or silent retries that hide errors

### Recommended

Valuable but not auto-applied because approval or design judgment is needed.

- public API, schema, CLI, config, persistence, or error semantic changes
- module boundary or responsibility changes
- large test structure changes
- performance-motivated rewrites

### Not needed

Do not apply.

- style preferences
- clever one-liners
- shorter but less readable code
- changes that conflict with project conventions
- defensive defaults, broad catches, mocks, stubs, or retries that hide failures

## Apply rules

The subagent identifies Required candidates within its authorized files, then applies only candidates that satisfy every condition:

1. External behavior is unchanged.
2. Public contracts, schemas, CLI/config contracts, persistence formats, and error semantics are unchanged.
3. Dependencies and module boundaries are unchanged.
4. No fallback, default substitution, broad catch, mock/stub continuation, or silent retry is added.
5. Any new helper or abstraction removes duplication or clarifies responsibility.
6. The before/after change is easy to explain.

Do not make a prohibited change. Mark it Recommended or return `BLOCKED` when the requested result requires a decision outside this scope.

## Dispatch prompt

Use this prompt unchanged apart from the bracketed inputs. Do not add an output format that replaces the role's status contract.

```text
Run the integrated my-pr simplify workflow.

Mode: <review|apply>
Authorized write targets: <apply mode: explicit product paths and allowed areas; review mode: none>
Allowed read-only inputs: <absolute common overview, task context, applicable language-rule paths, and review artifacts; none only when no input exists>
Task and PR context:
<PR_CONTEXT_OR_NO_CONTEXT>

Review input (review mode only; source of truth):
<FULL_DIFF_ARTIFACT_OR_ASSIGNED_CHUNK_ARTIFACT>

Applicable language rules:
<MATCHING_ABSOLUTE_LANGUAGE_REFERENCES_IN_DOCUMENTED_ORDER_OR_NONE>

Acceptance criteria:
- Preserve behavior. Do not change public contracts, schemas, CLI/config contracts, persistence formats, error semantics, dependencies, or module boundaries.
- Do not add fallbacks, default substitutions, broad catches, silent retries, mocks, or stub continuations.
- Do not delegate, commit, push, deploy, apply configuration, or mutate external systems.
- In review mode, remain read-only. Read the supplied `references/simplify/overview.md` path, then the PR context, then the diff or chunk, then each supplied language-reference path in the documented order. Use read-only tools or bounded shell commands only for those exact paths. Do not inspect other repository files or run verification commands.
- In apply mode, treat Authorized write targets and Allowed read-only inputs as explicit, disjoint sets. Read-only inputs, including the common overview, task context, and language rules, may be read without becoming writable. Edit only Authorized write targets. If either set is missing or ambiguous, return NEEDS_CONTEXT. If the sets overlap, or an edit is requested for a read-only input, return BLOCKED. Identify Required candidates yourself, apply only Required behavior-preserving changes, and do not apply Recommended candidates.
- Return at most 5 Required and 5 Recommended findings per full-diff run or chunk.
- Classify each candidate exactly once as Required, Recommended, or Not needed.
- The main workflow will review the diff and run verification. Do not run repository verification commands; state this in CHECKS.

Use the role's exact status envelope. Include the requested details inside EVIDENCE or CHANGES; do not replace STATUS, SUMMARY, CHECKS, or CONCERNS.
```

## Verification

After an apply dispatch completes, the main workflow reviews the produced diff and runs the closest documented verification command. Prefer project docs, package manager scripts, `AGENTS.md`, or CI workflow commands.

If no documented command exists, report the item as unverified. Always run:

```bash
git diff --check
git diff --stat
```

## Output

The role must always use its exact five-section status envelope. `EVIDENCE` is used in review mode and `CHANGES` in apply mode. Detailed headings below are nested content, not substitute top-level sections.

### Review mode

```markdown
STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
SUMMARY:
- concise review result
EVIDENCE:
## Required
1. **file:line** — short title
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Problem: what is duplicated, over-complex, dead, or inefficient
   - Why required: why this behavior-preserving change is needed before merge
   - Ideal state: simpler equivalent structure or invariant
   - Simplification: concrete change
   - Why safe: behavior-preserving reason

## Recommended
1. **file:line** — short title
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Problem: what is suboptimal or uncertain
   - Why approval is needed: trade-off or scope decision
   - Ideal state: simpler structure or clearer ownership
   - Next step: concrete option to approve, defer, or investigate

## Not needed
- finding and reason
CHECKS:
- not run: review mode is read-only; main workflow owns verification
CONCERNS:
- remaining risk or none
```

### Apply mode

```markdown
STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
SUMMARY:
- concise apply result
CHANGES:
## Applied
- **file:line** — Required change and behavior-preservation evidence

## Not applied
- **file:line** — Recommended or out-of-scope item and reason
CHECKS:
- not run: main workflow owns diff review and verification
CONCERNS:
- remaining risk or none
```
