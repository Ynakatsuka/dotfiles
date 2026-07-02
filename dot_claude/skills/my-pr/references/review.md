# my-pr Review Prompts

Use this reference for the default, `review`, and `fix` command quality review stage.

This reference is read-only for repository behavior. It collects and integrates findings only. Do not edit product files, write reviewer notes, run fix verification, commit, push, create/update a PR, or mark a PR ready while using this reference. The main orchestrator may write `.tmp/my-pr/` artifacts and state files only; reviewers must not write files.

## Design principles

- Separate finding from filtering. Reviewers should surface potential issues with severity and confidence; integration decides what is Required, Recommended, or Not needed.
- Ask for coverage, not only high-severity findings. Do not let reviewers silently drop plausible bugs because they think they are not important enough.
- Keep scope explicit: review the full PR diff against the base branch, not only the latest simplify changes.
- Keep reviewer responsibilities separate. Simplify handles quality, duplication, and behavior-preserving micro-efficiency. Claude/Codex review correctness, security, performance regressions, and test risks.
- Require line references, problem detail, why it matters, evidence, and a concrete fix strategy for every finding.
- Do not collapse integrated findings into one-line verdicts. Each Required and Recommended item must include a clear 3-5 line explanation covering the problem, why it matters, the ideal state, and the fix or next step.
- Treat AI review as assistive. Verify findings before changing code, and run targeted tests after fixes.
- Check cross-client and downstream impact when the repository has multiple clients, SDKs, entrypoints, or pipelines. Do not assume one client is the only consumer.
- Do not continue with degraded evidence. If a diff artifact, reviewer, Codex run, or background task fails, stop before fixing or creating a PR unless the user explicitly approves the degraded path.

## Artifact and scope gate

Use repo-local artifacts. Do not pass `/tmp` diff files to reviewers.

```bash
eval "$(bash "${CLAUDE_SKILL_DIR}/scripts/prepare-review-artifacts.sh" "$BASE_REF")"
```

Read `MY_PR_SCOPE_SUMMARY` before launching reviewers. If `MY_PR_SCOPE_GATE` is not `ok`, stop.

- `large`: continue only when the user already clearly confirmed that the whole current branch/diff is the target PR scope.
- `untracked`: classify the untracked files. Stage or `git add -N` task-created files that belong in the PR, or confirm they are out of scope, then regenerate artifacts.
- `large+untracked`: resolve both conditions before continuing.

Use these generated paths:

```text
MY_PR_ARTIFACT_DIR=<repo-local artifact dir>
MY_PR_ARTIFACT_ENV=<artifact dir>/artifact.env
MY_PR_REVIEW_DIFF=<artifact dir>/review.diff
MY_PR_CHANGED_FILES=<artifact dir>/changed-files.txt
MY_PR_SCOPE_SUMMARY=<artifact dir>/scope-summary.txt
```

Never stage or commit `.tmp/my-pr/`.

## PR context and first-time reviewer orientation

After preparing review artifacts, capture PR context:

```bash
eval "$(bash "${CLAUDE_SKILL_DIR}/scripts/prepare-pr-context.sh)"
```

Use these generated paths:

```text
MY_PR_CONTEXT=<artifact dir>/pr-context.md
MY_PR_CONTEXT_STATE=found|no_existing_pr
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

If `MY_PR_CONTEXT_STATE=no_existing_pr`, state that no PR body or prior GitHub conversation exists. Do not invent missing intent; infer only from the diff and repository files, and mark intent uncertainty in findings or Non-findings.

## Large diff chunking

Use the full `MY_PR_REVIEW_DIFF` by default. Split Reviewer A, Reviewer B, and Reviewer C by file groups or top-level domains only when any condition is true:

- review diff lines > 10,000
- a single reviewer cannot read the full artifact within tool limits

Changed file count alone is not enough to chunk. Prefer one full-diff review when the artifact is readable within limits.

Chunk rules:

1. Group files by subsystem or top-level directory.
2. Keep each chunk near 2,000-3,000 diff lines when possible.
3. Generate initial chunk artifacts with `bash "${CLAUDE_SKILL_DIR}/scripts/split-review-chunks.sh" "$BASE_REF"`.
4. Each chunk prompt must include `Chunk id`, `Files covered`, and `Files not covered`.
5. Integration must list all chunks for all reviewers and stop if any chunk is missing, failed, or inaccessible.

If a generated chunk is still too large, split its `files.txt` into smaller subsystem-specific file lists and create additional chunk artifacts under `MY_PR_ARTIFACT_DIR/chunks/`.

For small diffs, use the single `MY_PR_REVIEW_DIFF`.

Reviewer A chunks run integrated simplify in `review` mode with the simplify performance profile from `references/simplify/overview.md`. Include `MY_PR_CONTEXT` in the simplify prompt when it exists, so simplify also understands the PR's stated problem and prior discussion before proposing changes. Each Reviewer A run or chunk reports at most 5 Required and at most 5 Recommended findings. Integration deduplicates simplify findings across chunks.

## Review focus checklist

Use this checklist for Claude/Codex correctness review. Exclude style or preference-only findings, but keep plausible low-severity or uncertain risks for integration. Put inspected-but-safe areas in Non-findings when useful.

- Fallbacks: unintended fallback behavior, default substitution, broad catch, silent retry, mock/stub continuation, cached-data continuation, or swallowed dependency/config failures.
- Downstream impact: changed output shape, ordering, timing, side effects, idempotency, error semantics, event names, metrics, logs, artifacts, or files consumed by later processing.
- Cross-client reference parity: existing implementations, helpers, schemas, flows, fixtures, or tests in other clients/SDKs that should have been reused or matched.
- Cross-client compatibility: behavior changes that can break other clients, shared libraries, generated code, API callers, CLI users, configuration consumers, or migration paths.
- Security: authentication, authorization, secret handling, injection, unsafe shell/file/path handling, SSRF, XSS, CSRF, deserialization, dependency trust, permissions, and data exposure.
- Public contracts: exported functions, types, schemas, API responses, CLI flags, config keys, database migrations, documented error semantics, and backward compatibility.
- Data integrity: data loss, partial writes, duplicate writes, transaction boundaries, rollback behavior, concurrency, race conditions, and timezone/locale/encoding issues.
- Operations: deploy order, feature flags, environment variables, observability, alerting, rate limits, resource usage, and failure modes that operators must see.
- Performance: algorithmic complexity regressions, N+1 queries, redundant I/O or network calls, blocking work on hot paths, missing pagination/streaming, unbounded memory growth, large allocations or copies inside loops, and lost caching or batching.
- Tests: changed behavior without focused unit, integration, regression, security, performance, or cross-client compatibility coverage.

## Inputs

Prepare these values before launching reviewers:

```text
BRANCH=<current branch>
BASE_BRANCH=<default branch>
BASE_REF=origin/<default branch>
MY_PR_REVIEW_DIFF=<repo-local full review diff from prepare-review-artifacts.sh>
MY_PR_CHANGED_FILES=<repo-local changed files list from prepare-review-artifacts.sh>
MY_PR_SCOPE_SUMMARY=<repo-local scope summary from prepare-review-artifacts.sh>
MY_PR_ARTIFACT_ENV=<sourceable env file for resuming the same artifact paths>
MY_PR_CONTEXT=<repo-local PR context from prepare-pr-context.sh>
MY_PR_CONTEXT_STATE=found|no_existing_pr
```

Launch Reviewer A, Reviewer B, and Reviewer C concurrently. Do not run them sequentially unless the environment cannot execute concurrent tasks; if concurrency is unavailable, report that limitation before starting review. Wait for all reviewer and chunk results before integration.

Reviewer B is host-aware:

- In a Claude Code session with the Agent tool available, use the Agent tool.
- In a Codex or other non-Claude host session, use the Claude Code CLI in non-interactive read-only mode with tools restricted to `Read`: `claude --permission-mode plan --tools Read --output-format=stream-json --verbose -p "<PROMPT>"`.
- Parse the final `stream-json` result event before integration. Use its `result` field as the reviewer text. If the final result event is missing, `permission_denials` is non-empty, the command is unavailable, authentication is missing, permissions fail, the command times out, or the reviewer text is incomplete, return `REVIEW_INCOMPLETE` and stop before integration.
- Do not invoke `/my-agent claude` from inside a delegated Claude session unless the user explicitly requested nested delegation.
- Do not pass `--model` unless the user explicitly requested a model. Use the Claude Code configured default model and effort.
- If a prompt file is needed for quoting, write it under `MY_PR_ARTIFACT_DIR` as an orchestration artifact. Do not use `/tmp`, and never stage or commit it.

## Reviewer A: integrated simplify review

Read `references/simplify/overview.md`. Run integrated simplify in `review` mode against `MY_PR_REVIEW_DIFF` or the assigned chunk artifact. Use the simplify performance profile: Codex CLI with `model_reasoning_effort="medium"` and capped findings. Do not use `/my-agent codex` for Reviewer A unless the user explicitly requests the global Codex default, because `/my-agent` intentionally preserves the global effort setting.

If Codex fails, times out, lacks quota, rejects the config override, or cannot read the artifact, return `REVIEW_INCOMPLETE` and stop. Do not silently switch to Claude/local execution.

Pass the PR context artifact path in the prompt. Reviewer A must read it before the diff when it exists, and must not propose simplifications that conflict with the PR's stated problem, constraints, or resolved discussion.

Keep its output categories as-is:

- Required
- Recommended
- Not needed

## Reviewer B: Claude correctness review

Use the host-aware executor above with this prompt.

```text
<role>
You are a senior software engineer reviewing a pull request for correctness, security, and test risk.
</role>

<context>
Branch: <BRANCH>
Base branch: <BASE_BRANCH>
Base ref: <BASE_REF>
Changed files:
<MY_PR_CHANGED_FILES contents>
Review diff artifact:
<MY_PR_REVIEW_DIFF>
PR context artifact:
<MY_PR_CONTEXT>
</context>

<scope>
Review the full branch diff against the base branch. Do not review only the latest simplify changes.
Use the review diff artifact as the source of truth. If you cannot read it, return REVIEW_INCOMPLETE and do not review current file state as a substitute.
Read the PR context artifact before the diff. You are seeing this PR for the first time, so first identify the problem it is trying to solve, intended behavior, constraints, and prior discussion decisions. If the PR context says no existing PR exists, state that limitation and do not invent missing intent.
Focus on:
1. Correctness bugs, edge cases, data loss, race conditions, and error semantics
2. Unintended fallback behavior, default substitution, broad catch, silent retry, mock/stub continuation, cached-data continuation, or swallowed dependency/config failures
3. Downstream processing impact from changed output shape, ordering, timing, side effects, idempotency, error semantics, event names, metrics, logs, artifacts, or files
4. Cross-client impact: ignored reusable/reference implementations in other clients/SDKs, or changes that can break other clients, shared libraries, generated code, API callers, CLI users, configuration consumers, or migration paths
5. Security issues, secret leakage, injection, unsafe shell/file/path handling, authorization mistakes, dependency trust, permissions, and data exposure
6. Public contract and backward compatibility risks in exported functions, types, schemas, API responses, CLI flags, config keys, migrations, or documented error semantics
7. Operational risks around deploy order, feature flags, environment variables, observability, alerting, rate limits, resource usage, and visible failure modes
8. Performance regressions: algorithmic complexity, N+1 queries, redundant I/O or network calls, blocking work on hot paths, missing pagination/streaming, unbounded memory growth, large allocations or copies inside loops, or lost caching/batching
9. Missing or weak tests for changed behavior, especially regression, security, downstream, and cross-client compatibility coverage
</scope>

<out_of_scope>
Code quality, duplication, naming style, formatting, and efficiency are handled separately by integrated simplify. Do not report style preferences, pure readability nits, generated files, lockfiles, vendored dependencies, snapshots, or issues already enforced by CI unless the diff creates a concrete correctness or security risk.
</out_of_scope>

<read_only_rules>
Do not edit files.
Do not write files anywhere, including the repository, .plans, .tmp, or /tmp.
Do not use Bash or any shell command.
Use only the Read tool and the supplied diff artifact.
Use the supplied PR context artifact as the source of truth for PR body and prior GitHub conversation. If it cannot be read, return REVIEW_INCOMPLETE.
Do not run formatters, tests, generators, migrations, reproductions, grep, rg, git, or commands of any kind.
If additional evidence would require a shell command or another unavailable tool, report the uncertainty in the finding or Non-findings instead of trying to execute it.
</read_only_rules>

<finding_policy>
Report every plausible issue you find, including low-severity or uncertain findings. Do not filter for importance at this stage; integration will rank and filter. For each finding include severity and confidence.
</finding_policy>

<output_format>
## PR understanding
- Problem: one sentence based on the PR context, or "Unavailable: no existing PR context".
- Intended behavior: one sentence.
- Prior discussion constraints: bullets, or "- none found".

## Strengths
- Specific strengths in the diff, if any. Keep this short.

## Findings

1. **file:line** — short title
   - Category: correctness | fallback | downstream | cross-client | security | contract | operations | performance | tests
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Impact: what can break or become unsafe
   - Evidence: why this follows from the diff/code
   - Suggested fix: concrete fix direction
   - Verification: test or command that should catch this

## Non-findings
- Optional: notable risks inspected but not reported, with reason.

## Assessment

**Ready to merge?** Yes | No | With fixes

**Reasoning:** One or two technical sentences.
</output_format>
```

If the Claude Agent or CLI exits non-zero, lacks quota or authentication, cannot read the diff artifact, or returns incomplete output, stop before integration. Do not replace Claude review with Codex/local review without explicit user approval.

## Reviewer C: Codex correctness review

Use the repo-local `MY_PR_REVIEW_DIFF`. Do not create `/tmp` diff files.

Run `/my-agent codex` with this prompt:

```text
Review the diff in <MY_PR_REVIEW_DIFF> as a senior software engineer.

Before reviewing code, read the PR context in <MY_PR_CONTEXT>. You are seeing this PR for the first time, so identify the problem it is trying to solve, intended behavior, constraints, and prior discussion decisions. If the PR context says no existing PR exists, state that limitation and do not invent missing intent.

Scope:
- Review the full branch diff against <BASE_BRANCH>.
- Use the diff artifact as the source of truth. If you cannot read it, return REVIEW_INCOMPLETE and do not review current file state as a substitute.
- Use the PR context artifact as the source of truth for PR body and prior GitHub conversation. If it cannot be read, return REVIEW_INCOMPLETE.
- Cross-check the implementation against the PR intent. Report mismatches between the stated goal and the diff as findings.
- Focus on correctness bugs, edge cases, data loss, race conditions, and error semantics.
- Check for unintended fallback behavior, default substitution, broad catch, silent retry, mock/stub continuation, cached-data continuation, or swallowed dependency/config failures.
- Check downstream processing impact from changed output shape, ordering, timing, side effects, idempotency, error semantics, event names, metrics, logs, artifacts, or files.
- Check cross-client impact: ignored reusable/reference implementations in other clients/SDKs, or changes that can break other clients, shared libraries, generated code, API callers, CLI users, configuration consumers, or migration paths.
- Check security issues, unsafe shell/file/path handling, secret leakage, injection, authorization mistakes, dependency trust, permissions, and data exposure.
- Check public contract and backward compatibility risks in exported functions, types, schemas, API responses, CLI flags, config keys, migrations, or documented error semantics.
- Check operational risks around deploy order, feature flags, environment variables, observability, alerting, rate limits, resource usage, and visible failure modes.
- Check performance regressions: algorithmic complexity, N+1 queries, redundant I/O or network calls, blocking work on hot paths, missing pagination/streaming, unbounded memory growth, large allocations or copies inside loops, or lost caching/batching.
- Check missing or weak tests for changed behavior, especially regression, security, downstream, and cross-client compatibility coverage.
- Do not report code quality, duplication, naming style, formatting, or efficiency issues; integrated simplify handles those separately.
- Do not report issues already enforced by CI, generated files, lockfiles, vendored dependencies, snapshots, or preference-only nits unless the diff creates a concrete correctness or security risk.
- Do not edit or write files anywhere. Do not create notes under .plans, .tmp, or /tmp.

Finding policy:
- Report every plausible issue you find, including low-severity or uncertain findings.
- Do not filter for importance at this stage. Integration will rank and filter.
- Include severity and confidence for each finding.

Output exactly this structure:

## PR understanding
- Problem: one sentence based on the PR context, or "Unavailable: no existing PR context".
- Intended behavior: one sentence.
- Prior discussion constraints: bullets, or "- none found".

## Strengths
- Specific strengths in the diff, if any. Keep this short.

## Findings

1. **file:line** — short title
   - Category: correctness | fallback | downstream | cross-client | security | contract | operations | performance | tests
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Impact: what can break or become unsafe
   - Evidence: why this follows from the diff/code
   - Suggested fix: concrete fix direction
   - Verification: test or command that should catch this

## Non-findings
- Optional: notable risks inspected but not reported, with reason.

## Assessment

**Ready to merge?** Yes | No | With fixes

**Reasoning:** One or two technical sentences.
```

If Codex exits non-zero, lacks quota, cannot read the diff, or returns incomplete output, stop before integration. Do not replace Codex with Claude/local review without explicit user approval.

## Background execution rule

If reviewers run in the background, do not send a final answer while any reviewer is still running.

When a long-running review must continue after the current response, persist a state note under `MY_PR_ARTIFACT_DIR/state.md` with:

- reviewer names and output paths
- current status
- next command or next manual step
- whether any degraded path was approved

If the environment provides a background monitor, register the task before the final response. Otherwise wait in the foreground or stop with `REVIEW_INCOMPLETE`.

## Integration rules

Deduplicate findings from simplify, Claude, and Codex. Put each finding in exactly one category.

Before classifying, confirm all required reviewers and chunks completed. If any required reviewer/chunk is missing or failed, output `REVIEW_INCOMPLETE` and stop.

| Final category | Criteria |
|---|---|
| Required | Confirmed correctness/security/data-loss/fallback/downstream/cross-client/contract/operations/performance issue; test gap for changed behavior that can hide a bug; behavior-preserving simplify Required |
| Recommended | Plausible but uncertain issue; design/API/schema/config change; approval-worthy operational design/config change; simplify Recommended; useful but approval-worthy test expansion |
| Not needed | Style preference; readability-only nit covered by no clear risk; false positive; issue outside this PR's scope |

This phase only classifies findings. Required fixes are applied later by the default or `fix` workflow. Recommended and Not needed findings are not applied by this skill.

## Integration output

For each Required and Recommended finding, write 3-5 concise sub-bullets, including metadata when present. Include:

- Problem: what is wrong, missing, or risky in the current diff
- Why: why the fix is required now, or why approval is needed before changing it
- Ideal state: the invariant, behavior, or maintainability target the code should satisfy
- Fix/next step: concrete change direction, plus verification when useful

If review is incomplete, output only:

```markdown
# Quality Review Result

## Status
REVIEW_INCOMPLETE

## Missing or failed inputs
- <reviewer/chunk/artifact> — <exact failure>

## Next step
- Stop before fixes, commits, pushes, or PR creation unless the user explicitly approves a degraded path.
```

If all required reviewers and chunks completed, output:

```markdown
# Quality Review Result

## Status
COMPLETE

## PR context
- Context state: found | no_existing_pr
- Problem understood: one sentence based on PR body/conversation, or "Unavailable: no existing PR context"
- Prior discussion considered: key constraints or "- none found"

## Required
1. **file:line** — short title
   - Signal: source simplify | Claude | Codex | multiple; severity critical | high | medium | low; confidence high | medium | low
   - Problem: what is broken, missing, or unsafe
   - Why required: concrete risk that makes this necessary before merge
   - Ideal state: expected invariant, behavior, or contract
   - Fix: concrete fix direction and verification

## Recommended
1. **file:line** — short title
   - Signal: source simplify | Claude | Codex | multiple
   - Problem: what is suboptimal, risky, or uncertain
   - Why approval is needed: trade-off or contract/design choice
   - Ideal state: expected design, behavior, or maintainability target
   - Next step: concrete option to approve, defer, or investigate

## Not needed
- **file:line** — ignored finding and reason

## Verification plan
- Commands/tests to run after fixes
```
