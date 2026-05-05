# my-pr Review Prompts

Use this reference for the default and `review` command quality review stage.

## Design principles

- Separate finding from filtering. Reviewers should surface potential issues with severity and confidence; integration decides what is Required, Recommended, or Not needed.
- Ask for coverage, not only high-severity findings. Do not let reviewers silently drop plausible bugs because they think they are not important enough.
- Keep scope explicit: review the full PR diff against the base branch, not only the latest simplify changes.
- Keep reviewer responsibilities separate. Simplify handles quality, duplication, and efficiency. Claude/Codex review correctness, security, and test risks.
- Require line references, concrete impact, evidence, and a fix suggestion for every finding.
- Treat AI review as assistive. Verify findings before changing code, and run targeted tests after fixes.

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
2. Security issues, secret leakage, injection, unsafe shell usage, and authorization mistakes
3. Missing or weak tests for changed behavior
</scope>

<out_of_scope>
Code quality, duplication, naming style, formatting, and efficiency are handled separately by integrated simplify. Do not report style preferences, pure readability nits, generated files, lockfiles, vendored dependencies, snapshots, or issues already enforced by CI unless the diff creates a concrete correctness or security risk.
</out_of_scope>

<finding_policy>
Report every plausible issue you find, including low-severity or uncertain findings. Do not filter for importance at this stage; integration will rank and filter. For each finding include severity and confidence.
</finding_policy>

<output_format>
## Findings

1. **file:line** — short title
   - Category: correctness | security | tests
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Impact: what can break or become unsafe
   - Evidence: why this follows from the diff/code
   - Suggested fix: concrete fix direction
   - Verification: test or command that should catch this

## Non-findings
- Optional: notable risks inspected but not reported, with reason.
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
- Focus on correctness bugs, edge cases, data loss, race conditions, security issues, unsafe shell usage, secret leakage, authorization mistakes, and missing tests.
- Do not report code quality, duplication, naming style, formatting, or efficiency issues; integrated simplify handles those separately.
- Do not report issues already enforced by CI, generated files, lockfiles, vendored dependencies, snapshots, or preference-only nits unless the diff creates a concrete correctness or security risk.

Finding policy:
- Report every plausible issue you find, including low-severity or uncertain findings.
- Do not filter for importance at this stage. Integration will rank and filter.
- Include severity and confidence for each finding.

Output exactly this structure:

## Findings

1. **file:line** — short title
   - Category: correctness | security | tests
   - Severity: critical | high | medium | low
   - Confidence: high | medium | low
   - Impact: what can break or become unsafe
   - Evidence: why this follows from the diff/code
   - Suggested fix: concrete fix direction
   - Verification: test or command that should catch this

## Non-findings
- Optional: notable risks inspected but not reported, with reason.
```

The `trap` removes the diff file after Codex finishes or fails.

## Integration rules

Deduplicate findings from simplify, Claude, and Codex. Put each finding in exactly one category.

| Final category | Criteria |
|---|---|
| Required | Confirmed correctness/security/data-loss issue; test gap for changed behavior that can hide a bug; behavior-preserving simplify Required |
| Recommended | Plausible but uncertain issue; design/API/schema/config change; simplify Recommended; useful but approval-worthy test expansion |
| Not needed | Style preference; readability-only nit covered by no clear risk; false positive; issue outside this PR's scope |

Required fixes can be applied automatically when they do not change public contracts or intended behavior. Recommended fixes require user approval. Not needed findings are not applied.

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
