---
name: my-gemini
description: >-
  Delegate tasks to Google Gemini CLI for second opinions or parallel execution.
  Use when the user explicitly mentions "gemini" or asks to delegate work to Gemini
  (e.g., "geminiで実行", "Geminiに聞いて", "run with gemini", "ask gemini").
  Do NOT use for general coding tasks that don't mention Gemini.
argument-hint: "<task-description>"
---

# Gemini Runner

Delegate tasks to Google Gemini CLI from within Claude Code.

## Model Selection

- **Default**: Do NOT specify `-m`. The default model configured by the Gemini CLI is used.
- **User-specified model**: Only add `-m <MODEL>` when the user explicitly requests a specific model (e.g., "gemini-2.5-proで実行して", "use gemini-2.5-flash").

## Invocation

Run Gemini in non-interactive (headless) mode with `-p`/`--prompt`:

```bash
# Default (uses configured default model)
gemini -p "<PROMPT>"

# With explicit model override (only when user specifies)
gemini -m <MODEL> -p "<PROMPT>"
```

### Approval mode

Gemini prompts for approval by default. For fully autonomous delegation, pass `-y` (YOLO) or `--approval-mode`:

```bash
# Auto-approve all tool actions
gemini -y -p "<PROMPT>"

# Read-only (plan mode) — safe for analysis tasks
gemini --approval-mode plan -p "<PROMPT>"

# Auto-approve edits only
gemini --approval-mode auto_edit -p "<PROMPT>"
```

Default to `-y` for delegated execution unless the user asks for planning/analysis, in which case use `--approval-mode plan`.

### Include extra directories

```bash
gemini -y --include-directories path/to/dir1,path/to/dir2 -p "<PROMPT>"
```

### Resume previous session

```bash
gemini -r latest       # Most recent session
gemini -r 5            # Session index 5
gemini --list-sessions # Show available sessions
```

### Structured output

```bash
gemini -y -o json -p "<PROMPT>"          # JSON output
gemini -y -o stream-json -p "<PROMPT>"   # Streaming JSON
```

## Prompt Construction

1. Convert the user's request into a clear, self-contained prompt for Gemini
2. Include relevant file paths and context in the prompt
3. If the user provides a specific prompt, pass it through directly

### Examples

**Simple task:**
```bash
gemini -y -p "Fix the type error in src/utils.ts"
```

**With context:**
```bash
gemini -y -p "Add input validation to the login handler in src/auth/handler.py. Validate email format and password length (min 8 chars)."
```

**Code review (read-only):**
```bash
gemini --approval-mode plan -p "Review the changes in the current branch compared to main. Focus on security issues and performance."
```

**With explicit model:**
```bash
gemini -y -m gemini-2.5-pro -p "Analyze the architecture of this project"
```

## Execution

- Always use the Bash tool with `timeout: 600000` (10 minutes) when running `gemini -p`, as tasks may take significant time.

## Notes

- Always use `-p`/`--prompt` (non-interactive) since Claude cannot interact with Gemini's TUI
- Do NOT hardcode model names — let the CLI default handle it so it stays up to date
- Output streams to stdout; capture or display results directly
- For long-running tasks, warn the user that Gemini may take time
- If Gemini fails, report the error and suggest the user run it interactively with `gemini`
