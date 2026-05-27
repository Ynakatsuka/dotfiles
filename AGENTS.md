# Global Rules

## Default Behavior

- Respond in Japanese using です・ます form. Avoid casual form.
- Write code comments, docstrings, commit messages, and README text in English.

## Output Style

- Write natural, concise Japanese. Drop fillers and preambles.

## No Implicit Fallbacks

Default to surfacing failures as errors. Do not implement fallback behavior, auto-recovery, default substitution, mock/stub continuation, workaround paths, or silent retries during code changes unless the user explicitly approves that fallback in the current task.

If a fallback seems necessary, stop before editing and propose it. Name the failure mode, exact fallback behavior, trade-off, and what erroring out would look like.

Avoid these patterns unless explicitly approved:

- Substituting `0`, `""`, `[]`, `null`, or another default for missing or invalid data.
- `catch { return null }`, `except: pass`, or broad exception handlers that swallow the cause.
- Continuing with mock, stub, cached, or alternate data when an intended dependency fails.
- Silent retries without bounded attempts, backoff, logging, and a final error.
- Guessing alternate config paths, branches, models, endpoints, parsers, or commands.
- Treating partial results as complete success without surfacing the missing or failed part.

Do not preserve or broaden existing fallback logic when modifying nearby code unless that behavior is intentionally part of the current task. If touched, call it out and either leave it unchanged or ask before changing it.

## Critical Thinking

- Challenge flawed premises before proceeding. Recommend a better approach with one concrete reason.
- Verify important assumptions with current evidence such as code, tests, logs, metrics, dashboards, live queries, recent incidents, or primary docs.
- Before making or reversing a non-obvious decision, read existing ADRs, PRDs, and design docs when available.
- Record important "why" in the closest useful scope: code comment, commit/PR body, ADR, or PRD.
- For shared modules or public interfaces, state what you verified and what you could not verify.
- Before changing exported functions, public types, config keys, schemas, API responses, CLI flags, database migrations, or documented error semantics, search for callers and downstream consumers.
- If a public contract would break, stop and report before editing. Do not silently update call sites to match.

## Solution Scope

Choose the narrowest implementation that solves the real problem without creating avoidable future drag.

- Prefer local fixes for isolated behavior, shared improvements for repeated problems, and new abstractions only when there is a clear contract and real consumer.
- When scope materially affects API shape, data model, ownership, or long-term maintenance and evidence cannot resolve it, ask before editing.

## Root-Cause Discipline

- Diagnose before patching. For bugs, state the root cause in one sentence before applying the production fix.
- Prefer a failing test or minimal repro, then make it pass.
- Fix causes, not symptoms. Do not special-case only the failing input, skip the broken path with a flag, swallow errors at the wrong layer, add defensive defaults that hide contract violations, or weaken tests to match broken behavior.
- If a workaround is genuinely right, label it as a workaround, name the underlying issue, explain the trade-off, and propose or create a tracked follow-up.
- Read the nearest test, type, doc, or caller before touching behavior whose invariant is unclear.
- If root cause cannot be established after bounded investigation, stop and report what was observed, ruled out, likely remaining causes, and the next evidence needed.

## Behavior

- Investigate autonomously before asking: read relevant code, tests, configs, docs, and git history.
- Ask only when desired behavior, design, interface shape, data model, error semantics, scope, or tech choice has multiple reasonable interpretations that evidence cannot resolve.
- For low-stakes reversible choices, pick a sensible default and proceed.
- Before editing, read the target file and the most relevant adjacent file, config, or test.
- Prefer the smallest safe and reversible change.
- Before introducing a helper or abstraction, check whether the same problem is already solved elsewhere.
- Transform tasks into verifiable goals. Report what validation ran, or say explicitly what could not be verified.
- After fixing a bug, search for the same pattern elsewhere and fix related instances when safe.

## Browsing

- When launching a local browser, use headless mode unless the user explicitly requests a visible browser.
- Prefer `agentbrowser` over launching a browser directly when it is available.

## Skills

- When a referenced skill is not found in the host environment's built-in skill list, look under `~/.claude/skills/` before reporting it as missing.
- When creating or editing `dot_claude/skills/*/SKILL.md`, use the skill-authoring workflow first.

## Codex-Specific Addendum

### Autonomy

- Before a long-running tool call or batch, emit one short sentence stating what you are about to do.

### Tool Usage

- Pass an explicit `workdir` parameter when running shell commands.
- Use `rg` / `rg --files` for search when available.
- Use `apply_patch` for manual file edits.

### Git

- Do not revert user changes unless explicitly asked.
- Ignore unrelated dirty worktree changes.
- Do not accidentally push directly to protected branches (`main`, `master`, `staging`, `develop`, `production`, `release/*`). Before an implicit-destination push, resolve `@{push}`; if it points to a protected branch during PR creation or branch-publication work, stop and report.
- Use Conventional Commits format when committing (`feat:`, `fix:`, `refactor:`, etc.).
- Never commit secrets, credentials, or `.env` files. Warn if asked.
- Use `gh` for all GitHub operations (PRs, issues, releases, checks).

### Domain Rules

- Python: use `uv`, modern typing, Ruff, Mypy, and Pytest.
- BigQuery / `.sql`: use `bq`, show the current project/account before execution, and run `--dry_run` before expensive queries.
- GPU Python: check `nvidia-smi` first and set `CUDA_VISIBLE_DEVICES` explicitly.
