---
name: my-code-write
description: >-
  Delegate writing predictable code to the `code-write` command, which has a cheaper writer model
  write the target file directly so the generated code never enters your context. Use for tests,
  scaffolding, fixtures, boilerplate, or a new file that copies an existing pattern, and when the
  user says "code write", "生成を委譲", or "雛形を書かせて". Do NOT use for design decisions,
  changes to public contracts or shared modules, edits inside an existing file that needs
  judgment, or logic with subtle correctness requirements.
---

# Code Write Delegation

## When to delegate

- The result follows a pattern that an existing file already shows: a test for another module,
  a handler or model shaped like a sibling, a fixture, or a scaffold.
- The spec can be stated completely up front, including the file path, the behavior, and the
  reference file to imitate.
- The file is new or is owned entirely by this task, so a full rewrite is acceptable.

Write the code yourself when the change needs a design decision, touches a public contract, or
must be woven into an existing file with judgment.

## Command

```bash
code-write --spec "<complete spec>" --target <file> [--reference <file>]...
```

- State the spec completely: what to cover, names to use, framework, and edge cases. The writer
  cannot ask questions.
- Pass one or two reference files that show the exact pattern to copy. Each is sent verbatim.
- The target must be inside the current working directory. An existing target is sent to the
  writer and rewritten as a whole.
- Stdout carries the written path with its line count and a short summary; stderr carries
  progress. A non-zero exit means nothing usable was written. Report the error instead of
  retrying with the same input.

## Collecting completion

- This command is a shell process, not a `spawn_agent` task. Do not use `wait_agent`,
  `clock.sleep`, or shell `sleep` to wait for its result, and do not rely on a completion notification.
- In Codex, when `exec_command` returns a `session_id`, collect output with `write_stdin`
  using that ID and empty `chars`. Use `yield_time_ms: 1000` while waiting for this result;
  repeat while a `session_id` remains, until an `exit_code` and the final output arrive.
  The tool may enforce a longer minimum wait, but returns early when the process finishes.
- `functions.exec` saying `Script completed` only ends the JavaScript wrapper. An inner
  `session_id` still needs collection. If the wrapper instead yields a running `cell_id`,
  resume it with `functions.wait` and `yield_time_ms: 1000`, then inspect the inner result.
- Do independent work while the writer runs, but check its result at the next tool boundary.
  When its result is the only remaining dependency, keep collecting directly without an
  extra delay. Once the exit code and summary arrive, proceed to verification and stop waiting.
- In Claude Code, collect a background Bash task with `TaskOutput` using its returned task ID;
  a finished task's output should be read immediately rather than waiting for another notification.
- A target file appearing or changing is not proof of completion. Collect the command's
  exit status before reading, editing, or testing the target.

## After the write

- Run the narrowest relevant check on the target, such as the new test file or the linter, instead
  of reading the file to review it.
- Confirm with `git status` that only the target changed.
- When a check fails, read the failing region with a bounded range and fix it yourself, or re-run
  once with a more precise spec. Do not loop on the writer.
