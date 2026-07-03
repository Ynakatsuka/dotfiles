# Gemini Reference

Detailed usage for the `gemini` provider in `my-agent`. Read this **before** running `gemini -p` for the first time in a session.

## Preflight (run BEFORE every `gemini -p` invocation)

This environment exports `GEMINI_FORCE_FILE_STORAGE=true` in `~/.zshenv` so `@github/keytar` is bypassed and OAuth tokens live in a file under `~/.gemini/`. Without this, headless invocations can hang indefinitely on a locked GNOME Keyring (Secret Service over D-Bus) on SSH-only servers. Filename varies by backend: `oauth_creds.json` (default OAuth) or `gemini-credentials.json` (FileKeychain).

1. **Confirm the env var is exported and at least one credential file exists:**

   ```bash
   test "$GEMINI_FORCE_FILE_STORAGE" = "true" \
     && { test -f "$HOME/.gemini/oauth_creds.json" || test -f "$HOME/.gemini/gemini-credentials.json"; } \
     && echo ok
   ```

   If `GEMINI_FORCE_FILE_STORAGE` is missing, source `~/.zshenv` or export it before invoking `gemini -p`. If neither credential file exists, the user has not authenticated — instruct them to run `gemini` once in a TTY to complete OAuth. Do NOT run `gemini -p` in either case.

2. **Always pass `--skip-trust`.** Gemini CLI 0.39+ refuses to run headlessly in directories that are not registered as trusted ("Gemini CLI is not running in a trusted directory"). Since Claude Code invokes Gemini from arbitrary working directories, every `gemini -p` call MUST include `--skip-trust` (or set `GEMINI_CLI_TRUST_WORKSPACE=true` for the call). Omitting this is the most common cause of immediate failure.

## Invocation

Run Gemini headless with `-p`/`--prompt`. `--skip-trust` is required (see Preflight #2).

```bash
# Default (configured default model)
gemini --skip-trust -p "<PROMPT>"

# With explicit model override
gemini --skip-trust -m <MODEL> -p "<PROMPT>"
```

### Approval mode

Gemini prompts for approval by default. For autonomous delegation pass `-y` or `--approval-mode`:

```bash
# Auto-approve all tool actions (default for delegated execution)
gemini --skip-trust -y -p "<PROMPT>"

# Read-only (plan mode) — safe for analysis
gemini --skip-trust --approval-mode plan -p "<PROMPT>"

# Auto-approve edits only
gemini --skip-trust --approval-mode auto_edit -p "<PROMPT>"
```

Default to `-y`. Use `--approval-mode plan` when the user asks for planning/analysis only.

### Other options

```bash
# Include extra directories
gemini --skip-trust -y --include-directories path/to/dir1,path/to/dir2 -p "<PROMPT>"

# Resume sessions
gemini -r latest        # Most recent
gemini -r 5             # Session index 5
gemini --list-sessions  # List available

# Structured output
gemini --skip-trust -y -o json -p "<PROMPT>"
gemini --skip-trust -y -o stream-json -p "<PROMPT>"
```

## Model Selection

- **Default**: Do NOT specify `-m`. The Gemini CLI default is used.
- **User-specified model**: Add `-m <MODEL>` only when the user explicitly requests one (e.g., "gemini-2.5-proで実行して").

## Examples

```bash
# Simple task
gemini --skip-trust -y -p "Fix the type error in src/utils.ts"

# With context
gemini --skip-trust -y -p "Add input validation to src/auth/handler.py: email format and password length (min 8 chars)."

# Code review (read-only)
gemini --skip-trust --approval-mode plan -p "Review the changes in the current branch vs main. Focus on security and performance."

# Explicit model
gemini --skip-trust -y -m gemini-2.5-pro -p "Analyze the architecture of this project"
```

## Troubleshooting

- **Trusted-folder error**: stderr contains `Gemini CLI is not running in a trusted directory` — you forgot `--skip-trust`. Re-run with the flag.
- **Zero-output hang**: If `gemini -p` is killed by timeout AND both stdout and stderr are 0 byte, the most likely cause is that `GEMINI_FORCE_FILE_STORAGE=true` was not inherited by the calling shell, so keytar tried to read from a locked GNOME Keyring over D-Bus and stalled. Verify the env var is exported in the invoking shell, then retry. Do NOT retry blindly with the same environment.
