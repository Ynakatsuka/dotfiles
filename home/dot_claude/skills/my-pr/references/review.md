# my-pr Native Review

Use this reference for the default, `review`, and `fix` command quality-review stage.

This stage collects and integrates findings only. Do not edit product files, write reviewer notes, run fix verification, commit, push, create or update a PR, or mark a PR ready. Only the main orchestrator creates `.tmp/my-pr/` artifacts and state files. Native review roles return their results to the main orchestrator and never write repository product files or review artifacts.

## Principles

- Review the full PR diff against the base branch, not only later simplification changes.
- Keep the roles separate: `reviewer` examines approach fit, correctness, safety, compatibility, and test risk; `simplifier` examines behavior-preserving simplifications.
- Surface plausible findings with severity and confidence. Integration, not an agent, classifies them as Required, Recommended, or Not needed.
- Require a location, problem, impact, evidence, concrete fix or decision, and focused verification for every actionable finding.
- Check downstream and cross-client effects whenever the repository has multiple clients, SDKs, entrypoints, or pipelines.
- Verify findings before making later fixes. Run focused tests after fixes.
- Do not continue with degraded evidence. Missing artifacts, missing role results, unfinished status, or a native-agent failure makes the review incomplete.

## Artifact and scope gate

Use repository-local artifacts. Do not pass `/tmp` diffs to review roles.

### `my-pr review`

For `my-pr review`, resolve and verify an existing remote-tracking base ref without `git fetch`. Never mutate refs. Stop if the existing base ref cannot be verified.

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
bash "$HOME/.claude/skills/my-pr/scripts/prepare-review-artifacts.sh" "$BASE_REF"
```

### `default` and `fix`

For the default and `fix` workflows, retain the safe remote-tracking fetch before artifact preparation because they may later commit changes.

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
bash "$HOME/.claude/skills/my-pr/scripts/prepare-review-artifacts.sh" "$BASE_REF"
```

The script prints one absolute `artifact.env` path. Preserve that exact path as orchestration state. Replace `/absolute/path/to/artifact.env` below with it. Never infer a current artifact from `latest-env.sh` or an inherited shell environment.

Read `MY_PR_SCOPE_SUMMARY` before launching roles. Stop if `MY_PR_SCOPE_GATE` is not `ok`.

For `my-pr review`:

- `large`: continue only when the user already confirmed that the whole current branch and diff are the target PR scope.
- `untracked` or `large+untracked`: stop and report the files without staging, `git add -N`, ignore or exclude changes, or file removal.

For the default and `fix` workflows:

- `large`: continue only when the user already confirmed that the whole current branch and diff are the target PR scope.
- `untracked`: classify the files. Stage or `git add -N` task-created files that belong in the PR, or confirm that they are out of scope, then regenerate artifacts.
- `large+untracked`: resolve both conditions before continuing.

The state file persists these generated paths. Source this exact file only in shell calls that need to inspect the values:

```text
MY_PR_ARTIFACT_DIR=<repo-local artifact dir>
MY_PR_ARTIFACT_ENV=<artifact dir>/artifact.env
MY_PR_REVIEW_DIFF=<artifact dir>/review.diff
MY_PR_REVIEW_BYTES=<review diff bytes>
MY_PR_CHANGED_FILES=<artifact dir>/changed-files.txt
MY_PR_SCOPE_SUMMARY=<artifact dir>/scope-summary.txt
```

Never stage or commit `.tmp/my-pr/`.

## PR context

After preparing artifacts, capture PR context:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/prepare-pr-context.sh" "/absolute/path/to/artifact.env"
source "/absolute/path/to/artifact.env"
cat "$MY_PR_CONTEXT"
```

The generated values are:

```text
MY_PR_CONTEXT=<artifact dir>/pr-context.md
MY_PR_CONTEXT_STATE=found|no_existing_pr
MY_PR_METADATA=<artifact dir>/pr-metadata.json
MY_PR_ISSUE_COMMENTS=<artifact dir>/pr-issue-comments.json
MY_PR_REVIEWS=<artifact dir>/pr-reviews.json
MY_PR_REVIEW_COMMENTS=<artifact dir>/pr-review-comments.json
```

When `MY_PR_CONTEXT_STATE=found`, each role reads `MY_PR_CONTEXT` before its diff. It must identify the PR problem, intended behavior, explicit constraints, and decisions in prior discussion. It must report a remaining mismatch with those decisions, but not re-raise a resolved discussion item that the diff follows.

When the state is `no_existing_pr`, each role states that PR context is unavailable, infers intent only from its supplied inputs, and records uncertainty in the affected finding.

## Large-diff chunking

Use the full `MY_PR_REVIEW_DIFF` unless either condition is true:

- review-diff lines exceed 10,000
- review-diff bytes exceed 196,608

When either condition is true, generate file-boundary chunks:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/split-review-chunks.sh" "/absolute/path/to/artifact.env"
```

The script groups files by top-level area, keeps chunks at or below 196,608 bytes, verifies reviewable-file coverage, and persists the manifest and skipped-file paths in the explicit artifact state. Treat its `review.diff` for a chunk as the complete assigned diff. Do not split inside a file.

Every dispatch for a chunk includes its chunk id and total count, absolute chunk-diff path, `Files covered`, and `Files not covered`. A role reviews only the covered files and never claims coverage of another chunk.

The script reserves 8,192 bytes for metadata. If one complete file diff exceeds the remaining payload limit, it appears in `MY_PR_SKIPPED_FILES` and `MY_PR_SKIPPED_FILE_SUMMARY`. List that file and byte count in the final result as not reviewed. If every changed file is skipped, do not launch empty roles; return `COMPLETE_WITH_SKIPS`, list all skipped files, and state that no file content was reviewed.

For chunked runs, every role must return a valid result for every non-empty chunk. The main orchestrator may process chunks as pairs in waves when the host maximum-thread limit would be exceeded. Start the `reviewer` and `simplifier` pair concurrently within each wave, and wait for every role in the wave before starting the next one. Do not integrate until all role results for all chunks have arrived.

## Native role launch

Use only host-native subagents. Do not invoke external command-line executors or change to another executor when native subagents are unavailable. Return `REVIEW_INCOMPLETE` instead.

For a non-chunked diff, launch `reviewer` and `simplifier` concurrently in review mode.

- In Codex, spawn one `agent_type: reviewer` and one `agent_type: simplifier`, each with `fork_turns: "none"`. Do not set a model or reasoning-effort override.
- In Claude Code, launch two native `Agent` subagents, one for each role, concurrently.

The main orchestrator is responsible for artifact preparation, dispatch, waiting, and integration. It does not edit the diff after preparation until both roles and all chunks finish. Review roles do not edit files, create notes, run verification, commit, push, change PR state, or launch further agents.

If any role cannot be launched, fails, returns no final result, reports incomplete inputs, or has any status other than `DONE` or `DONE_WITH_CONCERNS`, stop without partial integration and return `REVIEW_INCOMPLETE`. `NEEDS_CONTEXT` and `BLOCKED` are incomplete statuses, not a request to substitute another role.

If a host runs native roles in the background, do not send a final response while any role is running. If waiting must continue outside the current response, the main orchestrator records the role names, artifact paths, current status, and next step in the current artifact state, then uses the available background monitor.

## Dispatch contract

Build every dispatch from the current explicit artifact state. It must be self-contained and include all of the following:

- Task: the role-specific review objective.
- Base: branch name and base ref.
- PR context: absolute `MY_PR_CONTEXT` path and its state.
- Diff: absolute `MY_PR_REVIEW_DIFF` path, or an absolute chunk `review.diff` path.
- Chunk: `full (1/1)`, or chunk id and total count.
- Coverage: literal `Files covered` and `Files not covered` lists.
- Mode: `review`, for the `simplifier` role only.
- Simplifier reference: the absolute path to `references/simplify/overview.md`, for the `simplifier` role only.
- Language-specific references: for the `simplifier` role, select matching rules from `Files covered`, or changed targets for a full diff, using the mapping in `references/simplify/overview.md`. Provide the selected absolute paths in the documented order: TypeScript / JavaScript, Python, then Shell / Bash / Zsh. If none match, state `none (no matching language-specific reference)` explicitly.
- Read-only boundary: the supplied PR context and diff define intent, change scope, and changed lines. The current worktree is never an alternative source for the diff.
- Reviewer reads: after reading the artifacts, the `reviewer` may use read-only tools or bounded shell commands to inspect relevant unchanged callers, contracts, schemas, documentation, and tests needed to verify downstream or cross-client impact.
- Simplifier reads: the `simplifier` may read only the exact supplied simplifier overview, PR-context, diff or chunk, and language-reference paths. It reads them in this order: overview, PR context, diff or chunk, then each supplied language reference in the documented order.
- Prohibited operations: no edits or writes anywhere, notes, test execution, formatters, generators, migrations, commits, pushes, PR changes, network actions, or delegation. The `reviewer` must not broaden repository inspection beyond evidence needed for the assigned changed files.
- Output contract: the exact common structure below plus the role-specific content.

Do not replace an unreadable or incomplete artifact with a review of current files. Return `NEEDS_CONTEXT` and explain the missing input. Do not ask the review role to create output files; its final response is the only result consumed by integration.

All native-role responses use this common structure. The content under `EVIDENCE` follows the role contract below.

```markdown
STATUS: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

SUMMARY:
- scope reviewed and short conclusion

EVIDENCE:
- role-specific findings or categories

CHECKS:
- exact supplied inputs read; no verification commands were run

CONCERNS:
- uncertainty, missing context, or `- none`
```

### Reviewer dispatch

Use this task text after filling the dispatch contract values:

```text
Act as the read-only correctness reviewer for the supplied PR artifact.

Read the absolute PR-context artifact before the absolute diff artifact. Review the full supplied diff or only the supplied Files covered against the stated base. Files not covered are outside this assignment. The diff artifact is the source of truth for changes; never use current worktree state as a substitute. After reading it, you may inspect relevant unchanged callers, contracts, schemas, documentation, and tests with read-only tools when needed to prove downstream or cross-client impact. Do not report unrelated pre-existing issues.

Assess approach fit, correctness, fallback behavior, downstream impact, cross-client compatibility, security, public contracts, data integrity, operations, performance, and tests. For approach fit, check whether the diff solves the stated PR problem under its constraints and whether concrete evidence supports a simpler, safer, or existing path. Do not report style, naming, formatting, duplication, readability-only, generated-file, lockfile, vendor, snapshot, or preference-only findings unless the diff creates a concrete correctness or security risk.

Under EVIDENCE, report every plausible finding. For each one include:
- Location: `file:line`
- Category: approach | correctness | fallback | downstream | cross-client | security | contract | data | operations | performance | tests
- Severity: critical | high | medium | low
- Confidence: high | medium | low
- Problem / impact
- Evidence
- Suggested fix
- Verification

Do not filter findings by merge priority; integration classifies them later. If no findings exist, write `- none`. Follow the common STATUS/SUMMARY/EVIDENCE/CHECKS/CONCERNS structure exactly.
```

### Simplifier dispatch

Use this task text after filling the dispatch contract values:

```text
Mode: review

Act as the read-only simplifier for the supplied PR artifact. Read the supplied inputs in this exact order: the absolute path for `references/simplify/overview.md`, the absolute PR-context artifact, the absolute diff artifact, then each supplied language-reference path in the documented order. If the language-reference input states `none (no matching language-specific reference)`, do not read an unsupplied language file.

Review the full supplied diff or only the supplied Files covered. Files not covered are outside this assignment. Preserve the PR's stated purpose, constraints, public contracts, persistence formats, configuration behavior, and error semantics. The diff artifact is the source of truth; never use current worktree state as a substitute.

Under EVIDENCE, use exactly these categories: Required, Recommended, and Not needed. Include at most five findings in each category. Every Required and Recommended finding includes `file:line`, severity, confidence, problem, why it matters or needs approval, ideal state, concrete simplification or next step, and why it is safe or what decision is needed. Required findings must be behavior-preserving. Do not propose fallbacks, default substitutions, broad catches, silent retries, mocks, or stub continuations.

If no findings exist in a category, write `- none`. Follow the common STATUS/SUMMARY/EVIDENCE/CHECKS/CONCERNS structure exactly.
```

## Integration rules

Wait for all launched results before integration. A complete review requires every expected `reviewer` and `simplifier` result for every full diff or non-empty chunk to have status `DONE` or `DONE_WITH_CONCERNS`. Any missing result, failure, `NEEDS_CONTEXT`, or `BLOCKED` produces `REVIEW_INCOMPLETE`; do not integrate the successful subset.

Deduplicate all findings. Put each one in exactly one category and keep the strongest evidence, most precise location, and focused verification. Preserve a finding's severity. If no role supplied one, infer it from impact and evidence and label it `Severity source: integration-inferred`.

| Final category | Criteria |
|---|---|
| Required | Confirmed approach mismatch that leaves the stated problem unsolved or violates explicit constraints; confirmed correctness, security, data-loss, fallback, downstream, cross-client, contract, data, operations, or performance issue; test gap that can hide a changed-behavior bug; behavior-preserving simplifier Required |
| Recommended | Plausible but uncertain approach issue; simpler or safer alternative needing design approval; design, API, config, persistence, or operational decision; useful test expansion needing approval; simplifier Recommended |
| Not needed | Style preference, readability-only nit without clear risk, false positive, or issue outside this PR's scope |

This stage classifies findings only. Required fixes are applied later by the default or `fix` workflow. Recommended and Not needed findings are not applied here.

Set each integrated finding's signal to one of `reviewer`, `simplify`, or `multiple`.

## Integration output

For `my-pr review`, create the final response as the review comment. Group findings by action, Required before Recommended, and sort each group by severity: critical, high, medium, low.

Read the reviewed PR URL from `.url` in `MY_PR_METADATA`; never reconstruct or guess it. If `MY_PR_CONTEXT_STATE=no_existing_pr`, use `Review URL: unavailable (no existing PR)`.

Separate coverage from the code decision:

- Review status: `COMPLETE`, `COMPLETE_WITH_SKIPS`, or `REVIEW_INCOMPLETE`
- Code assessment: `CHANGES_REQUIRED` when Required findings exist; `NEEDS_DECISION` when no Required findings exist but Recommended findings exist; otherwise `NO_ACTION`

Use stable IDs in output order: `R1`, `R2`, ... for Required and `A1`, `A2`, ... for Recommended. Do not include confidence in integrated findings.

If review is incomplete, output only:

```markdown
Review URL: <PR URL or unavailable (no existing PR)>

# Review result

## Decision
- Review status: REVIEW_INCOMPLETE
- Code assessment: unavailable

## Missing or failed inputs
- <role/chunk/artifact>: <exact failure>

## Next step
- Stop before fixes, commits, pushes, or PR creation unless the user explicitly approves a degraded path.
```

Use `COMPLETE_WITH_SKIPS` only when oversized files were excluded. Otherwise use `COMPLETE`.

For a complete review, use this structure:

```markdown
Review URL: <PR URL or unavailable (no existing PR)>

# Review result

## Decision
- Review status: <COMPLETE or COMPLETE_WITH_SKIPS>
- Code assessment: <CHANGES_REQUIRED, NEEDS_DECISION, or NO_ACTION>
- Findings: Required <count> / Recommended <count>
- Coverage: <reviewed file count> / <changed file count> files
- Skipped: <count> inputs

## PR overview
- Purpose: why the PR exists, based on PR context when available
- Main changes: concise summary of the implemented changes
- Main risk: the most important risk, or `none identified`

## Required

### R1 [High] `file:line` — short title
- Problem / impact: what is broken, missing, or unsafe and what can happen
- Evidence: why this follows from the diff or code
- Action: concrete fix direction and focused verification
- Signal: reviewer | simplify | multiple

## Recommended

### A1 [Medium] `file:line` — short title
- Problem / impact: what is uncertain or approval-worthy
- Evidence: why this deserves consideration
- Action: concrete decision or follow-up
- Signal: reviewer | simplify | multiple

## Verification plan
- Commands or tests to run after Required fixes

## Excluded / reference
- Skipped file: <file> — <bytes> bytes; single-file review limit exceeded
- Not needed: <count> findings
```

Omit empty Required, Recommended, Verification plan, and Excluded / reference sections. For `NO_ACTION`, Decision and PR overview are sufficient. Each Required and Recommended item keeps a 3–5 line explanation covering the problem, impact, evidence, and action.
