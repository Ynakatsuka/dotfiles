# Claude Reference

Usage for the `claude` provider in `my-agent`.

## Preflight

- Confirm `command -v claude` succeeds. If it fails, stop and ask the user to install or authenticate Claude Code CLI.
- Do not invoke `/my-agent claude` from inside the delegated Claude session unless the user explicitly requests nested delegation.

## Invocation

Always use print mode (`-p`); a bare `claude` opens a TUI that cannot be driven from here.

```bash
claude -p "<PROMPT>"
claude --model <MODEL> -p "<PROMPT>"          # only when the user names a model
claude -p --output-format json "<PROMPT>"     # when the caller must parse the result
```

## Permission Mode

- **Default**: omit `--permission-mode`. The delegate inherits the configured default, which may already allow edits and commands; say so in the prompt when the task must stay read-only.
- **Planning or read-only review**: use `--permission-mode plan`.
- **Auto mode**: do not use `--permission-mode auto`. When settings disable it, it silently falls back to `default`, which cannot approve edits in print mode.
- **Bypass**: do not pass `--permission-mode bypassPermissions`, `--dangerously-skip-permissions`, or `--allow-dangerously-skip-permissions` unless the user explicitly accepts that risk.

If a tool permission fails, rerun only with an explicit mode that matches the user's intent; do not escalate to bypass without approval.
