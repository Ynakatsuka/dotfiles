# Claude Reference

Detailed usage for the `claude` provider in `my-agent`. Read this **before** running `claude -p` for the first time in a session.

## Preflight

1. Confirm the Claude Code CLI exists:

   ```bash
   command -v claude
   ```

   If this fails, do not continue with the `claude` provider. Report that Claude Code CLI is unavailable and suggest installing or authenticating it before retrying.

2. Do not invoke `/my-agent claude` from inside the delegated Claude session unless the user explicitly requests nested delegation. This avoids accidental recursion.

## Invocation

Always use print mode (`-p`/`--print`) for non-interactive execution; Claude cannot interact with a nested TUI.

```bash
# Default
claude -p "<PROMPT>"

# With explicit Fable model alias
claude --model fable -p "<PROMPT>"

# With explicit model override
claude --model <MODEL> -p "<PROMPT>"

# With JSON output
claude -p --output-format json "<PROMPT>"
```

## Permission Mode

- **Default**: Do not specify `--permission-mode`. Use Claude Code's configured default.
- **Planning or read-only review**: Use `--permission-mode plan` when the user asks for planning, analysis, or review only.
- **Autonomous edits**: Use `--permission-mode auto` only when the user explicitly asks the delegated Claude to modify files.
- **Bypass permissions**: Do not use `--permission-mode bypassPermissions`, `--dangerously-skip-permissions`, or `--allow-dangerously-skip-permissions` unless the user explicitly requests that risk.

## Model Selection

- **Default**: Do NOT specify `--model`. Claude Code's configured default is used.
- **User-specified model**: Add `--model <MODEL>` only when the user explicitly requests one (e.g., "fableに相談して", "fableで実行して", "opusで実行して", "use sonnet").
- **Fable alias**: If the user says "fable" as the provider, asks to use Claude Fable, or uses consultation phrasing such as "fableに相談" / "Fableに聞いて", use `claude --model fable -p "<PROMPT>"`. Do not expand `fable` to a dated model ID.

## Examples

```bash
# Simple analysis
claude -p "Explain the architecture of this project and identify the main extension points."

# Read-only code review
claude --permission-mode plan -p "Review the changes in the current branch vs main. Focus on security and performance."

# Delegated implementation
claude --permission-mode auto -p "Fix the type error in src/utils.ts and run the nearest relevant test."

# Explicit Fable model
claude --model fable -p "Analyze the architecture of this project."
```

## Troubleshooting

- **Interactive prompt or no output**: Ensure `-p`/`--print` is present. Do not run bare `claude` from this skill.
- **Tool permission failure**: Re-run only after choosing an explicit permission mode that matches the user's intent. Do not escalate to bypass permissions without user approval.
- **Unavailable command**: `command -v claude` failed. Ask the user to install or authenticate Claude Code CLI, then retry.
