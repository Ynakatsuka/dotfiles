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
---

# CLI Agent Runner

Delegate a task to an external CLI agent:

- **codex** — OpenAI Codex CLI (`codex exec`)
- **gemini** — Google Antigravity CLI (`agy -p`)
- **claude** — Claude Code CLI (`claude -p`)

## Provider Selection

1. "fable" / "Fable" / asks to consult Claude Fable → `claude --model fable -p`. Pass the alias `fable` verbatim; do not expand it to a dated model ID.
2. "gemini" / "ジェミニ" → `gemini`
3. "claude" / "クロード" → `claude`
4. "codex" / "コーデックス", or no provider named → `codex`. Do not ask which provider to use.

Treat the first argument as a provider only when it is exactly `codex`, `gemini`, `claude`, or `fable`; otherwise the whole argument string is the task prompt. Strip consultation phrasing such as "fableに相談して X" down to `X`. Turn the request into a self-contained prompt with the relevant file paths and context; pass a literal prompt through unchanged.

## Common Notes

- Run delegates with a 10-minute shell timeout.
- Do not hardcode default models; omit `--model` so each CLI's own default stays current. Add it only when the user names a model.
- If the delegate fails, report the error and suggest the user run it interactively (`codex` / `agy` / `claude`).

## Codex

```bash
codex exec "<PROMPT>" </dev/null
```

`codex exec` reads stdin whenever stdin is not a terminal, so always redirect it. For Chrome operation, Computer Use, or Slack posts, use `codex-task` as the Claude instructions require instead. For long prompts, image input, resume, and model override, read `references/codex.md`.

## Gemini

Before the first `agy -p` of the session, read `references/gemini.md` for preflight, sandbox, and plan-mode rules.

```bash
agy --sandbox --disable-slash-commands -p "<PROMPT>"
```

## Claude

Before the first `claude -p` of the session, read `references/claude.md` for permission-mode rules.

```bash
claude -p "<PROMPT>"
```
