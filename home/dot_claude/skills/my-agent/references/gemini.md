# Gemini Reference

Use Google Gemini through Antigravity CLI (`agy`). Read this before the first Gemini delegation in
a session.

## Preflight

1. Confirm that `agy` is installed:

   ```bash
   command -v agy
   agy --version
   ```

2. When the user requests a specific model, confirm that it is available before invoking it:

   ```bash
   agy models
   ```

3. Authentication is managed by Antigravity. If a headless call reports that authentication is
   missing or expired, stop and ask the user to run `agy` interactively. Do not inspect or print
   credential files.

## Invocation

Run Gemini headlessly with `-p`. Use the sandbox and disable slash-command expansion so prompt text
cannot invoke local commands or skills implicitly.

```bash
agy --sandbox --disable-slash-commands -p "<PROMPT>"
```

For analysis that should not edit files, add plan mode:

```bash
agy --mode plan --sandbox -p "<PROMPT>"
```

Antigravity CLI 1.2.5 ignores plan mode when `--disable-slash-commands` is present, so do not
combine those options. Keep untrusted document contents out of the command prompt in this mode.

For an explicitly requested implementation task, use accept-edits inside the sandbox:

```bash
agy --mode accept-edits --sandbox --disable-slash-commands -p "<PROMPT>"
```

Do not use `--dangerously-skip-permissions`. If a required operation is denied, report it rather
than weakening the permission boundary.

## Model selection

- Default: omit `--model` and use the Antigravity default.
- User-specified model: confirm the ID with `agy models`, then pass `--model <MODEL>`.
- Workflow-pinned model: a skill may specify a model when that exact model is part of its tested
  contract. Fail clearly if it is unavailable; do not silently substitute another model.

Example:

```bash
agy --model gemini-3.8-flash-high --effort high \
  --sandbox --disable-slash-commands -p "<PROMPT>"
```

## Structured output

Use JSON or stream-JSON output when the caller must validate the response.

```bash
agy --sandbox --disable-slash-commands \
  --output-format json -p "<PROMPT>"
```

For stream input, `--input-format stream-json` requires `--output-format stream-json`. Parse the
final `result` event and verify its status instead of reconstructing the answer from text deltas.
Also inspect tool events when the workflow forbids tool use.

## Troubleshooting

- `agy: command not found`: install Antigravity CLI with the repository bootstrap script.
- Unknown model: run `agy models`; do not choose a replacement without an explicit workflow rule.
- Authentication error: run `agy` interactively and complete sign-in.
- Plan-mode warning: remove `--disable-slash-commands`; Antigravity 1.2.5 otherwise ignores plan
  mode.
- Permission denial: keep the sandbox and permission policy; change only the scoped task or report
  the blocked operation.
- Invalid or incomplete structured output: treat the delegation as failed. Do not accept partial
  output as a successful result.
