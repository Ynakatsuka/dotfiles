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

## Preflight (run BEFORE every `gemini -p` invocation)

This environment exports `GEMINI_FORCE_FILE_STORAGE=true` in `~/.zshenv` so that `@github/keytar` is bypassed and OAuth tokens live in a file under `~/.gemini/`. Without this, headless invocations can hang indefinitely on a locked GNOME Keyring (Secret Service over D-Bus) on SSH-only servers. The actual filename varies by platform/backend: `oauth_creds.json` (default OAuth flow) or `gemini-credentials.json` (FileKeychain).

1. **Confirm the env var is exported and at least one credential file exists:**

   ```bash
   test "$GEMINI_FORCE_FILE_STORAGE" = "true" \
     && { test -f "$HOME/.gemini/oauth_creds.json" || test -f "$HOME/.gemini/gemini-credentials.json"; } \
     && echo ok
   ```

   If `GEMINI_FORCE_FILE_STORAGE` is missing, source `~/.zshenv` or export it before invoking `gemini -p`. If neither credential file exists, the user has not authenticated yet — instruct them to run `gemini` once in a TTY to complete the OAuth flow. Do NOT run `gemini -p` in either case.

2. **Always pass `--skip-trust`.** Gemini CLI 0.39+ refuses to run headlessly in directories that are not registered as trusted ("Gemini CLI is not running in a trusted directory"). Since Claude Code invokes Gemini from arbitrary working directories, every `gemini -p` call MUST include `--skip-trust` (or set `GEMINI_CLI_TRUST_WORKSPACE=true` for the call). Omitting this is the most common cause of immediate failure.

## Model Selection

- **Default**: Do NOT specify `-m`. The default model configured by the Gemini CLI is used.
- **User-specified model**: Only add `-m <MODEL>` when the user explicitly requests a specific model (e.g., "gemini-2.5-proで実行して", "use gemini-2.5-flash").

## Invocation

Run Gemini in non-interactive (headless) mode with `-p`/`--prompt`. `--skip-trust` is required (see Preflight #2):

```bash
# Default (uses configured default model)
gemini --skip-trust -p "<PROMPT>"

# With explicit model override (only when user specifies)
gemini --skip-trust -m <MODEL> -p "<PROMPT>"
```

### Approval mode

Gemini prompts for approval by default. For fully autonomous delegation, pass `-y` (YOLO) or `--approval-mode`:

```bash
# Auto-approve all tool actions
gemini --skip-trust -y -p "<PROMPT>"

# Read-only (plan mode) — safe for analysis tasks
gemini --skip-trust --approval-mode plan -p "<PROMPT>"

# Auto-approve edits only
gemini --skip-trust --approval-mode auto_edit -p "<PROMPT>"
```

Default to `-y` for delegated execution unless the user asks for planning/analysis, in which case use `--approval-mode plan`.

### Include extra directories

```bash
gemini --skip-trust -y --include-directories path/to/dir1,path/to/dir2 -p "<PROMPT>"
```

### Resume previous session

```bash
gemini -r latest       # Most recent session
gemini -r 5            # Session index 5
gemini --list-sessions # Show available sessions
```

### Structured output

```bash
gemini --skip-trust -y -o json -p "<PROMPT>"          # JSON output
gemini --skip-trust -y -o stream-json -p "<PROMPT>"   # Streaming JSON
```

## Prompt Construction

1. Convert the user's request into a clear, self-contained prompt for Gemini
2. Include relevant file paths and context in the prompt
3. If the user provides a specific prompt, pass it through directly

### Examples

**Simple task:**
```bash
gemini --skip-trust -y -p "Fix the type error in src/utils.ts"
```

**With context:**
```bash
gemini --skip-trust -y -p "Add input validation to the login handler in src/auth/handler.py. Validate email format and password length (min 8 chars)."
```

**Code review (read-only):**
```bash
gemini --skip-trust --approval-mode plan -p "Review the changes in the current branch compared to main. Focus on security issues and performance."
```

**With explicit model:**
```bash
gemini --skip-trust -y -m gemini-2.5-pro -p "Analyze the architecture of this project"
```

## Execution

- Always use the Bash tool with `timeout: 600000` (10 minutes) when running `gemini -p`, as tasks may take significant time.
- **Trusted-folder error**: If stderr contains `Gemini CLI is not running in a trusted directory`, you forgot `--skip-trust`. Re-run with the flag.
- **Zero-output hang**: If `gemini -p` is killed by timeout AND both stdout and stderr are 0 byte, the most likely cause is that `GEMINI_FORCE_FILE_STORAGE=true` was not inherited by the calling shell, so keytar tried to read from a locked GNOME Keyring over D-Bus and stalled. Verify the env var is exported in the invoking shell, then retry. Do NOT retry blindly with the same environment.

## Notes

- Always use `-p`/`--prompt` (non-interactive) since Claude cannot interact with Gemini's TUI
- Do NOT hardcode model names — let the CLI default handle it so it stays up to date
- Output streams to stdout; capture or display results directly
- For long-running tasks, warn the user that Gemini may take time
- If Gemini fails, report the error and suggest the user run it interactively with `gemini`
