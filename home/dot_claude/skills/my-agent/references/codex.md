# Codex Reference

Detailed usage for the `codex` provider in `my-agent`. Read this when invoking Codex with anything beyond `codex exec "<PROMPT>"`.

## Invocation

Always use `exec` mode (non-interactive); Claude cannot interact with Codex's TUI.

```bash
# Default (uses model from ~/.codex/config.toml)
codex exec "<PROMPT>"

# With explicit model override (only when user specifies)
codex exec --model <MODEL> "<PROMPT>"

# With image input
codex exec -i path/to/image.png "<PROMPT>"

# Resume previous session
codex resume --last
```

## Model Selection

- **Default**: Do NOT specify `--model`. The model in `~/.codex/config.toml` is used automatically.
- **User-specified model**: Add `--model <MODEL>` only when the user explicitly requests one (e.g., "gpt-5.4で実行して", "use gpt-5.3-codex").

## Configuration

User's Codex config (`~/.codex/config.toml`) controls defaults:

- `model` — Default model
- `approval_policy = "never"` — fully autonomous
- `sandbox_mode = "danger-full-access"`
- `network_access = true`

Codex therefore runs without approval prompts.

## Examples

```bash
# Simple task
codex exec "Fix the type error in src/utils.ts"

# With context
codex exec "Add input validation to src/auth/handler.py: email format and password length (min 8 chars)."

# Code review
codex exec "Review the changes in the current branch vs main. Focus on security and performance."

# Explicit model
codex exec --model gpt-5.4 "Analyze the architecture of this project"
```
