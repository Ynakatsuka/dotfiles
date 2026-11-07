# Gemini Reference

Use Google Gemini through Antigravity CLI (`agy`). Read this before the first Gemini delegation in
a session.

## Preflight

1. Confirm `command -v agy` succeeds. If it fails, install Antigravity CLI with the repository
   bootstrap script.
2. When the user names a model, confirm its ID with `agy models` before invoking it.
3. Authentication is managed by Antigravity. If a headless call reports missing or expired
   authentication, stop and ask the user to run `agy` interactively. Do not inspect or print
   credential files.

## Invocation

Run headlessly with `-p`. Use the sandbox and disable slash-command expansion so prompt text
cannot invoke local commands or skills implicitly.

```bash
agy --sandbox --disable-slash-commands -p "<PROMPT>"
```

For analysis that must not edit files, use plan mode without `--disable-slash-commands`:

```bash
agy --mode plan --sandbox -p "<PROMPT>"
```

Antigravity ignores plan mode when `--disable-slash-commands` is present and prints
`warning: --mode plan has no effect while slash command expansion is disabled.` (checked on
1.5.2). Do not combine the two, and keep untrusted document contents out of the prompt in plan
mode.

For an explicitly requested implementation task, use accept-edits inside the sandbox:

```bash
agy --mode accept-edits --sandbox --disable-slash-commands -p "<PROMPT>"
```

Do not use `--dangerously-skip-permissions`. If a required operation is denied, report it rather
than weakening the permission boundary.

## Model selection

- Default: omit `--model`.
- User-specified model: confirm the ID with `agy models`, then pass `--model <MODEL>`.
- Workflow-pinned model: a skill may specify a model when that exact model is part of its tested
  contract. Fail clearly if it is unavailable; do not substitute another model.

## Structured output

Use `--output-format json` or `stream-json` when the caller must validate the response.
`--input-format stream-json` requires `--output-format stream-json`. Parse the final `result`
event and verify its status instead of reconstructing the answer from text deltas, and inspect
tool events when the workflow forbids tool use. Treat invalid or incomplete structured output as
a failed delegation.
