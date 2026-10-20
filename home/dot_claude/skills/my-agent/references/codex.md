# Codex Reference

Detailed usage for the `codex` provider in `my-agent`. Read this when invoking Codex with anything beyond `codex exec "<PROMPT>"`.

## Invocation

Always use `exec` mode (non-interactive); Claude cannot interact with Codex's TUI.

`codex exec` reads stdin whenever stdin is not a terminal and appends it to the prompt, so an agent shell whose stdin never closes hangs at `Reading additional input from stdin...`. Redirect stdin on every call: `</dev/null`, or `-` with the prompt file on stdin. When logging to a file, use a new path or `>|`, because zsh `noclobber` refuses `>` over an existing file.

```bash
# Default (uses model from ~/.codex/config.toml)
codex exec "<PROMPT>" </dev/null

# Long prompt from a file
codex exec - <prompt.md

# With explicit model override (only when user specifies)
codex exec --model <MODEL> "<PROMPT>" </dev/null

# With image input
codex exec -i path/to/image.png "<PROMPT>" </dev/null

# Resume a previous session non-interactively
codex exec resume --last "<PROMPT>" </dev/null
```

For Chrome operation, Computer Use, or Slack posts, use `codex-task --prompt-file <file>`; run `codex-task --help` for its output and resume options.

## Model Selection

- **Default**: Do NOT specify `--model`. The model in `~/.codex/config.toml` is used automatically.
- **User-specified model**: Add `--model <model>` only when the user explicitly requests one. Resolve the current default from `~/.codex/config.toml`; omit `-m` to use the CLI default.

## Configuration

User's Codex config (`~/.codex/config.toml`) controls defaults:

- `model` — Default model
- `approval_policy = "never"` — fully autonomous
- `sandbox_mode = "danger-full-access"`

Codex therefore runs without approval prompts.

## Examples

```bash
# Simple task
codex exec "Fix the type error in src/utils.ts" </dev/null

# With context
codex exec "Add input validation to src/auth/handler.py: email format and password length (min 8 chars)." </dev/null

# Code review of a diff piped as context (the pipe replaces </dev/null)
git diff main... | codex exec "Review this diff. Focus on security and performance."

# Explicit model (resolve current ID from ~/.codex/config.toml, or omit --model to use CLI default)
codex exec --model <model> "Analyze the architecture of this project" </dev/null
```
