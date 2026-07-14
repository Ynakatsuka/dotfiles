# my-pr Review Prompts

Use this reference for the default, `review`, and `fix` command quality review stage.

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
- Do not continue with degraded evidence. If a diff artifact, Reviewer A/C, Codex run, or background task fails, stop before fixing or creating a PR unless the user explicitly approves the degraded path. The only standing exception is a structurally invalid Reviewer B result after the bounded format-correction step below: skip Reviewer B, disclose the skip, and integrate Reviewer A/C.

## Artifact and scope gate

Use repo-local artifacts. Do not pass `/tmp` diff files to reviewers.

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
bash "$HOME/.claude/skills/my-pr/scripts/prepare-review-artifacts.sh" "$BASE_REF"
```

The script prints one absolute `artifact.env` path. Preserve that exact path as orchestration state. Replace `/absolute/path/to/artifact.env` below with it; never infer the current artifact from `latest-env.sh` or a previous shell environment.

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

After preparing review artifacts, capture PR context:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/prepare-pr-context.sh" "/absolute/path/to/artifact.env"
source "/absolute/path/to/artifact.env"
cat "$MY_PR_CONTEXT"
```

Use these generated paths:

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

If `MY_PR_CONTEXT_STATE=no_existing_pr`, state that no PR body or prior GitHub conversation exists. Do not invent missing intent; infer only from the diff and repository files, and mark intent uncertainty in findings or Non-findings.

## Large diff chunking

Use the full `MY_PR_REVIEW_DIFF` by default. Split Reviewer A, Reviewer B, and Reviewer C by file groups or top-level domains when any condition is true:

- review diff lines > 10,000
- review diff bytes > 196,608
- a single reviewer cannot read the full artifact within tool limits

Changed file count alone is not enough to chunk. Prefer one full-diff review when the artifact is readable within limits.

Chunk rules:

1. Group files by subsystem or top-level directory.
2. Keep each chunk at or below 196,608 bytes. Line count is not a safety bound because Markdown and generated content can contain long lines.
3. Generate chunk artifacts with `bash "$HOME/.claude/skills/my-pr/scripts/split-review-chunks.sh" "/absolute/path/to/artifact.env"`. The script loads the base ref from that state file, packs complete file diffs, verifies reviewable-file coverage, persists chunk paths back to the state file, and is compatible with macOS Bash 3.2.
4. Each chunk prompt must include `Chunk id`, `Files covered`, and `Files not covered`.
5. Integration must list all chunks for Reviewer A/C and stop if any is missing, failed, or inaccessible. If any Reviewer B chunk remains structurally invalid after format correction, skip the entire Reviewer B family instead of integrating partial B coverage. Also list every skipped file with its byte count and state that those files were not reviewed.

For a chunked run, tell each reviewer to review only the supplied `Files covered` as its assigned portion of the full PR. Do not ask one chunk to claim full-diff coverage. Integration establishes full coverage from the manifest and all completed chunk results.

The script reserves 8,192 bytes per chunk for metadata. If one complete file diff exceeds the remaining payload limit, skip only that file, record it in `MY_PR_SKIPPED_FILES` and `MY_PR_SKIPPED_FILE_SUMMARY`, and continue reviewing the remaining files. Do not split in the middle of a file or treat a skipped file as reviewed. If a generated Codex prompt exceeds 393,216 bytes, stop before launching that reviewer.

If every changed file is skipped, do not launch empty reviewer runs. Return a review result that lists every skipped file and clearly states that no file content was reviewed.

For small diffs, use the single `MY_PR_REVIEW_DIFF`.

Reviewer A chunks run integrated simplify in `review` mode with the simplify performance profile from `references/simplify/overview.md`. Include `MY_PR_CONTEXT` in the simplify prompt when it exists, so simplify also understands the PR's stated problem and prior discussion before proposing changes. Each Reviewer A run or chunk reports at most 5 Required and at most 5 Recommended findings. Integration deduplicates simplify findings across chunks.

## Codex review input integrity

Reviewer A and Reviewer C must use `scripts/run-codex-review.sh`. Do not pass artifact paths to Codex and ask Codex to read them with `cat`, `sed`, `Read`, or another tool.

The runner:

- embeds the complete PR context and assigned diff directly into Codex stdin
- caps the generated prompt at 393,216 bytes before launch
- runs from an isolated artifact-local Git repository instead of the review target repository
- disables nested agents, hooks, shell, web, browser, apps, plugins, and configured MCP servers, and uses a read-only sandbox
- derives the artifact root from the required context-file argument, so reviewer processes do not need to inherit `MY_PR_ARTIFACT_DIR`
- stores stdout/stderr under that artifact root instead of streaming token-heavy output to the parent tool
- requires JSON Schema output with matching SHA-256 receipts and an unpredictable nonce disclosed only after the final diff boundary
- exits non-zero on missing input, oversized prompt, Codex failure, incomplete status, or receipt mismatch

Write each role-specific prompt under the exact artifact directory recorded in `artifact.env`. Invoke one runner process per assigned chunk with literal values from that state file or chunk manifest; do not rely on shell variables inherited from orchestration:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/run-codex-review.sh" \
  reviewer-a "full" "1" \
  "/absolute/artifact/path/reviewer-a-prompt.md" \
  "/absolute/artifact/path/pr-context.md" \
  "/absolute/artifact/path/review.diff"

bash "$HOME/.claude/skills/my-pr/scripts/run-codex-review.sh" \
  reviewer-c "full" "1" \
  "/absolute/artifact/path/reviewer-c-prompt.md" \
  "/absolute/artifact/path/pr-context.md" \
  "/absolute/artifact/path/review.diff"
```

Each successful runner prints the absolute review Markdown path. Use that file as reviewer output. Never use a partial stdout/stderr log as review output. Do not retry a failed chunk or switch executors unless the user explicitly approves it.

Do not set or forward `MY_PR_ARTIFACT_DIR` solely for the runner. Its context-file argument is the source of truth for the result directory, including when Reviewer A/C runs in another process or shell.

## Review focus checklist

Use this checklist for Claude/Codex correctness review. Exclude style or preference-only findings, but keep plausible low-severity or uncertain risks for integration. Put inspected-but-safe areas in Non-findings when useful.

- Fallbacks: unintended fallback behavior, default substitution, broad catch, silent retry, mock/stub continuation, cached-data continuation, or swallowed dependency/config failures.
- Approach fit: whether the implementation directly solves the PR's stated problem under its constraints, whether it bypasses the intended architecture or extension point, and whether a simpler or safer existing implementation should have been reused or extended.
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
MY_PR_REVIEW_BYTES=<review diff bytes>
MY_PR_CHANGED_FILES=<repo-local changed files list from prepare-review-artifacts.sh>
MY_PR_SCOPE_SUMMARY=<repo-local scope summary from prepare-review-artifacts.sh>
MY_PR_ARTIFACT_ENV=<sourceable env file for resuming the same artifact paths>
MY_PR_CONTEXT=<repo-local PR context from prepare-pr-context.sh>
MY_PR_CONTEXT_STATE=found|no_existing_pr
MY_PR_CONTEXT_BYTES=<PR context bytes>
```

Launch Reviewer A, Reviewer B, and Reviewer C concurrently. All three reviewers must use the same full-diff input or the same chunk manifest. Process each reviewer's assigned chunks without nested delegation. Do not run the three reviewer families sequentially unless the environment cannot execute concurrent tasks; if concurrency is unavailable, report that limitation before starting review. Wait for all launched reviewer and chunk results before integration.

Reviewer B is host-aware:

- In a Claude Code session with the Agent tool available, use the Agent tool.
- In a Codex or other non-Claude host session, use the Claude Code CLI in non-interactive read-only mode with tools restricted to `Read`: `claude --permission-mode plan --tools Read --output-format=stream-json --verbose --json-schema "$(jq -c . "$HOME/.claude/skills/my-pr/assets/claude-review-result.schema.json")" -p "<PROMPT>"`. The final event must contain `structured_output.review_markdown` with the complete review body. Keep this schema dialect-neutral: Claude CLI validates the supported schema subset itself and rejects the Draft 2020-12 `$schema` URI before starting the review.
- For Agent output, have the main orchestrator save the final response verbatim to the exact `<artifact-dir>/reviewer-results/reviewer-b/<chunk-id>/review.md` path. For CLI output, extract only `structured_output.review_markdown` from the final `stream-json` result event into the same path. Do not make Reviewer B inherit `MY_PR_ARTIFACT_DIR`, and do not use an interim message, handoff summary, or shortened recap as the reviewer body.
- Validate every Reviewer B Markdown file with `bash "$HOME/.claude/skills/my-pr/scripts/validate-reviewer-b-output.sh" "/absolute/path/to/reviewer-b-review.md"` before integration.
- If the final result event is missing, `permission_denials` is non-empty, the command is unavailable, authentication is missing, permissions fail, the command times out, or Reviewer B reports that the diff/context was inaccessible, return `REVIEW_INCOMPLETE` and stop before integration.
- Do not invoke `/my-agent claude` from inside a delegated Claude session unless the user explicitly requested nested delegation.
- Do not pass `--model` unless the user explicitly requested a model. Use the Claude Code configured default model and effort.
- If a prompt file is needed for quoting, write it under the exact artifact directory from the current state file. Do not use `/tmp`, and never stage or commit it.

## Reviewer A: integrated simplify review

Read `references/simplify/overview.md`. Write its review-mode prompt under the exact artifact directory from the current state file, then run `scripts/run-codex-review.sh reviewer-a` with the absolute full-diff path or assigned chunk path. The runner applies `model_reasoning_effort="medium"`, embeds the complete inputs, disables nested delegation, and validates the receipt. Do not invoke Codex directly for Reviewer A.

If Codex fails, times out, lacks quota, rejects the config override, or cannot read the artifact, return `REVIEW_INCOMPLETE` and stop. Do not silently switch to Claude/local execution.

The runner embeds the PR context before the diff. Reviewer A must use that embedded context and must not propose simplifications that conflict with the PR's stated problem, constraints, or resolved discussion.

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
Review the supplied full branch diff or assigned chunk against the base branch. Do not review only the latest simplify changes.
For an assigned chunk, report findings only for `Files covered`; do not claim coverage of `Files not covered`.
Use the review diff artifact as the source of truth. If you cannot read it completely, return REVIEW_INCOMPLETE and do not review current file state as a substitute.
Read the PR context artifact before the diff. You are seeing this PR for the first time, so first identify the problem it is trying to solve, intended behavior, constraints, and prior discussion decisions. If the PR context says no existing PR exists, state that limitation and do not invent missing intent.
Focus on:
1. Approach fit: whether the current implementation is a sound way to solve the stated PR problem, whether it leaves the problem partly unsolved, violates explicit constraints, bypasses the intended architecture, or ignores a simpler, safer, or already-existing implementation path
2. Correctness bugs, edge cases, data loss, race conditions, and error semantics
3. Unintended fallback behavior, default substitution, broad catch, silent retry, mock/stub continuation, cached-data continuation, or swallowed dependency/config failures
4. Downstream processing impact from changed output shape, ordering, timing, side effects, idempotency, error semantics, event names, metrics, logs, artifacts, or files
5. Cross-client impact: ignored reusable/reference implementations in other clients/SDKs, or changes that can break other clients, shared libraries, generated code, API callers, CLI users, configuration consumers, or migration paths
6. Security issues, secret leakage, injection, unsafe shell/file/path handling, authorization mistakes, dependency trust, permissions, and data exposure
7. Public contract and backward compatibility risks in exported functions, types, schemas, API responses, CLI flags, config keys, migrations, or documented error semantics
8. Operational risks around deploy order, feature flags, environment variables, observability, alerting, rate limits, resource usage, and visible failure modes
9. Performance regressions: algorithmic complexity, N+1 queries, redundant I/O or network calls, blocking work on hot paths, missing pagination/streaming, unbounded memory growth, large allocations or copies inside loops, or lost caching/batching
10. Missing or weak tests for changed behavior, especially regression, security, downstream, and cross-client compatibility coverage
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
Your final response must contain the complete Markdown structure below and nothing else. Do not return a progress report, handoff summary, shortened recap, or a statement that the review was completed. Use `- none` in `Strengths`, `Findings`, or `Non-findings` when that section has no entries.
When the executor supplies a JSON Schema, put this complete Markdown verbatim in `review_markdown`. Do not put a summary in that field.

## PR understanding
- Description: one sentence describing what the PR changes.
- Purpose: one sentence explaining why the PR exists.
- Problem: one sentence based on the PR context, or "Unavailable: no existing PR context".
- Intended behavior: one sentence.
- Prior discussion constraints: bullets, or "- none found".

## Strengths
- Specific strengths in the diff, if any. Keep this short.

## Findings

1. **file:line** — short title
   - Category: approach | correctness | fallback | downstream | cross-client | security | contract | operations | performance | tests
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Impact: what can break or become unsafe
   - Evidence: why this follows from the diff/code
   - Suggested fix: concrete fix direction
   - Verification: test or command that should catch this

## Non-findings
- Notable risks inspected but not reported, with reason. Use `- none` when there are none.

## Assessment

**Ready to merge?** Yes | No | With fixes

**Reasoning:** One or two technical sentences.
</output_format>
```

If Reviewer B completes its review but `validate-reviewer-b-output.sh` rejects the final Markdown, request one format-only correction in the same Agent conversation or CLI session. Tell Reviewer B to re-emit its already completed review using the exact output format, without rereading files, calling tools, changing findings, or returning a summary. Validate the corrected body once.

If the corrected body is still invalid, skip the entire Reviewer B family, record the exact validation failure, and integrate Reviewer A/C. Do not retry again and do not replace Claude review with Codex or local review. This format-only skip is an explicitly approved degraded path and does not produce `REVIEW_INCOMPLETE`.

If the Claude Agent or CLI exits non-zero, lacks quota or authentication, times out, cannot read the diff/context artifact, or explicitly reports incomplete input, stop before integration. These execution and input failures are not format-only failures.

## Reviewer C: Codex correctness review

Use the repo-local `MY_PR_REVIEW_DIFF` or the assigned chunk artifact. Do not create `/tmp` diff files.

Write the following prompt under the exact artifact directory from the current state file, then run it with `scripts/run-codex-review.sh reviewer-c`. Do not use `/my-agent codex`; it streams token-heavy output and inherits nested multi-agent settings that this read-only leaf reviewer must disable.

```text
Review the supplied diff as a senior software engineer.

Before reviewing code, read the supplied PR context. You are seeing this PR for the first time, so identify the problem it is trying to solve, intended behavior, constraints, and prior discussion decisions. If the PR context says no existing PR exists, state that limitation and do not invent missing intent.

Scope:
- Review the supplied full diff, or the supplied assigned chunk, against <BASE_BRANCH>.
- For an assigned chunk, report findings only for `Files covered`; treat `Files not covered` as explicit scope metadata for integration.
- Use the embedded diff as the source of truth. If it is incomplete, return REVIEW_INCOMPLETE and do not review current file state as a substitute.
- Use the embedded PR context as the source of truth for PR body and prior GitHub conversation. If it is incomplete, return REVIEW_INCOMPLETE.
- Cross-check the implementation against the PR intent. Report mismatches between the stated goal and the diff as findings.
- Assess whether the chosen approach is a sound way to solve the stated PR problem. Report when it leaves the problem partly unsolved, violates explicit constraints, bypasses the intended architecture, or ignores a simpler, safer, or already-existing implementation path.
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
- Do not call tools, run shell commands, read repository files, delegate, or spawn subagents. All review inputs are embedded in the prompt.

Finding policy:
- Report every plausible issue you find, including low-severity or uncertain findings.
- Do not filter for importance at this stage. Integration will rank and filter.
- Include severity and confidence for each finding.

Output exactly this structure:

## PR understanding
- Description: one sentence describing what the PR changes.
- Purpose: one sentence explaining why the PR exists.
- Problem: one sentence based on the PR context, or "Unavailable: no existing PR context".
- Intended behavior: one sentence.
- Prior discussion constraints: bullets, or "- none found".

## Strengths
- Specific strengths in the diff, if any. Keep this short.

## Findings

1. **file:line** — short title
   - Category: approach | correctness | fallback | downstream | cross-client | security | contract | operations | performance | tests
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

Deduplicate findings from simplify, Claude, and Codex. Put each finding in exactly one category.

Before classifying, confirm all Reviewer A/C chunks completed. If any required A/C chunk is missing or failed, output `REVIEW_INCOMPLETE` and stop. Reviewer B is also required unless its completed result failed only the Markdown structure validation after one format-correction attempt. In that case, omit all Reviewer B results, mark it skipped, and continue classification using Reviewer A/C.

Every integrated finding must include a severity: `critical`, `high`, `medium`, or `low`. Do not output a Required, Recommended, or Not needed item without severity. If a reviewer omits severity, assign severity from the impact and evidence, include it in the output, and set `Severity source: integration-inferred`.

| Final category | Criteria |
|---|---|
| Required | Confirmed approach mismatch that leaves the stated problem unsolved or violates explicit constraints; confirmed correctness/security/data-loss/fallback/downstream/cross-client/contract/operations/performance issue; test gap for changed behavior that can hide a bug; behavior-preserving simplify Required |
| Recommended | Plausible but uncertain approach issue; simpler or safer alternative that needs design approval; design/API/schema/config change; approval-worthy operational design/config change; simplify Recommended; useful but approval-worthy test expansion |
| Not needed | Style preference; readability-only nit covered by no clear risk; false positive; issue outside this PR's scope |

This phase only classifies findings. Required fixes are applied later by the default or `fix` workflow. Recommended and Not needed findings are not applied by this skill.

## Integration output

For `my-pr review`, create the final response as the review comment. Optimize for the decisions a reviewer or fixer must make. Group findings by action (`Required`, then `Recommended`), not by severity. Sort findings within each action by severity: critical, high, medium, low.

The first line must identify the reviewed PR URL again, before the title or status. Read it from `.url` in `MY_PR_METADATA`. Do not reconstruct or guess it. If `MY_PR_CONTEXT_STATE=no_existing_pr`, write `Review URL: unavailable (no existing PR)` instead.

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
- Signal: `simplify`, `Claude`, `Codex`, or `multiple`

Keep severity in the finding heading. Do not include Confidence in the integrated output. Include `Severity source: integration-inferred` only when integration had to infer a missing severity; otherwise omit severity-source metadata.

Omit empty Required and Recommended sections. Summarize Not needed findings as a count under `Excluded / reference`; list an individual Not needed item only when recording why a potentially important finding was rejected prevents confusion. Do not emit empty severity sections.

If review is incomplete, output only:

```markdown
Review URL: <PR URL or unavailable (no existing PR)>

# Review result

## Decision
- Review status: REVIEW_INCOMPLETE
- Code assessment: unavailable

## Missing or failed inputs
- <reviewer/chunk/artifact>: <exact failure>

## Next step
- Stop before fixes, commits, pushes, or PR creation unless the user explicitly approves a degraded path.
```

If Reviewer B or any oversized file was skipped, use `COMPLETE_WITH_SKIPS`; otherwise use `COMPLETE`. A format-only Reviewer B skip does not add a retry request or `Next step` section.

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
- Not needed: <count> findings
```

Omit `Required`, `Recommended`, `Verification plan`, or `Excluded / reference` when the section has no content. For `NO_ACTION`, the Decision and PR overview are sufficient.
