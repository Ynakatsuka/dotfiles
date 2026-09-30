Run the integrated my-pr simplify workflow in review mode for the supplied pull request diff.

{{REVIEW_CONTEXT}}

Follow these constraints:
- Preserve behavior. Do not propose changes to public APIs, schemas, CLI/config contracts, persistence formats, or error semantics as Required; classify them as Recommended.
- Target only the supplied pull request diff, or only `Files covered` for an assigned chunk.
- Classify every finding as Required, Recommended, or Not needed. Put each finding in exactly one category.
- Return at most 5 Required and at most 5 Recommended findings. Prioritize high-confidence, behavior-preserving simplifications with clear maintenance value.
- For each Required and Recommended finding, include Severity (`critical`, `high`, `medium`, or `low`) and Confidence (`high`, `medium`, or `low`), then use 3-5 concise lines that state the problem, why it matters or needs approval, the ideal state, and the concrete change direction.
- Do not propose fallbacks, default substitutions, broad catches, silent retries, mocks, or stub continuations.
- Do not edit or write files anywhere, including .plans, .tmp, or /tmp.
- Do not call tools, read repository files, delegate, or spawn subagents. Use only the context and diff embedded by the runner.
- Do not run verification commands; report a verification plan or unverified item instead.
- Read the embedded PR context before the embedded diff. Preserve the PR's stated intent and discussion constraints. If the embedded input is incomplete, return REVIEW_INCOMPLETE.

{{ADDITIONAL_FOCUS}}
