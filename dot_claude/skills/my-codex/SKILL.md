---
name: my-codex
description: >-
  Delegate tasks to OpenAI Codex CLI for second opinions or parallel execution.
  Use when the user explicitly mentions "codex" or asks to delegate work to Codex
  (e.g., "codexで実行", "codexに聞いて", "run with codex", "ask codex").
  Do NOT use for general coding tasks that don't mention Codex.
argument-hint: "<task-description>"
---

# Codex Runner

Delegate tasks to OpenAI Codex CLI from within Claude Code.

## Model Selection

- **Default**: Do NOT specify `--model`. The model configured in `~/.codex/config.toml` is used automatically.
- **User-specified model**: Only add `--model <MODEL>` when the user explicitly requests a specific model (e.g., "gpt-5.4で実行して", "use gpt-5.3-codex").

## Invocation

Run Codex in non-interactive exec mode:

```bash
# Default (uses model from config.toml)
codex exec "<PROMPT>"

# With explicit model override (only when user specifies)
codex exec --model <MODEL> "<PROMPT>"
```

### With image input

```bash
codex exec -i path/to/image.png "<PROMPT>"
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
codex exec "Fix the type error in src/utils.ts"
```

**With context:**
```bash
codex exec "Add input validation to the login handler in src/auth/handler.py. Validate email format and password length (min 8 chars)."
```

**Code review:**
```bash
codex exec "Review the changes in the current branch compared to main. Focus on security issues and performance."
```

**With explicit model:**
```bash
codex exec --model gpt-5.4 "Analyze the architecture of this project"
```

## Configuration

User's Codex config (`~/.codex/config.toml`) controls defaults:
- `model` - Default model (updated by user as new models release)
- `approval_policy = "never"` (fully autonomous)
- `sandbox_mode = "danger-full-access"`
- `network_access = true`

These settings mean Codex runs without approval prompts and uses the configured default model.

## Execution

- Always use the Bash tool with `timeout: 600000` (10 minutes) when running `codex exec`, as tasks may take significant time.

## Notes

- Always use `exec` mode (non-interactive) since Claude cannot interact with Codex's TUI
- Do NOT hardcode model names — let config.toml handle the default so it stays up to date
- Output streams to stdout; capture or display results directly
- For long-running tasks, warn the user that Codex may take time
- If Codex fails, report the error and suggest the user run it interactively with `codex`
