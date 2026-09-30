# my-pr Multi-reviewer Review

Read this reference only when `references/review.md` Reviewer selection chose A/B/C. It covers large-diff chunking, concurrent launch, and the Reviewer A/B specifics. Everything in `references/review.md` still applies.

## Large diff chunking

Use the full `MY_PR_REVIEW_DIFF` unless a chunking condition in `references/review.md` Reviewer selection applies. Changed file count alone is not enough to chunk. Prefer one full-diff review when the artifact is readable within limits.

Chunk rules:

1. Group files by subsystem or top-level directory.
2. Keep each chunk at or below 196,608 bytes. Line count is not a safety bound because Markdown and generated content can contain long lines.
3. Generate chunk artifacts with `bash "$HOME/.claude/skills/my-pr/scripts/split-review-chunks.sh" "/absolute/path/to/artifact.env"`. The script loads the base ref from that state file, packs complete file diffs, writes `Chunk id`, `Files covered`, and `Files not covered` into each chunk, verifies reviewable-file coverage, persists chunk paths back to the state file, and is compatible with macOS Bash 3.2.
4. Reuse the same generated role prompts for every chunk. The chunk metadata inside each chunk diff tells the reviewer its assigned portion.
5. Integration must list all chunks for Reviewer A/C and stop if any is missing, failed, or inaccessible. If any Reviewer B chunk remains structurally invalid after format correction, skip the entire Reviewer B family instead of integrating partial B coverage. Also list every skipped file with its byte count and state that those files were not reviewed.

Integration, not any one chunk, establishes full coverage from the manifest and all completed chunk results.

The script reserves 8,192 bytes per chunk for metadata. If one complete file diff exceeds the remaining payload limit, skip only that file, record it in `MY_PR_SKIPPED_FILES` and `MY_PR_SKIPPED_FILE_SUMMARY`, and continue reviewing the remaining files. Do not split in the middle of a file or treat a skipped file as reviewed. If a generated prompt exceeds 393,216 bytes, stop before launching that reviewer.

If every changed file is skipped, do not launch empty reviewer runs. Return a review result that lists every skipped file and clearly states that no file content was reviewed.

Each Reviewer A run or chunk reports at most 5 Required and at most 5 Recommended findings. Integration deduplicates simplify findings across chunks.

## Launch

Verify these executors before launch: `scripts/run-codex-reviews.sh`, `scripts/prepare-reviewer-b-input.sh`, `scripts/validate-reviewer-b-output.sh`, plus the configured `my-pr-reviewer` Agent in Claude Code or `scripts/run-claude-review.sh` and its Claude CLI prerequisites on other hosts.

Launch Reviewer A, Reviewer B, and Reviewer C concurrently. All three reviewers must use the same full-diff input or the same chunk manifest. Process each reviewer's assigned chunks without nested delegation. Do not run the three reviewer families sequentially unless the environment cannot execute concurrent tasks; if concurrency is unavailable, report that limitation before starting review. Wait for all launched reviewer and chunk results before integration.

Reviewer A uses the generated `simplify-review-prompt.md`. Reviewers B and C both use the generated `correctness-review-prompt.md`.

### Reviewer A and C

Launch A and C for each chunk through `scripts/run-codex-reviews.sh`, which starts the two `run-codex-review.sh` processes concurrently and waits for both. Use literal values from the state file or chunk manifest; do not rely on shell variables inherited from orchestration:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/run-codex-reviews.sh" \
  "full" "1" \
  "/absolute/artifact/path/simplify-review-prompt.md" \
  "/absolute/artifact/path/correctness-review-prompt.md" \
  "/absolute/artifact/path/pr-context.md" \
  "/absolute/artifact/path/review.diff"
```

It prints one `<reviewer>\t<absolute review Markdown path>` line per reviewer. Use those files as reviewer output. Never use a partial stdout/stderr log as review output. Do not retry a failed chunk or switch executors unless the user explicitly approves it.

If either reviewer fails, the wrapper reports which one, echoes that reviewer's stderr, prints no result paths, and exits non-zero. Treat that as `REVIEW_INCOMPLETE`; do not integrate the reviewer that happened to succeed.

In A/B/C mode, run `run-codex-review.sh` directly only for a single-reviewer relaunch explicitly approved by the user. The argument order differs: `<reviewer-a|reviewer-c> <chunk-id> <chunk-count> <prompt> <context> <diff>`.

Reviewer A runs the configured Codex model at `medium` effort; the runner appends the required `# Simplify Review` output structure. It must not propose simplifications that conflict with the PR's stated problem, constraints, or resolved discussion. If Codex fails, times out, lacks quota, rejects the config override, or cannot read the artifact, return `REVIEW_INCOMPLETE` and stop. Do not silently switch to Claude/local execution.

### Reviewer B input

Build one self-contained input per chunk:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/prepare-reviewer-b-input.sh" \
  "full" "1" \
  "/absolute/artifact/path/correctness-review-prompt.md" \
  "/absolute/artifact/path/pr-context.md" \
  "/absolute/artifact/path/review.diff"
```

The script embeds the complete PR context and diff, applies the same 393,216-byte prompt ceiling as the Codex runners, and prints the absolute `input.md` path. Use that file as the only Reviewer B task input. Do not replace it with artifact paths or current repository state.

### Launch mechanics by host

Concurrency across A and C is enforced by `scripts/run-codex-reviews.sh`. Concurrency with Reviewer B is not enforced, so order the launch deliberately.

In a Claude Code session with the Agent tool:

- Read the complete generated Reviewer B `input.md`, then launch the configured `my-pr-reviewer` Agent with that content as its prompt. Do not invoke a generic Agent and do not add artifact paths, repository-reading instructions, or tools.
- `my-pr-reviewer` fixes the model to Opus, effort to `high`, available tools to none, and background execution to true. Launch every Reviewer B chunk in the same response so chunked reviews overlap.
- Then call `run-codex-reviews.sh` once per chunk. Issue every chunk call in the same response; never await one chunk before issuing the next.
- Give each `run-codex-reviews.sh` call an explicit `timeout` of `600000` ms. The default Bash timeout is 120,000 ms and can kill a healthy Codex review mid-run. Because the wrapper runs A and C concurrently, its wall clock is the slower reviewer, not their sum.
- A timeout kill is an execution failure, not a format failure. It produces `REVIEW_INCOMPLETE` and cannot be retried without explicit user approval, so set the timeout before launching rather than recovering afterward.
- If a chunked run needs more than the 600,000 ms ceiling, launch the wrapper with `run_in_background` and wait for its completion notification. Do not poll on a short interval.

In a Codex or other non-Claude host, Reviewer B runs through the bundled Claude CLI wrapper:

- Start `run-codex-reviews.sh` in the background first, capturing its PID and redirecting stdout/stderr to files under the artifact directory.
- Run `scripts/run-claude-review.sh` with the same chunk id, count, correctness prompt, context, and diff. The wrapper builds the embedded input itself and blocks until Reviewer B returns.
- For multiple chunks, background every A/C wrapper and Reviewer B wrapper before waiting. Keep each process's stdout/stderr under the artifact directory.
- After Reviewer B returns, wait on the backgrounded wrappers and read their captured output before integration.
- If this host cannot execute concurrent tasks at all, report that limitation before starting review instead of silently serializing.

## Reviewer B executor and output

- In a Claude Code session with the Agent tool available, use only the configured `my-pr-reviewer` Agent and pass the complete generated `input.md` as its prompt.
- In a Codex or other non-Claude host session, use `scripts/run-claude-review.sh`. It launches `claude -p` with `--model opus`, `--effort high`, `--tools ""`, safe mode, an empty MCP configuration, an isolated artifact-local Git repository, and the complete generated input on stdin. Do not invoke Claude CLI directly.
- For Agent output, have the main orchestrator save the final response verbatim to the exact `<artifact-dir>/reviewer-results/reviewer-b/<chunk-id>/review.md` path. For CLI output, use the review path printed by `run-claude-review.sh`; the wrapper extracts only `structured_output.review_markdown` from the final `stream-json` result event. Do not make Reviewer B inherit `MY_PR_ARTIFACT_DIR`, and do not use an interim message, handoff summary, or shortened recap as the reviewer body.
- Validate every Reviewer B Markdown file with `bash "$HOME/.claude/skills/my-pr/scripts/validate-reviewer-b-output.sh" "/absolute/path/to/reviewer-b-review.md"` before integration.
- If the final result event is missing, `permission_denials` is non-empty, the command is unavailable, authentication is missing, permissions fail, the command times out, or Reviewer B reports that the diff/context was inaccessible, return `REVIEW_INCOMPLETE` and stop before integration.
- Do not invoke `/my-agent claude` from inside a delegated Claude session unless the user explicitly requested nested delegation.
- Pin Reviewer B to Claude Opus at `high` effort. Do not inherit the configured default model or effort and do not allow the global session effort to override this profile.

If Reviewer B completes its review but `validate-reviewer-b-output.sh` rejects the final Markdown, request one format-only correction in the same Agent conversation or CLI session. Tell Reviewer B to re-emit its already completed review using the exact output format, without rereading files, calling tools, changing findings, or returning a summary. Validate the corrected body once.

If the corrected body is still invalid, skip the entire Reviewer B family, record the exact validation failure, and integrate Reviewer A/C. Do not retry again and do not replace Claude review with Codex or local review. This format-only skip is an explicitly approved degraded path and does not produce `REVIEW_INCOMPLETE`.

If the Claude Agent or CLI exits non-zero, lacks quota or authentication, times out, cannot read the diff/context artifact, or explicitly reports incomplete input, stop before integration. These execution and input failures are not format-only failures.
