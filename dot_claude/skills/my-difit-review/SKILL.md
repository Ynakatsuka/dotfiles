---
name: my-difit-review
description: |
  Fetch review comments left in a difit browser surface running inside cmux,
  then address them by modifying code. Use when the user asks to "difitのコメントを取得",
  "difitレビュー対応", "difit comments", "review comments取得", or similar.
  Do NOT use for general code review unrelated to difit, or when difit is not running.
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

# my-difit-review

Pull review comments from a difit instance hosted inside a cmux browser surface
and apply the requested fixes. difit stores comments in browser `localStorage`
under keys prefixed with `difit-storage-v1/`, so they are read via cmux's
`browser eval` API rather than HTTP.

Assumption: one difit surface per worktree. If more than one difit browser
surface is found, **warn the user** and list them — do not silently merge.

## Steps

1. **Locate difit browser surface(s)**

   ```bash
   /Applications/cmux.app/Contents/Resources/bin/cmux tree --all
   ```

   Find lines like `surface:NN [browser] "difit ..." ... http://localhost:PORT/`.
   Filter to surfaces whose URL contains `localhost` AND title contains `difit`.

   - 0 found → tell the user difit is not running and stop.
   - 1 found → proceed.
   - 2+ found → **warn**: "Multiple difit surfaces detected (expected one per
     worktree)." List each `surface:NN` with its title and URL, ask which one
     to target (or process all if the user confirms).

2. **Read comments from localStorage**

   ```bash
   /Applications/cmux.app/Contents/Resources/bin/cmux \
     browser --surface surface:NN \
     eval 'JSON.stringify(Object.fromEntries(Object.entries(localStorage).filter(([k])=>k.startsWith("difit-storage-v1/"))))'
   ```

   The result is a JSON object whose values are JSON strings. Each value
   parses to an object with shape:

   ```jsonc
   {
     "version": 2,
     "baseCommitish": "...",
     "targetCommitish": "...",
     "threads": [
       {
         "id": "...",
         "filePath": "CLAUDE.md",
         "position": { "side": "new", "line": 118 },
         "messages": [
           { "body": "comment text", "author": "User", "createdAt": "..." }
         ]
       }
     ]
   }
   ```

   Parse and flatten all threads across all storage entries.

3. **Present the comments**

   Group by `filePath`, sort by `position.line`. For each comment show:

   ```
   path/to/file.ext:LINE  (side=new|old)
     > comment body
   ```

   If there are zero threads, tell the user and stop.

4. **Determine the working directory**

   The difit surface lives in a cmux pane whose `cwd` is the repo to edit.
   Resolve via `cmux tree --all` (the pane title typically shows the cwd) or
   fall back to the user's current working directory if detection fails.
   `cd` into that directory before editing files.

5. **Address each comment**

   For each thread, read the referenced file (use `position.line` as the
   anchor — `side: "new"` means the post-change line, `side: "old"` means the
   pre-change line), understand the comment intent, then apply the fix with
   `Edit`.

   - If a comment is a question rather than an instruction, answer it in the
     chat instead of editing.
   - If multiple comments touch the same file, batch the reads but apply edits
     individually with precise `old_string` context.
   - After all edits, summarize what was changed per comment, e.g.
     `CLAUDE.md:118 — fixed: <one-line summary>`.

6. **Do not auto-commit.** Leave changes for the user to review unless they
   explicitly ask to commit.

## Notes

- difit comments are **not** exposed via HTTP; the only reliable read path is
  `cmux browser eval` against `localStorage`.
- The `--clean` flag in `difit-cmux` clears comments at startup, so always
  fetch *before* the user closes/restarts the difit pane.
- Storage key format: `difit-storage-v1/<sha>/<encoded-title>-<COMMITISH>`.
  Multiple keys can exist for the same surface (different diff modes); merge
  threads from all of them.
