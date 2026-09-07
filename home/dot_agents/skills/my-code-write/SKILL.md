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

## After the write

- Run the narrowest relevant check on the target, such as the new test file or the linter, instead
  of reading the file to review it.
- Confirm with `git status` that only the target changed.
- When a check fails, read the failing region with a bounded range and fix it yourself, or re-run
  once with a more precise spec. Do not loop on the writer.
