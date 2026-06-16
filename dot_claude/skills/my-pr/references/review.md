# my-pr Review Prompts

Use this reference for the default, `review`, and `fix` command quality review stage.

This reference is read-only. It collects and integrates findings only. Do not edit files, run fix verification, commit, push, create/update a PR, or mark a PR ready while using this reference.

## Design principles

- Separate finding from filtering. Reviewers should surface potential issues with severity and confidence; integration decides what is Required, Recommended, or Not needed.
- Ask for coverage, not only high-severity findings. Do not let reviewers silently drop plausible bugs because they think they are not important enough.
- Keep scope explicit: review the full PR diff against the base branch, not only the latest simplify changes.
- Keep reviewer responsibilities separate. Simplify handles quality, duplication, and behavior-preserving micro-efficiency. Claude/Codex review correctness, security, performance regressions, and test risks.
- Require line references, problem detail, why it matters, evidence, and a concrete fix strategy for every finding.
- Treat AI review as assistive. Verify findings before changing code, and run targeted tests after fixes.
- Check cross-client and downstream impact when the repository has multiple clients, SDKs, entrypoints, or pipelines. Do not assume one client is the only consumer.

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
CHANGED_FILES=<git diff --name-only $BASE_BRANCH..HEAD>
DIFF_FILE=<path to full git diff patch when needed>
```

## Reviewer A: integrated simplify review

Read `references/simplify/overview.md`. Run integrated simplify in `review` mode. Default executor is `/my-agent codex` unless the user explicitly requested Claude/local execution.

Keep its output categories as-is:

- Required
- Recommended
- Not needed

## Reviewer B: Claude Code correctness review

Use an Agent with this prompt.

```text
<role>
You are a senior software engineer reviewing a pull request for correctness, security, and test risk.
</role>

<context>
Branch: <BRANCH>
Base branch: <BASE_BRANCH>
Changed files:
<CHANGED_FILES>
</context>

<scope>
Review the full branch diff against the base branch. Do not review only the latest simplify changes.
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

<finding_policy>
Report every plausible issue you find, including low-severity or uncertain findings. Do not filter for importance at this stage; integration will rank and filter. For each finding include severity and confidence.
</finding_policy>

<output_format>
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

## Reviewer C: Codex correctness review

Create the diff file in the same shell session that invokes Codex, and clean it up with `trap` so failures do not leave temporary files behind:

```bash
DIFF_FILE=$(mktemp -t my-pr-diff.XXXXXX.patch)
trap 'rm -f "$DIFF_FILE"' EXIT
git diff "$BASE_BRANCH"..HEAD > "$DIFF_FILE"
```

Run `/my-agent codex` with this prompt:

```text
Review the diff in <DIFF_FILE> as a senior software engineer.

Scope:
- Review the full branch diff against <BASE_BRANCH>.
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

Finding policy:
- Report every plausible issue you find, including low-severity or uncertain findings.
- Do not filter for importance at this stage. Integration will rank and filter.
- Include severity and confidence for each finding.

Output exactly this structure:

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

The `trap` removes the diff file after Codex finishes or fails.

## Integration rules

Deduplicate findings from simplify, Claude, and Codex. Put each finding in exactly one category.

| Final category | Criteria |
|---|---|
| Required | Confirmed correctness/security/data-loss/fallback/downstream/cross-client/contract/operations/performance issue; test gap for changed behavior that can hide a bug; behavior-preserving simplify Required |
| Recommended | Plausible but uncertain issue; design/API/schema/config change; approval-worthy operational design/config change; simplify Recommended; useful but approval-worthy test expansion |
| Not needed | Style preference; readability-only nit covered by no clear risk; false positive; issue outside this PR's scope |

This phase only classifies findings. Required fixes are applied later by the default or `fix` workflow. Recommended and Not needed findings are not applied by this skill.

## Integration output

```markdown
# Quality Review Result

## Required
1. **file:line** — issue and fix
   - Source: simplify | Claude | Codex | multiple
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Why required: reason

## Recommended
1. **file:line** — proposal
   - Source: simplify | Claude | Codex | multiple
   - Needs approval because: reason

## Not needed
- **file:line** — ignored finding and reason

## Verification plan
- Commands/tests to run after fixes
```
