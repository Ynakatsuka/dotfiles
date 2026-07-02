---
name: my-agent
description: >-
  Delegate tasks to an external CLI agent (OpenAI Codex, Google Gemini, or
  Claude Code) for second opinions or parallel execution. Use when the user
  explicitly mentions "codex", "gemini", or "claude" or asks to delegate work to one of them
  (e.g., "codexで実行", "codexに聞いて", "geminiで実行", "Geminiに聞いて",
  "claudeで実行", "Claudeに聞いて", "run with codex", "ask gemini",
  "ask claude"). Also use when the user mentions Claude's "fable" model alias
  for delegation or consultation (e.g., "fableで実行", "fableに相談",
  "Fableに聞いて", "ask fable").
  Do NOT use for general coding tasks that don't mention codex, gemini, claude, or fable.
argument-hint: "[codex|gemini|claude|fable] <task-description>"
---

# CLI Agent Runner

Delegate tasks to an external CLI agent from within Claude Code. Supports three providers plus Claude's explicit `fable` model alias:

- **codex** — OpenAI Codex CLI (`codex exec ...`)
- **gemini** — Google Gemini CLI (`gemini -p ...`)
- **claude** — Claude Code CLI (`claude -p ...`)
- **fable** — Claude Code CLI with explicit model alias (`claude --model fable -p ...`)

## Provider Selection

Pick the provider in this order:

1. User says "fable" / "Fable" / "fableに相談" / "Fableに聞いて" / asks to delegate or consult Claude Fable → `claude` with `--model fable`
2. User says "gemini" / "ジェミニ" / asks to delegate to Gemini → `gemini`
3. User says "claude" / "クロード" / asks to delegate to Claude → `claude`
4. User says "codex" / "コーデックス" → `codex`
5. **No explicit provider mentioned (default) → `codex`**

The first argument is treated as a provider only if it is exactly `codex`, `gemini`, or `claude`. If the first argument is exactly `fable`, use the `claude` provider with `--model fable` and treat the remaining arguments as the task prompt. Otherwise the entire argument string is the task prompt and `codex` is used. Do NOT ask the user which provider to use — pick `codex` and proceed.

The remaining arguments form the task prompt. For consultation phrasing such as "fableに相談して X" or "Fableに聞いて X", remove the consultation phrase and use `X` as the task prompt. Convert the user's request into a clear, self-contained prompt and include relevant file paths/context. If the user provides a literal prompt, pass it through directly.

## Common Notes (all providers)

- Always use the Bash tool with `timeout: 600000` (10 minutes); delegated tasks can take time.
- Do NOT hardcode model names as defaults — let each CLI's own default handle it so it stays current. Pass `--model fable` only when the user explicitly requests Fable.
- Output streams to stdout; capture or display results directly.
- For long-running tasks, warn the user that the delegate may take time.
- If the delegate fails, report the error and suggest the user run it interactively (`codex` / `gemini` / `claude`).

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

### Claude

**Before the first `claude -p` of the session, read `references/claude.md`.** It contains the non-interactive invocation rules and permission-mode guidance.

```bash
claude -p "<PROMPT>"

# With explicit Fable model alias
claude --model fable -p "<PROMPT>"
```

For permission modes, model override, structured output, troubleshooting, and more examples, read `references/claude.md`.
