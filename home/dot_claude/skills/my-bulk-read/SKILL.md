---
name: my-bulk-read
description: >-
  Delegate reading large or multiple files to the `bulk-read` command, which sends the files to a
  cheaper reader model and returns only its answer. Use when a question needs the content of a file
  over about 350 lines or of several files at once, when a PreToolUse guard denied an unbounded
  read, or when the user says "bulk read", "一括読み込み", or "まとめて読んで". Do NOT use for
  files you are about to edit, for subtle correctness reasoning such as concurrency bugs, or for
  short files that fit a bounded read.
---

# Bulk Read Delegation

## When to delegate

- A question about what a file or module does, where something is defined, or how a flow works,
  and the answer does not need exact line numbers.
- Several related files must be understood together.
- The guard denied an unbounded read of a large file.

Keep reading directly with a bounded range (`offset` and `limit`, `sed -n 'A,Bp'`) or a search
(`rg -n`) when you need exact lines for an edit or a search can locate the section.

## Command

```bash
bulk-read --question "<one precise question>" <file>...
```

- Ask one specific question per call and name the identifiers or behavior you need. Vague
  questions return vague summaries.
- Pass only the files the question needs. Each file is sent verbatim.
- The answer arrives on stdout; startup information goes to stderr. Runtime depends on input
  size and reasoning. Silence is not evidence of completion or failure. A non-zero exit means
  the delegation failed. Report the error instead of retrying with the same input.

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
- Do independent work while the reader runs, but check its result at the next tool boundary.
  When its answer is the only remaining dependency, keep collecting directly without an
  extra delay. Once the exit code and answer arrive, consume them and stop waiting.
- In Claude Code, collect a background Bash task with `TaskOutput` using its returned task ID;
  a finished task's output should be read immediately rather than waiting for another notification.

## Working with the answer

- Treat the answer as a summary from another model. Confirm identifiers with a targeted search
  before relying on them.
- Line numbers in the answer are not reliable. Locate edit points with a bounded read.
- When the answer says the files lack the information, widen the file set or search instead of
  asking the same question again.

## Limits

- The reader cannot edit files or run commands.
- Delegation does not replace careful reasoning about subtle bugs. Read those sections yourself.
