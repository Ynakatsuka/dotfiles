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
- The answer arrives on stdout after roughly 10 to 60 seconds; progress goes to stderr. A non-zero
  exit means the delegation failed. Report the error instead of retrying with the same input.

## Working with the answer

- Treat the answer as a summary from another model. Confirm identifiers with a targeted search
  before relying on them.
- Line numbers in the answer are not reliable. Locate edit points with a bounded read.
- When the answer says the files lack the information, widen the file set or search instead of
  asking the same question again.

## Limits

- The reader cannot edit files or run commands.
- Delegation does not replace careful reasoning about subtle bugs. Read those sections yourself.
