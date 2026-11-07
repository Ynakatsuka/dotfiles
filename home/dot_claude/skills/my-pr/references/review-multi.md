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

Verify these executors before launch: `scripts/run-codex-reviews.sh`, `scripts/prepare-reviewer-b-input.sh`, `scripts/validate-reviewer-b-output.sh`, plus `scripts/run-claude-review.sh` and its Claude CLI prerequisites (`claude`, `jq`, `git`) on every host.

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

### Reviewer B

Reviewer B always runs through `scripts/run-claude-review.sh`, on every host including Claude Code. Do not launch the `my-pr-reviewer` Agent: its prompt would have to carry the whole `input.md` (900-3,400 lines), and the global read guard denies unbounded `Read` and `cat` of files over 350 lines. Never `Read`, `cat`, or retype `input.md`, hashes, or any other value the scripts already print.

The wrapper builds the self-contained input itself (it calls `prepare-reviewer-b-input.sh`, which embeds the complete PR context and diff and applies the same 393,216-byte prompt ceiling as the Codex runners), runs Claude, and prints the absolute review Markdown path. Pass literal artifact paths:

```bash
bash "$HOME/.claude/skills/my-pr/scripts/run-claude-review.sh" \
  "full" "1" \
  "/absolute/artifact/path/correctness-review-prompt.md" \
  "/absolute/artifact/path/pr-context.md" \
  "/absolute/artifact/path/review.diff"
```

To inspect the prompt without running Reviewer B, run `prepare-reviewer-b-input.sh` with the same arguments and look at its head or specific ranges with bounded reads (`offset`/`limit`) or `rg`.

### Launch mechanics

Concurrency across A and C is enforced by `scripts/run-codex-reviews.sh`. Concurrency with Reviewer B is not enforced, so order the launch deliberately.

In a Claude Code session with the Bash tool, issue every call in one response:

- One `run-claude-review.sh` call per chunk with `run_in_background: true`. Its completion notification re-invokes you; do not poll on a short interval.
- One `run-codex-reviews.sh` call per chunk, each with an explicit `timeout` of `600000` ms. The default Bash timeout is 120,000 ms and can kill a healthy Codex review mid-run. Because the wrapper runs A and C concurrently, its wall clock is the slower reviewer, not their sum.
- A timeout kill is an execution failure, not a format failure. It produces `REVIEW_INCOMPLETE` and cannot be retried without explicit user approval, so set the timeout before launching rather than recovering afterward.
- If a chunked A/C run needs more than the 600,000 ms ceiling, also use `run_in_background` and wait for its completion notification.
- Read the printed review path only after every notification has arrived.

In a Codex or other non-Claude host:

- Start `run-codex-reviews.sh` in the background first, capturing its PID and redirecting stdout/stderr to files under the artifact directory.
- Run `run-claude-review.sh` for each chunk, also in the background with output under the artifact directory, then wait on all of them and read their captured output before integration.
- If this host cannot execute concurrent tasks at all, report that limitation before starting review instead of silently serializing.

## Reviewer B executor and output

- Use only `scripts/run-claude-review.sh`. It launches `claude -p` with `--model opus`, `--effort high`, `--tools ""`, safe mode, an empty MCP configuration, an isolated artifact-local Git repository, and the complete generated input on stdin. Do not invoke the Claude CLI directly and do not substitute the `my-pr-reviewer` Agent.
- Use the review path printed by the wrapper (`<artifact-dir>/reviewer-results/reviewer-b/<chunk-id>/review.md`); it extracts only `structured_output.review_markdown` from the final `stream-json` result event. Do not make Reviewer B inherit `MY_PR_ARTIFACT_DIR`, and do not use an interim message, handoff summary, or shortened recap as the reviewer body.
- Validate every Reviewer B Markdown file with `bash "$HOME/.claude/skills/my-pr/scripts/validate-reviewer-b-output.sh" "/absolute/path/to/reviewer-b-review.md"` before integration.
- The wrapper exits non-zero when the final result event is missing or `permission_denials` is non-empty. Return `REVIEW_INCOMPLETE` and stop before integration if that happens, the command is unavailable, authentication is missing, permissions fail, the command times out, or Reviewer B reports that the diff/context was inaccessible.
- Do not invoke `/my-agent claude` from inside a delegated Claude session unless the user explicitly requested nested delegation.
- Pin Reviewer B to Claude Opus at `high` effort. Do not inherit the configured default model or effort and do not allow the global session effort to override this profile.

If Reviewer B completes its review but `validate-reviewer-b-output.sh` rejects the Markdown, skip the entire Reviewer B family, record the exact validation failure, and integrate Reviewer A/C. The wrapper runs with `--no-session-persistence`, so a format-only correction in the same session is impossible; do not rerun the wrapper and do not replace Claude review with Codex or local review. This format-only skip is an explicitly approved degraded path and does not produce `REVIEW_INCOMPLETE`.

If the wrapper exits non-zero, lacks quota or authentication, times out, cannot read the diff/context artifact, or explicitly reports incomplete input, stop before integration. These execution and input failures are not format-only failures.
