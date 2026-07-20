---
name: my-update-models
description: >-
  Check the latest Claude (Anthropic), OpenAI Codex, and Google Gemini model
  releases from official primary sources, update model selections in this
  dotfiles repo, and update the Codex and Claude Code CLIs through their existing
  managers. The model track also scans the invoking repository for hardcoded
  model IDs and offers to bump them. Use when the user asks to "モデル更新", "モデルを最新に",
  "最新モデル確認", "Codex/Claude Code本体の更新", "model bump", "update models",
  or "update agent CLIs". Subcommands: harness, model, both (default). Do NOT
  use for one-off model selection in a single conversation, general model
  questions, or unrelated package updates.
argument-hint: "[harness|model|both] [claude|codex|gemini|all]"
arguments:
  - mode
  - provider
---

# Update Models and Agent CLIs

Refresh the default model selections in this dotfiles repo using the latest
official release information from Anthropic, OpenAI, and Google. Update the
Codex and Claude Code CLIs through their current managers, then sweep the
invoking repository for any hardcoded model IDs that should be bumped too.

## Subcommands and Targets

Invocation: `$my-update-models [$mode] [$provider]`.

Treat an omitted `$mode` as `both` and an omitted `$provider` as `all`.
Therefore, invoking the skill without arguments updates both tracks for every
supported provider.

### Mode

- `harness` — check and update the Codex and/or Claude Code CLI. Do not edit
  model settings or run the model-ID repo scan.
- `model` — check and update model settings, then run the model-ID repo scan.
  Do not update a CLI.
- `both` — run both `harness` and `model` for the selected provider. This is
  the default.

### Provider

- `claude` — Anthropic model settings and, when selected, native Claude Code
- `codex` — OpenAI model settings and, when selected, mise-managed Codex CLI
- `gemini` — Google Gemini model settings only
- `all` — all model providers plus the Codex and Claude Code CLIs

Reject unknown modes or providers before making network calls. Also reject
`harness gemini` and `both gemini`; this skill does not manage the Gemini CLI.
Tell the user to use `model gemini` for Gemini model settings.

Examples:

```text
$my-update-models                 # both all
$my-update-models harness         # harness all
$my-update-models harness codex   # Codex CLI only
$my-update-models model gemini    # Gemini model settings only
$my-update-models both claude     # Claude model settings and Claude Code CLI
```

## Dotfiles Config Files

All paths are relative to `/home/yuki/ghq/github.com/Ynakatsuka/dotfiles/`.
Always edit in the ghq repo, never in `~/`.

| File | Field | Example value | Notes |
|---|---|---|---|
| `home/dot_claude/settings.json` | top-level `model` | `"opus"` | Default Claude Code model alias. Effort is managed separately via `env.CLAUDE_CODE_EFFORT_LEVEL`. |
| `home/dot_claude/settings.json` | `env.CLAUDE_CODE_SUBAGENT_MODEL` | `"opus"` | Subagent model alias. Only present on some setups — skip if the key is absent. |
| `home/dot_claude/settings.json` | `autoUpdatesChannel` | `"latest"` | Native Claude Code update channel. Read it when checking or updating the CLI; do not change it unless requested. |
| `home/dot_codex/private_config.toml.tmpl` | `model` | `"gpt-5.5"` | Codex CLI default model (full ID, not an alias). |
| `home/dot_codex/private_config.toml.tmpl` | `[tui.model_availability_nux]` key | `"gpt-5.5" = 4` | NUX banner suppression — must be bumped together with `model` to keep the key in sync. |
| `home/dot_gemini/settings.json` | `model.name` | `"pro"` | Accepts aliases (`auto`, `pro`, `flash`, `flash-lite`) or full IDs (e.g. `gemini-2.5-pro`). Aliases auto-track the CLI default across releases — keep the alias unless the user wants a pinned version. |

Do NOT modify model IDs that appear inside skill examples
(e.g., `home/dot_claude/skills/my-agent/SKILL.md`). Those are illustrative only.

## CLI Management

Keep the existing split ownership. Do not migrate either CLI to another
manager as part of this skill.

| CLI | Expected manager | Current version | Latest/update command |
|---|---|---|---|
| Codex | mise entry `npm:@openai/codex = "latest"` | `codex --version` | `mise latest npm:@openai/codex`; update with `mise upgrade npm:@openai/codex --yes` |
| Claude Code | Anthropic native installer under `~/.local/share/claude/versions/` | `claude --version` | Check the configured channel and official releases; update with `claude update` |

Before proposing an update, resolve each selected executable with `command -v`
and inspect symlinks with `realpath`. For Codex, also run:

```bash
mise ls --json npm:@openai/codex
```

Stop and report an ownership mismatch instead of updating through a guessed
manager. Do not fall back to `npm install -g`, `curl | sh`, or another installer.
For Claude Code, also stop if `DISABLE_UPDATES=1` prevents manual updates.

## Primary Sources

Use primary sources only. If a required primary source is unavailable, report
the failure and stop before proposing or applying an update.

### Anthropic (Claude / Claude Code)
- Models overview: https://docs.anthropic.com/en/docs/about-claude/models/overview
- News: https://www.anthropic.com/news
- Claude Code setup and updates: https://docs.anthropic.com/en/docs/claude-code/setup
- Claude Code release notes: https://docs.claude.com/en/release-notes/claude-code
- Claude Code releases: https://github.com/anthropics/claude-code/releases

### OpenAI (Codex)
- Models reference: https://platform.openai.com/docs/models
- News: https://openai.com/news
- Codex CLI repo (releases / changelog): https://github.com/openai/codex

### Google (Gemini)
- Models reference: https://ai.google.dev/gemini-api/docs/models
- Gemini CLI releases: https://github.com/google-gemini/gemini-cli/releases
- Gemini CLI default + alias table: https://github.com/google-gemini/gemini-cli/blob/main/packages/core/src/config/models.ts

## Workflow

1. **Parse scope.** Resolve `$mode` and `$provider` using the defaults and
   validation rules above. Report the resolved scope before continuing.
2. **Read current state.** For the `model` track, open the managed files for the
   selected provider(s) and capture the current model values. For the `harness`
   track, verify selected CLI ownership and capture installed versions. Report
   the current state up front.
3. **Fetch latest info.** Use WebFetch on the primary sources. If a required
   source cannot be read, report the failure and stop before proposing an
   update. Fetch only information required by the selected track(s):
   - Newest available model IDs (new Claude family generation, new
     `gpt-*-codex` release, new `gemini-*` generation)
   - Release date and any deprecation notice on the currently configured model
   - Whether a new alias has been introduced (e.g., a new Claude family, or a
     new Gemini alias)
   - Latest selected CLI versions. Use `mise latest npm:@openai/codex` for
     Codex. For Claude Code on the `latest` channel, use the official GitHub
     release and cross-check it against the changelog. For another channel,
     report the channel explicitly and use only a target documented for it.
4. **Compare models when selected.** Build a short table:
   `file | field | current | proposed | reason`. Note trade-offs (capability,
   latency, cost) when relevant. Omit this step for `harness`.
5. **Compare CLIs when selected.** Build a short table:
   `CLI | manager | installed | latest | action`. Omit this step for `model`.
6. **Confirm before mutating anything.** Let the user independently approve
   model config edits, each CLI update, and repo-scan edits. If the user picks a
   different choice, follow it.
7. **Update selected CLIs.** For `harness` or `both`, run only the approved
   commands:
   ```bash
   mise upgrade npm:@openai/codex --yes
   mise reshim --force
   claude update
   ```
   Run the Codex pair only for `codex` or `all`, and `claude update` only for
   `claude` or `all`. If a command fails, surface the error and stop that update;
   do not switch installers or claim partial success as complete.
8. **Verify CLI updates.** Re-resolve each updated executable, run its
   `--version` command, and compare the result with the proposed version. Report
   an error if the executable moved to an unexpected manager or the installed
   version did not change as expected.
9. **Apply approved model edits.** For `model` or `both`, edit the ghq repo with
   the Edit tool. Change one field per edit.
10. **Scan the invoking repository.** For `model` or `both`, scan for hardcoded
   model IDs as described below. Skip the scan for `harness`.
11. **Deploy model config changes.** Tell the user the deploy steps; only run
   them if asked.
   The chezmoi source dir is the ghq clone, so the canonical sequence is:
   ```bash
   chezmoi git pull -- --ff-only
   chezmoi diff
   chezmoi apply -v
   ```
   Per repo policy, do not commit automatically — wait for explicit approval.
12. **Verify model config changes.** After `chezmoi apply`, read `~/.codex/config.toml`,
   `~/.claude/settings.json`, and `~/.gemini/settings.json` to confirm the
   change landed.

## Repo Scan (hardcoded model IDs)

After updating dotfiles configs, sweep the **current working directory's
repository** (the one the user invoked the skill from) for hardcoded model
IDs that also need bumping.

1. **Determine the repo root.**
   ```bash
   git rev-parse --show-toplevel
   ```
   If the command fails (not a git repo), skip the scan and tell the user.

2. **Grep for model-ID patterns.** Run the Grep tool at the repo root with
   this regex (ripgrep syntax, respects `.gitignore` by default):
   ```
   claude-(fable|opus|sonnet|haiku)-[0-9]|gpt-[0-9]|gemini-[0-9]|\bo[134](-mini|-preview)?\b
   ```
   Prioritize these globs on the first pass:
   - `.github/workflows/**/*.{yml,yaml}` — GitHub Actions
   - `**/*.py` — Python code
   - `**/*.{sh,bash,zsh}` — shell scripts
   - `**/*.{ts,tsx,js,jsx,mjs}` — Node / TypeScript clients
   - `**/*.{toml,json,yaml,yml}` — app configs (skip lockfiles)

3. **Classify each hit** before proposing edits:
   - **Update candidate:** production code, CI workflow, deployment config,
     CLI wrapper, Dockerfile.
   - **Leave alone:**
     - documentation examples, changelog entries, migration notes
     - test fixtures, recorded cassettes, VCR tapes, golden snapshots
     - lockfiles, vendor dirs (`node_modules/`, `.venv/`, `dist/`, `build/`)
     - files under `.claude/skills/` or `home/dot_claude/skills/` that only
       illustrate a model name
     - comments that intentionally name a legacy model for historical reasons
     - the dotfiles config files already handled in the previous section

4. **Present candidates.** Show the user a table:
   `path:line | current | proposed | category`.
   List skipped hits on a separate short line (one reason each).

5. **Apply after confirmation.** Edit one occurrence at a time. If the same
   model ID appears many times in a single file with identical context, use
   `replace_all`; otherwise edit per-site to preserve surrounding context.

6. **Re-run the grep** after edits to confirm no stale IDs remain in the
   candidates you chose to update.

## Notes

- Claude Code uses friendly aliases (`opus`, `sonnet`, `haiku`). Anthropic
  rotates the underlying model behind each alias on release, so the alias
  itself usually does not need to change. Switch the alias only when picking
  a different family (e.g., dropping from `opus` to `sonnet` for cost) or
  when a new family ships.
- Codex uses full model IDs. Always update to a specific ID announced on
  the OpenAI models page or the Codex CLI release notes.
- Gemini CLI accepts both aliases (`auto`, `pro`, `flash`, `flash-lite`) and
  full IDs (`gemini-2.5-pro`, `gemini-3-pro-preview`). Aliases track the CLI
  default across releases — keep the alias unless the user wants pinning.
- If the new model has different reasoning controls, also re-evaluate
  `model_reasoning_effort` in `home/dot_codex/private_config.toml.tmpl` and the `[1m]`
  effort suffix on the Claude Code `model` field.
