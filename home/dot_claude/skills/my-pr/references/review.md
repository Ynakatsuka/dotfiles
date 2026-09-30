# my-pr Review

Use this reference for the default, `review`, and `fix` command quality review stage. For the A/B/C reviewer set, also read `references/review-multi.md`.

This reference is read-only for repository behavior. It collects and integrates findings only. Do not edit product files, write reviewer notes, run fix verification, commit, push, create/update a PR, or mark a PR ready while using this reference. The main orchestrator may write `.tmp/my-pr/` artifacts and state files only; reviewers must not write files.

## Design principles

- Separate finding from filtering. Reviewers should surface potential issues with severity and confidence; integration decides what is Required, Recommended, or Not needed.
- Ask for coverage, not only high-severity findings. Do not let reviewers silently drop plausible bugs because they think they are not important enough.
- Keep scope explicit: review the full PR diff against the base branch, not only the latest simplify changes.
- Keep reviewer responsibilities separate. Simplify handles quality, duplication, and behavior-preserving micro-efficiency. Claude/Codex review approach fit, correctness, security, performance regressions, and test risks.
- Require line references, problem detail, why it matters, evidence, and a concrete fix strategy for every finding.
- Do not collapse integrated findings into one-line verdicts. Each Required and Recommended item must include a clear 3-5 line explanation covering the problem, why it matters, the ideal state, and the fix or next step.
- Treat AI review as assistive. Verify findings before changing code, and run targeted tests after fixes.
- Check cross-client and downstream impact when the repository has multiple clients, SDKs, entrypoints, or pipelines. Do not assume one client is the only consumer.
- Check approach fit against the PR problem: whether the chosen solution actually solves the stated issue, and whether a simpler, safer, or existing path would solve it better. Report alternatives only when there is concrete evidence, such as an existing extension point, duplicated implementation, violated constraint, or avoidable operational/maintenance risk.
- Do not continue with degraded evidence. If a diff artifact or any selected reviewer run or background task fails, stop before fixing or creating a PR unless the user explicitly approves the degraded path. The only standing exception is a structurally invalid Reviewer B result after the bounded format-correction step in `references/review-multi.md`: skip Reviewer B, disclose the skip, and integrate Reviewer A/C.

## Artifact and scope gate

Use repo-local artifacts. Do not pass `/tmp` diff files to reviewers.

`SKILL.md` step 2 creates the review artifacts, PR context, and review prompts in one shell call and prints one absolute `artifact.env` path. Preserve that exact path as orchestration state. Replace `/absolute/path/to/artifact.env` below with it; never infer the current artifact from `latest-env.sh` or a previous shell environment.

Read `MY_PR_SCOPE_SUMMARY` before launching reviewers. If `MY_PR_SCOPE_GATE` is not `ok`, stop.

- `large`: continue only when the user already clearly confirmed that the whole current branch/diff is the target PR scope.
- `untracked`: classify the untracked files. Stage or `git add -N` task-created files that belong in the PR, or confirm they are out of scope, then regenerate artifacts.
- `large+untracked`: resolve both conditions before continuing.

The state file persists these generated paths. They are not user-configured environment prerequisites; source the explicit file only within a shell call that needs to inspect them:

```text
MY_PR_ARTIFACT_DIR=<repo-local artifact dir>
MY_PR_ARTIFACT_ENV=<artifact dir>/artifact.env
MY_PR_REVIEW_DIFF=<artifact dir>/review.diff
MY_PR_REVIEW_BYTES=<review diff bytes>
MY_PR_CHANGED_FILES=<artifact dir>/changed-files.txt
MY_PR_SCOPE_SUMMARY=<artifact dir>/scope-summary.txt
```

Never stage or commit `.tmp/my-pr/`.

## PR context and first-time reviewer orientation

`prepare-pr-context.sh` persists these generated paths:

```text
MY_PR_CONTEXT=<artifact dir>/pr-context.md
MY_PR_CONTEXT_STATE=found|no_existing_pr
MY_PR_CONTEXT_BYTES=<PR context bytes>
MY_PR_METADATA=<artifact dir>/pr-metadata.json
MY_PR_ISSUE_COMMENTS=<artifact dir>/pr-issue-comments.json
MY_PR_REVIEWS=<artifact dir>/pr-reviews.json
MY_PR_REVIEW_COMMENTS=<artifact dir>/pr-review-comments.json
```

If `MY_PR_CONTEXT_STATE=found`, reviewers must read `MY_PR_CONTEXT` before the diff. Treat the reviewer as seeing this PR for the first time:

1. Understand the PR title, body, linked issues, comments, reviews, and inline review comments.
2. Extract the problem the PR is trying to solve, intended behavior, explicit constraints, and decisions already made in discussion.
3. Cross-check the diff against that intended behavior. Report mismatches between PR intent and implementation as findings.
4. Avoid re-raising discussion items already resolved in the PR conversation unless the diff still violates the resolved decision.

If `MY_PR_CONTEXT_STATE=no_existing_pr`, state that no PR body or prior GitHub conversation exists. Do not invent missing intent; infer only from the diff and repository files, and mark intent uncertainty in the affected findings.

## Reviewer selection

Select the reviewer set after reading the scope summary, PR context, and diff. Use Reviewer C alone for small, low-risk changes. Use all three reviewers (A: simplify, B: Claude correctness, C: Codex correctness) when any of these applies:

- public contract, authentication/authorization, secret-handling, or data-migration changes
- a large scope (`MY_PR_SCOPE_GATE=large` after scope approval)
- review diff lines > 10,000, review diff bytes > 196,608, or a single reviewer cannot read the full artifact within tool limits; these also require chunking
- material uncertainty about correctness or cross-component impact
- an explicit request for multiple reviewers

Record the selected reviewer names and a short reason in the current artifact's `state.md` before launch. This selection does not bypass the scope gate or authorize retries. Do not silently reduce the selected set after a failure. A/B are not skipped or missing when C alone was selected.

For A/B/C, also read `references/review-multi.md` and follow its chunking and launch steps instead of Single-reviewer launch below.

## Review prompts

`SKILL.md` step 2 runs `scripts/prepare-review-prompts.sh "/absolute/path/to/artifact.env"`. Do not write, retype, or read back reviewer prompts; the fixed text lives in `assets/review-prompts/`, and reviewers receive it through the runners.

The script writes `simplify-review-prompt.md` (Reviewer A) and `correctness-review-prompt.md` (Reviewers B and C) under the artifact directory, embeds branch, base, and changed files, persists `MY_PR_SIMPLIFY_PROMPT` and `MY_PR_CORRECTNESS_PROMPT` to the state file, and prints one `<role>\t<absolute path>` line per prompt.

When the user asked for review focus beyond the templates, such as a prose-quality check, write only that extra instruction to a file under the artifact directory and pass it as the second argument. The script inserts it as `<additional_focus>` in both prompts; rerun the script with that file when the focus was not known at step 2. Do not edit the generated prompts afterward.

## Single-reviewer launch

Verify `scripts/run-codex-review.sh` and its Codex CLI prerequisites, then run it directly with the generated correctness prompt:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/run-codex-review.sh" \
  "reviewer-c" "full" "1" \
  "/absolute/artifact/path/correctness-review-prompt.md" \
  "/absolute/artifact/path/pr-context.md" \
  "/absolute/artifact/path/review.diff"
```

Use the absolute review Markdown path printed by the runner. Give the execution a 600,000 ms timeout where supported, or keep the returned background session alive until completion. Early tool yielding is not execution completion. On non-zero exit, timeout, or invalid input/receipt, return `REVIEW_INCOMPLETE`; do not substitute A/B or retry without approval. Do not use `/my-agent codex`; it streams token-heavy output and inherits nested multi-agent settings that this read-only leaf reviewer must disable.

## Codex runner guarantees

`scripts/run-codex-review.sh`, used directly for C alone and through `scripts/run-codex-reviews.sh` for A/B/C:

- embeds the complete PR context and assigned diff directly into Codex stdin; never pass artifact paths to Codex and ask it to read them
- pins each reviewer's effort so the global Codex config cannot silently change review depth: Reviewer A runs the configured model at `medium` effort; Reviewer C additionally pins its model to `gpt-6-sol` at `medium` effort
- caps the generated prompt at 393,216 bytes before launch
- runs from an isolated artifact-local Git repository instead of the review target repository
- disables nested agents, hooks, shell, web, browser, apps, plugins, and configured MCP servers, and uses a read-only sandbox
- derives the artifact root from the required context-file argument, so reviewer processes do not need to inherit `MY_PR_ARTIFACT_DIR`
- stores stdout/stderr under that artifact root instead of streaming token-heavy output to the parent tool
- requires JSON Schema output with matching SHA-256 receipts and an unpredictable nonce disclosed only after the final diff boundary
- exits non-zero on missing input, oversized prompt, Codex failure, incomplete status, or receipt mismatch

If the runner exits non-zero, Codex lacks quota, the generated prompt is oversized, the receipt does not match, or Codex returns incomplete output, stop before integration. Do not replace Codex with Claude/local review without explicit user approval.

## Background execution rule

If reviewers run in the background, do not send a final answer while any reviewer is still running.

When a long-running review must continue after the current response, persist a state note at the exact `<artifact-dir>/state.md` path with:

- reviewer names and output paths
- current status
- next command or next manual step
- whether any degraded path was approved

If the environment provides a background monitor, register the task before the final response. Otherwise wait in the foreground or stop with `REVIEW_INCOMPLETE`.

## Integration rules

Deduplicate findings from the selected reviewers. Put each finding in exactly one category.

Before classifying, confirm that every selected reviewer and assigned chunk completed. For C alone, require its result only. For A/B/C, missing or failed A/C chunks mean `REVIEW_INCOMPLETE`; B is also required unless its completed result failed only Markdown structure validation after one format-correction attempt. In that existing exception, omit all B results, disclose the skip, and classify A/C. Never treat an execution or input failure as a format-only skip.

Every integrated finding must include a severity: `critical`, `high`, `medium`, or `low`. Do not output a Required, Recommended, or Not needed item without severity. If a reviewer omits severity, assign severity from the impact and evidence, include it in the output, and set `Severity source: integration-inferred`.

| Final category | Criteria |
|---|---|
| Required | Confirmed approach mismatch that leaves the stated problem unsolved or violates explicit constraints; confirmed correctness/security/data-loss/fallback/downstream/cross-client/contract/operations/performance issue; test gap for changed behavior that can hide a bug; behavior-preserving simplify Required |
| Recommended | Plausible but uncertain approach issue; simpler or safer alternative that needs design approval; design/API/schema/config change; approval-worthy operational design/config change; simplify Recommended; useful but approval-worthy test expansion |
| Not needed | Style preference; readability-only nit covered by no clear risk; false positive; issue outside this PR's scope |

This phase only classifies findings. Required fixes are applied later by the default or `fix` workflow. Recommended and Not needed findings are not applied by this skill.

## Finding verification

Reviewers see only the embedded diff and are told to report every plausible issue, so their findings include false positives. Before finalizing the classification, the main orchestrator verifies every finding that would be Required and every `critical` or `high` finding against the working tree:

1. Read the cited file around the cited line with a bounded read. When the claim depends on code outside the diff, such as a caller, definition, config consumer, or test, find it with `rg` or `ast-grep` and read that location too. Issue independent reads in one response.
2. Decide from what was read:
   - Confirmed: the code shows the claimed defect. Keep the evidence-based category.
   - Refuted: the code contradicts the claim, for example a guard, caller contract, or test already handles it. Classify as Not needed (false positive).
   - Unresolved: reading cannot settle the claim, for example it depends on runtime data, an external service, or execution. Keep Required only when the diff alone establishes the defect; otherwise classify as Recommended and state what remains unverified.
3. Record the outcome in each Required finding's `Checked` field.

Verification is read-only. Do not edit files, run tests, reproductions, or other commands that write, and do not call reviewers again. Reading files here does not replace the embedded diff as the review scope: do not add new findings from unrelated code.

## Integration output

For `my-pr review`, create the final response as the review comment. Optimize for the decisions a reviewer or fixer must make. Start with a one-line verdict heading so the reader sees the outcome before anything else, then the PR identity and overview. Group findings by action (`Required`, then `Recommended`), not by severity. Sort findings within each action by severity: critical, high, medium, low.

Derive the verdict heading only from Review status and Code assessment. Use exactly one of:

| Review status | Code assessment | Verdict heading |
|---|---|---|
| `REVIEW_INCOMPLETE` | any | `# ⚠️ REVIEW INCOMPLETE — no verdict` |
| `COMPLETE` / `COMPLETE_WITH_SKIPS` | `CHANGES_REQUIRED` | `# 🔴 CHANGES REQUIRED — Required <count>` |
| `COMPLETE` / `COMPLETE_WITH_SKIPS` | `NEEDS_DECISION` | `# ✅ LGTM — Recommended <count> to consider` |
| `COMPLETE` / `COMPLETE_WITH_SKIPS` | `NO_ACTION` | `# ✅ LGTM` |

`LGTM` means no Required finding in the reviewed scope; Recommended items are optional decisions and are not applied by this skill. For `COMPLETE_WITH_SKIPS`, append ` (<count> inputs not reviewed)` to the heading so a skip is never read as full coverage.

Read the PR number, title, URL, state/draft status, and base/head branches from `MY_PR_METADATA`; do not reconstruct or guess them. Follow that metadata with a concise purpose, main-change summary, and main risk based on the PR context and diff. If `MY_PR_CONTEXT_STATE=no_existing_pr`, identify the PR and URL as unavailable and use the known base/current branch for scope instead.

After the overview, include `Good points`. Summarize concrete strengths supported by the diff, such as a sound approach, well-contained scope, clear failure behavior, or meaningful regression coverage. Avoid generic praise. If no evidence-backed strength is identifiable, write `- none identified`. If the review is incomplete, write `- unavailable: review incomplete` instead of drawing a positive conclusion from partial coverage.

Separate execution coverage from the code decision:

- Review status: `COMPLETE`, `COMPLETE_WITH_SKIPS`, or `REVIEW_INCOMPLETE`
- Code assessment: `CHANGES_REQUIRED` when any Required finding exists; `NEEDS_DECISION` when no Required finding exists but at least one Recommended finding exists; otherwise `NO_ACTION`

Assign stable IDs in output order:

- Required: `R1`, `R2`, ...
- Recommended: `A1`, `A2`, ...

For each Required and Recommended finding, include only:

- Problem / impact: what is wrong and what can break or become unsafe
- Evidence: the concrete diff/code evidence; include uncertainty here when relevant
- Action: the concrete fix or decision, plus focused verification when useful
- Checked (Required only): the `file:line` locations the orchestrator read and the outcome, such as `confirmed at src/a.py:40; caller src/b.py:12 passes None`
- Signal: `simplify`, `Claude`, `Codex`, or `multiple`

Keep severity in the finding heading. Do not include Confidence in the integrated output. Include `Severity source: integration-inferred` only when integration had to infer a missing severity; otherwise omit severity-source metadata.

Omit empty Required and Recommended sections. Summarize Not needed findings as a count under `Excluded / reference`; list an individual Not needed item only when recording why a potentially important finding was rejected prevents confusion. Do not emit empty severity sections.

If review is incomplete, output only:

```markdown
# ⚠️ REVIEW INCOMPLETE — no verdict

# PR overview
- PR: #<number> <title>, or unavailable (no existing PR)
- URL: <PR URL or unavailable (no existing PR)>
- Status: <state and draft status, or unavailable>
- Branches: <base> ← <head/current branch>
- Purpose: why the PR exists, based on PR context when available
- Main changes: concise summary of the implemented changes
- Main risk: unavailable because the review is incomplete

## Good points
- unavailable: review incomplete

# Review result

## Decision
- Review status: REVIEW_INCOMPLETE
- Code assessment: unavailable

## Missing or failed inputs
- <reviewer/chunk/artifact>: <exact failure>

## Next step
- Stop before fixes, commits, pushes, or PR creation unless the user explicitly approves a degraded path.
```

If a selected Reviewer B or any oversized file was skipped, use `COMPLETE_WITH_SKIPS`; otherwise use `COMPLETE`. Successful C-only review is `COMPLETE`; unselected A/B do not count as skips. State which reviewer set ran in the result. A format-only Reviewer B skip does not add a retry request or `Next step` section.

For a complete review, use this structure:

```markdown
# <verdict heading from the table above>

# PR overview
- PR: #<number> <title>, or unavailable (no existing PR)
- URL: <PR URL or unavailable (no existing PR)>
- Status: <state and draft status, or unavailable>
- Branches: <base> ← <head/current branch>
- Purpose: why the PR exists, based on PR context when available
- Main changes: concise summary of the implemented changes
- Main risk: the most important risk, or `none identified`

## Good points
- concrete, evidence-backed strength in the implementation, design, or verification

# Review result

## Decision
- Review status: <COMPLETE or COMPLETE_WITH_SKIPS>
- Code assessment: <CHANGES_REQUIRED, NEEDS_DECISION, or NO_ACTION>
- Findings: Required <count> / Recommended <count>
- Coverage: <reviewed file count> / <changed file count> files
- Skipped: <count> inputs

## Required

### R1 [High] `file:line` — short title
- Problem / impact: what is broken, missing, or unsafe and what can happen
- Evidence: why this follows from the diff or code
- Action: concrete fix direction and focused verification
- Checked: locations read and outcome
- Signal: Claude | Codex | simplify | multiple

## Recommended

### A1 [Medium] `file:line` — short title
- Problem / impact: what is uncertain or approval-worthy
- Evidence: why this deserves consideration
- Action: concrete decision or follow-up
- Signal: Claude | Codex | simplify | multiple

## Verification plan
- Commands or tests to run after Required fixes

## Excluded / reference
- Skipped reviewer: Reviewer B — <exact structural validation failure after one correction attempt>
- Skipped file: <file> — <bytes> bytes; single-file review limit exceeded
- Not needed: <count> findings (<count> refuted during verification)
```

Omit `Required`, `Recommended`, `Verification plan`, or `Excluded / reference` when the section has no content. Always retain the verdict heading, `PR overview`, and `Good points`. For `NO_ACTION`, those sections and the Decision are sufficient.
