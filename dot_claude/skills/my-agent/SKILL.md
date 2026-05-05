---
name: my-agent
description: >-
  Delegate tasks to an external CLI agent (OpenAI Codex or Google Gemini) for
  second opinions or parallel execution. Use when the user explicitly mentions
  "codex" or "gemini" or asks to delegate work to one of them
  (e.g., "codexで実行", "codexに聞いて", "geminiで実行", "Geminiに聞いて",
  "run with codex", "ask gemini").
  Do NOT use for general coding tasks that don't mention codex or gemini.
argument-hint: "[codex|gemini] <task-description>"
---

# CLI Agent Runner

Delegate tasks to an external CLI agent from within Claude Code. Supports two providers:

- **codex** — OpenAI Codex CLI (`codex exec ...`)
- **gemini** — Google Gemini CLI (`gemini -p ...`)

## Provider Selection

Pick the provider in this order:

1. User says "gemini" / "ジェミニ" / asks to delegate to Gemini → `gemini`
2. User says "codex" / "コーデックス" → `codex`
3. **No explicit provider mentioned (default) → `codex`**

The first argument is treated as a provider only if it is exactly `codex` or `gemini`; otherwise the entire argument string is the task prompt and `codex` is used. Do NOT ask the user which provider to use — pick `codex` and proceed.

The remaining arguments form the task prompt. Convert the user's request into a clear, self-contained prompt and include relevant file paths/context. If the user provides a literal prompt, pass it through directly.

## Common Notes (both providers)

- Always use the Bash tool with `timeout: 600000` (10 minutes); delegated tasks can take time.
- Do NOT hardcode model names — let each CLI's own default handle it so it stays current.
- Output streams to stdout; capture or display results directly.
- For long-running tasks, warn the user that the delegate may take time.
- If the delegate fails, report the error and suggest the user run it interactively (`codex` / `gemini`).

## Quick Reference

### Codex

```bash
codex exec "<PROMPT>"
```

For image input, model override, resume, configuration details, and more examples, read `references/codex.md`.

### Gemini

**Before the first `gemini -p` of the session, read `references/gemini.md`.** It contains the mandatory preflight (env var + credential file check) and the `--skip-trust` requirement; skipping either causes immediate failure or an indefinite hang.

```bash
gemini --skip-trust -y -p "<PROMPT>"
```

For approval modes, structured output, model override, troubleshooting, and more examples, read `references/gemini.md`.
