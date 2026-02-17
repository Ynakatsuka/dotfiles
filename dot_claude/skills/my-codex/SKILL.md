---
name: my-codex
description: Delegate tasks to OpenAI Codex CLI using gpt-5.3-codex model. Use when the user wants to run a task with Codex, delegate coding work to Codex, get a second opinion from Codex, or explicitly mentions "codex". Triggers on requests like "codexで実行", "codexに聞いて", "codexでやって", "run with codex", "ask codex", or any task delegation to Codex CLI.
---

# Codex Runner

Delegate tasks to OpenAI Codex CLI (`gpt-5.3-codex` model) from within Claude Code.

## Invocation

Run Codex in non-interactive exec mode:

```bash
codex exec --model gpt-5.3-codex "<PROMPT>"
```

### With image input

```bash
codex exec --model gpt-5.3-codex -i path/to/image.png "<PROMPT>"
```

### Resume previous session

```bash
codex resume --last
```

## Prompt Construction

1. Convert the user's request into a clear, self-contained prompt for Codex
2. Include relevant file paths and context in the prompt
3. If the user provides a specific prompt, pass it through directly

### Examples

**Simple task:**
```bash
codex exec --model gpt-5.3-codex "Fix the type error in src/utils.ts"
```

**With context:**
```bash
codex exec --model gpt-5.3-codex "Add input validation to the login handler in src/auth/handler.py. Validate email format and password length (min 8 chars)."
```

**Code review:**
```bash
codex exec --model gpt-5.3-codex "Review the changes in the current branch compared to main. Focus on security issues and performance."
```

## Configuration

User's Codex config (`~/.codex/config.toml`):
- `approval_policy = "never"` (fully autonomous)
- `sandbox_mode = "danger-full-access"`
- `network_access = true`

These settings mean Codex runs without approval prompts. The `--model` flag overrides the config default to use `gpt-5.3-codex`.

## Notes

- Always use `exec` mode (non-interactive) since Claude cannot interact with Codex's TUI
- Output streams to stdout; capture or display results directly
- For long-running tasks, warn the user that Codex may take time
- If Codex fails, report the error and suggest the user run it interactively with `codex --model gpt-5.3-codex`
