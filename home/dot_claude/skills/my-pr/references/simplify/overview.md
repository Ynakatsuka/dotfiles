# Integrated Simplify Workflow

Use this reference from `my-pr` when running the `simplify` subcommand, `create`, or the default/review/fix quality workflow.

## Executor

Default apply-mode executor is Codex CLI with the simplify performance profile. Do not override the model; only lower reasoning effort for simplify:

```bash
codex exec -c 'model_reasoning_effort="medium"' "<PROMPT>"
```

Use the global Codex default effort only when the user explicitly asks for a full-effort simplify run. Use Claude/local execution only when the user explicitly asks for it.

For `my-pr` review mode, do not invoke Codex directly. Write this reference's review prompt under `MY_PR_ARTIFACT_DIR` and use `scripts/run-codex-review.sh reviewer-a`; the runner embeds context and diff through stdin, applies medium effort, disables nested delegation, and verifies complete-input receipts.

Do not silently switch from Codex to Claude if Codex fails or rejects the config override. Report the failure and stop.

## Modes

| Mode | Behavior |
|---|---|
| `review` | Analyze current PR changes and report findings only. Do not edit or write files. |
| `apply` | Apply only Required behavior-preserving simplifications, then verify. |

## Performance profile

- Use `model_reasoning_effort="medium"` for simplify runs.
- Keep the configured Codex model. Do not pass `--model` unless the user explicitly requests one.
- For each run or chunk, report at most 5 Required and at most 5 Recommended findings.
- Prioritize high-confidence, behavior-preserving simplifications with clear maintenance value.
- For diffs that meet the line or byte chunking conditions in `references/review.md`, run simplify per file-boundary chunk. Otherwise prefer one full-diff simplify run.
- Avoid broad repository exploration. Read nearby docs, ADRs, specs, or tests only when design intent is unclear.

## Scope

Target only files changed in the current conversation or current PR diff. Do not touch unrelated staged, unstaged, or untracked files.

When invoked from `my-pr`, use the repo-local `MY_PR_REVIEW_DIFF` artifact from `prepare-review-artifacts.sh`. Do not use `/tmp` diff files. In review mode, the runner embeds that artifact directly; do not ask Codex to read it with tools. If the artifact cannot be embedded and receipt-validated, stop instead of reviewing current file state as a substitute.

When invoked from `my-pr` in review mode, read the PR context embedded by the runner before the diff. In apply mode, read `MY_PR_CONTEXT` when provided. Use the context to understand the PR's stated problem, intended behavior, explicit constraints, and resolved discussion. Do not propose simplifications that conflict with that intent.

In apply mode, before analysis, inspect:

```bash
git status --short
git diff --stat
git diff --name-only
git diff --cached --stat
git diff --cached --name-only
```

In apply mode, if design intent is unclear, read the nearest README, AGENTS.md, CLAUDE.md, ADR, spec, and tests before proposing or applying a simplification. In review mode, use only the embedded PR context and diff; report missing intent instead of calling tools.

## Language-specific references

Read only the references that match changed files.

| Target | Reference |
|---|---|
| TypeScript / JavaScript | `references/simplify/typescript.md` |
| Python | `references/simplify/python.md` |
| Shell / Bash / Zsh | `references/simplify/shell.md` |

If no language-specific reference exists, use this file's common rules only.


## Classification

Each finding must be placed in exactly one category.

Each run or chunk must return at most 5 Required and at most 5 Recommended findings. If more candidates exist, keep the safest and highest-value findings and omit style or preference-only items.

### Required

Safe, behavior-preserving changes with clear maintenance value.

- duplicated logic that can reuse an existing helper
- unnecessary wrappers, adapters, arguments, state, or configuration
- unreachable code, unused imports, unused variables, dead branches
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

Apply only Required findings that satisfy all conditions:

1. External behavior is unchanged.
2. Public contracts are unchanged.
3. No fallback, default substitution, broad catch, mock/stub continuation, or silent retry is added.
4. Any new helper or abstraction removes duplication or clarifies responsibility.
5. The before/after diff is easy to explain.

Stop and request approval before changing APIs, schemas, CLI/config contracts, persistence formats, error semantics, module boundaries, dependencies, or large file structure.

## Codex prompt template

Use this prompt with the simplify performance profile:

```bash
codex exec -c 'model_reasoning_effort="medium"' "<PROMPT>"
```

```text
Run the integrated my-pr simplify workflow in <review|apply> mode for the current repository changes.

Follow these constraints:
- Preserve behavior. Do not change public APIs, schemas, CLI/config contracts, persistence formats, or error semantics without approval.
- Target only the current conversation changes or current PR diff. Do not touch unrelated files.
- Classify every finding as Required, Recommended, or Not needed. Put each finding in exactly one category.
- Return at most 5 Required and at most 5 Recommended findings per run or chunk. Prioritize high-confidence, behavior-preserving simplifications.
- For each Required and Recommended finding, include Severity (`critical`, `high`, `medium`, or `low`) and Confidence (`high`, `medium`, or `low`), then use 3-5 concise lines that state the problem, why it matters or needs approval, the ideal state, and the concrete change direction.
- In review mode, do not edit or write files anywhere, including .plans, .tmp, or /tmp.
- In review mode, do not call tools, read repository files, delegate, or spawn subagents. Use only the context and diff embedded by the runner.
- In apply mode, apply only Required behavior-preserving simplifications. Do not apply Recommended changes.
- Do not add fallbacks, default substitutions, broad catches, silent retries, mocks, or stub continuations.
- Respect AGENTS.md, CLAUDE.md, ADRs, specs, nearby tests, and project conventions.
- In apply mode, run targeted verification from documented project commands. If no documented command exists, report it as unverified instead of inventing one.
- In review mode, do not run verification commands; report a verification plan or unverified item instead.
- Report changed files, skipped recommendations, and verification results.
- If MY_PR_REVIEW_DIFF is provided and unreadable, return REVIEW_INCOMPLETE and stop.
- In review mode, read the embedded PR context before the embedded diff. In apply mode, read MY_PR_CONTEXT when provided. Preserve the PR's stated intent and discussion constraints.
```

## Verification

After applying changes, run the closest documented verification command. Prefer project docs, package manager scripts, AGENTS.md, or CI workflow commands.

If no documented command exists, do not invent one. Report it as unverified.

Always run:

```bash
git diff --check
git diff --stat
```

## Output

### Review mode

```markdown
# Simplify Review

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
```

### Apply mode

```markdown
# Simplify Result

## Applied
- **file:line** — change and reason

## Not applied
- **file:line** — reason

## Verification
- command and result
- unverified items
```
