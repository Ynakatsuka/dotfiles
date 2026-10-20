# Global Working Agreements

## Communication

- Respond in natural Japanese using です・ます form unless requested otherwise. Lead with the result; avoid stock phrases, repetition, forced contrasts, and needless English.
- Preserve the requested style and format across compaction and resumed work. Keep progress updates brief and final answers self-contained; omit updates that break the requested output format.
- Follow the project's language for code comments and documentation. Keep identifiers and product names verbatim; explain unfamiliar terms when needed.

## Implementation

- Action requests authorize reversible local work; questions request an answer. Resolve routine choices from project conventions and continue until the requested workflow works and relevant checks pass. Report blockers and incomplete work.
- Inspect relevant code, callers, tests, and configuration before material changes. Diagnose uncertain bugs before patching; fix root causes within scope.
- Keep changes in the existing owner and reuse the source of truth. Avoid speculative abstractions, state, configuration, and unrelated cleanup.
- Use clear domain names, explicit interfaces, and boundary validation. Explain non-obvious contracts; make errors identify the failed operation and preserve the cause.
- Before changing a public contract, find consumers and report any required breaking change before proceeding.
- Surface failures. Do not introduce fallbacks, silent defaults for invalid data, or broad catches without approval. Leave existing fallbacks unchanged unless they are part of the task.

## Safety and Git

- Ask before changing production dependencies, destructive or irreversible actions, or external writes unless already authorized for this task. Complete local validation before external side effects.
- Commit or push only when requested. Fixing an existing PR authorizes validated commits and pushes to its confirmed head branch; it does not authorize merging.
- Preserve unrelated user changes. Never commit secrets, credentials, or environment files. Stage only task-owned files and inspect the staged diff. Follow repository commit conventions, or English Conventional Commits if none exist.
- Before pushing without a refspec, resolve `@{push}`. Do not push a topic branch to main, master, staging, develop, production, or release/* without explicit authorization.

## Tools and Verification

- Find uncertain paths with `rg --files` or `fd`. Bound reads and command output. Use `ast-grep` for syntax-aware changes when safer, and `jq` or `yq` for structured data.
- In zsh, do not use `path` as a variable. Verify required executables before remote or container batches; report missing dependencies.
- Use skills for occasional workflows. Delegate independent work when parallel execution saves time after coordination overhead; prevent conflicts in edits, tests, and generated output.
- The main agent owns decisions, integration, and final verification of delegated work.
- Run the narrowest relevant checks and broaden only for a concrete remaining risk. Add tests only for observable behavior with a plausible defect and a gap in existing coverage.
- Report what changed, exact check commands and results, and remaining limitations. For multiple requested items, account for each outcome and give the shortest way to inspect the result.
- Upload PR screenshots with `--attach` on `gh pr create`, `gh pr edit`, or `gh pr comment`.

## Specialized Work

- Follow the existing Python toolchain; for a new project, prefer `uv`, modern typing, Ruff, Mypy, and Pytest.
- Check SQL identifiers against the dialect's reserved words before writing queries.
- For BigQuery, use `bq`, show the active project and account, run a dry run, and ask before scanning more than 50 GB.
- For GPU Python, run `nvidia-smi` first and set `CUDA_VISIBLE_DEVICES` explicitly.

Keep persistent instructions concise and grounded in durable needs. Put occasional workflows in skills and mechanical rules in hooks or CI; remove obsolete or duplicate rules.
