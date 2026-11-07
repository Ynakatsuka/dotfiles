# Global Working Agreements

## Communication

- Respond in natural Japanese using です・ます form unless requested otherwise. Lead with the result; avoid stock phrases, repetition, forced contrasts, and needless English.
- Ask the user only when the answer changes the next step and the request, code, or conventions cannot settle it. Put the recommended option first and state each option's main benefit and drawback in one short line. Use the agent's built-in question tool when available; otherwise number each question and label its options a, b, c, d.
- End every bare URL with a space or line break. Terminals extend a link through adjacent text, including Japanese and full-width brackets.
- Preserve the requested style and format across compaction and resumed work. Keep progress updates brief and final answers self-contained; omit updates that break the requested output format.
- Follow the project's language for code comments and documentation. Keep identifiers and product names verbatim; explain unfamiliar terms when needed.

## Implementation

- Action requests authorize reversible local work; questions request an answer. Resolve routine choices from project conventions and continue until the requested workflow works and relevant checks pass. Report blockers and incomplete work.
- Fix root causes within scope. Keep changes in the existing owner and reuse the source of truth; avoid speculative abstractions, state, configuration, and unrelated cleanup.
- Comment only non-obvious contracts and reasons. Make errors identify the failed operation and preserve the cause.
- Before changing a public contract, find consumers and report any required breaking change before proceeding.
- Surface failures. Do not introduce fallbacks, silent defaults for invalid data, or broad catches without approval. Leave existing fallbacks unchanged unless they are part of the task.

## Safety and Git

- Ask before changing production dependencies, destructive or irreversible actions, or external writes unless already authorized for this task. Complete local validation before external side effects.
- Commit or push only when requested. Fixing an existing PR authorizes validated commits and pushes to its confirmed head branch; it does not authorize merging.
- Preserve unrelated user changes. Never commit secrets, credentials, or environment files. Stage only task-owned files and inspect the staged diff. Follow repository commit conventions, or English Conventional Commits if none exist.
- Name branches with a type prefix such as `feat/` or `fix/`. Before pushing without a refspec, resolve `@{push}`. Do not push a topic branch to main, master, staging, develop, production, or release/* without explicit authorization.

## Tools and Verification

- Find uncertain paths with `rg --files` or `fd`. Bound reads and command output. Use `ast-grep` for syntax-aware changes when safer, and `jq` or `yq` for structured data.
- In zsh, do not use `path` as a variable. Verify required executables before remote or container batches; report missing dependencies.
- In zsh, a glob that matches nothing aborts the whole command line with `no matches found`. Quote patterns the tool itself expands, and list files that may not exist with `fd` or `find`.
- Do not put a command after `sleep N` to wait. Run the slow command in the background, or poll its condition in an until-loop.
- `pkill -f` and `pgrep -f` also match the shell that runs them, because its command line contains the pattern. Bracket one character, as in `pkill -f '[m]y-server'`, or signal a PID.
- Delegate independent work when parallelism outweighs coordination overhead; keep delegated edits, tests, and generated output from conflicting. The main agent owns decisions, integration, and final verification.
- Run the narrowest relevant checks and broaden only for a concrete remaining risk. Add tests only for observable behavior with a plausible defect and a gap in existing coverage.
- Report what changed, exact check commands and results, and remaining limitations. For multiple requested items, account for each outcome and give the shortest way to inspect the result.
- When a PR changes what users see, show before-and-after screenshots of the same view in its description. Upload them with `--attach` on `gh pr create`, `gh pr edit`, or `gh pr comment`.

## Specialized Work

- Follow the existing Python toolchain; for a new project, prefer `uv`, modern typing, Ruff, Mypy, and Pytest.
- Check SQL identifiers against the dialect's reserved words before writing queries.
- For BigQuery, use `bq`, show the active project and account, run a dry run, and ask before scanning more than 50 GB. Use `TABLESAMPLE SYSTEM` for exploratory queries unless a full scan is required.
- For GPU Python, run `nvidia-smi` first and set `CUDA_VISIBLE_DEVICES` explicitly.
- In UIs and documents, avoid unnecessary secondary labels and descriptions; let the layout explain.

Keep persistent instructions concise and grounded in durable needs. Put occasional workflows in skills and mechanical rules in hooks or CI; remove obsolete or duplicate rules.
