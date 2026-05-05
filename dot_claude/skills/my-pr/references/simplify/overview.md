# Integrated Simplify Workflow

Use this reference from `my-pr` when running the `simplify` subcommand, `create`, or the default/review quality workflow.

## Executor

Default executor is Codex via `/my-agent codex`. Use Claude/local execution only when the user explicitly asks for it.

Do not silently switch from Codex to Claude if Codex fails. Report the failure and stop.

## Modes

| Mode | Behavior |
|---|---|
| `review` | Analyze current PR changes and report findings only. Do not edit files. |
| `apply` | Apply only Required behavior-preserving simplifications, then verify. |

## Scope

Target only files changed in the current conversation or current PR diff. Do not touch unrelated staged, unstaged, or untracked files.

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

Use this prompt with `/my-agent codex`.

```text
Run the integrated my-pr simplify workflow in <review|apply> mode for the current repository changes.

Follow these constraints:
- Preserve behavior. Do not change public APIs, schemas, CLI/config contracts, persistence formats, or error semantics without approval.
- Target only the current conversation changes or current PR diff. Do not touch unrelated files.
- Classify every finding as Required, Recommended, or Not needed. Put each finding in exactly one category.
- In review mode, do not edit files.
- In apply mode, apply only Required behavior-preserving simplifications. Do not apply Recommended changes.
- Do not add fallbacks, default substitutions, broad catches, silent retries, mocks, or stub continuations.
- Respect AGENTS.md, CLAUDE.md, ADRs, specs, nearby tests, and project conventions.
- Run targeted verification from documented project commands. If no documented command exists, report it as unverified instead of inventing one.
- Report changed files, skipped recommendations, and verification results.
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
1. **file:line** — issue
   - Simplification: concrete change
   - Why safe: behavior-preserving reason

## Recommended
1. **file:line** — suggestion
   - Needs approval because: reason

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
