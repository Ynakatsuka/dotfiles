# Integrated Simplify Workflow

Use this reference from `my-pr` when running the `simplify` subcommand, `create`, or the default/review/fix quality workflow.

## Executor

Default executor is Codex CLI with the simplify performance profile. Do not override the model; only lower reasoning effort for simplify:

```bash
codex exec -c 'model_reasoning_effort="medium"' "<PROMPT>"
```

Use the global Codex default effort only when the user explicitly asks for a full-effort simplify run. Use Claude/local execution only when the user explicitly asks for it.

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
- For very large diffs that meet the chunking conditions in `references/review.md`, run simplify per chunk. Otherwise prefer one full-diff simplify run.
- Avoid broad repository exploration. Read nearby docs, ADRs, specs, or tests only when design intent is unclear.

## Scope

Target only files changed in the current conversation or current PR diff. Do not touch unrelated staged, unstaged, or untracked files.

When invoked from `my-pr`, use the repo-local `MY_PR_REVIEW_DIFF` artifact from `prepare-review-artifacts.sh`. Do not use `/tmp` diff files. If the artifact cannot be read, stop and report the failure instead of reviewing current file state as a substitute.

Before analysis, inspect:

```bash
git status --short
git diff --stat
git diff --name-only
git diff --cached --stat
git diff --cached --name-only
```

If design intent is unclear, read the nearest README, AGENTS.md, CLAUDE.md, ADR, spec, and tests before proposing or applying a simplification.

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
- For each Required and Recommended finding, use 3-5 concise lines that state the problem, why it matters or needs approval, the ideal state, and the concrete change direction.
- In review mode, do not edit or write files anywhere, including .plans, .tmp, or /tmp.
- In apply mode, apply only Required behavior-preserving simplifications. Do not apply Recommended changes.
- Do not add fallbacks, default substitutions, broad catches, silent retries, mocks, or stub continuations.
- Respect AGENTS.md, CLAUDE.md, ADRs, specs, nearby tests, and project conventions.
- Run targeted verification from documented project commands. If no documented command exists, report it as unverified instead of inventing one.
- Report changed files, skipped recommendations, and verification results.
- If MY_PR_REVIEW_DIFF is provided and unreadable, return REVIEW_INCOMPLETE and stop.
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
   - Problem: what is duplicated, over-complex, dead, or inefficient
   - Why required: why this behavior-preserving change is needed before merge
   - Ideal state: simpler equivalent structure or invariant
   - Simplification: concrete change
   - Why safe: behavior-preserving reason

## Recommended
1. **file:line** — short title
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
