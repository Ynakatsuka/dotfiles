---
name: my-update-models
description: >-
  Check the latest Claude (Anthropic), OpenAI Codex, and Google Gemini model
  releases from official primary sources, update model selections in this
  dotfiles repo, and update the Claude Code, Codex, and Gemini CLIs through their
  configured managers. Every run checks both the model settings and CLI for the
  selected provider, then scans the invoking repository for hardcoded model IDs.
  Use when the user asks to "モデル更新", "モデルを最新に", "最新モデル確認",
  "Codex/Claude Code/Gemini CLI本体の更新", "model bump", "update models", or
  "update agent CLIs". Do NOT use for one-off model selection in a single
  conversation, general model questions, or unrelated package updates.
argument-hint: "[claude|codex|gemini|all]"
arguments:
  - provider
---

# Update Models and Agent CLIs

Refresh the default model selections in this dotfiles repo using the latest
official release information from Anthropic, OpenAI, and Google. Update the
Claude Code, Codex, and Gemini CLIs through their configured managers, then
sweep the invoking repository for any hardcoded model IDs that should be bumped
too.

## Targets

Invocation: `$my-update-models [$provider]`.

Treat an omitted `$provider` as `all`. Every target always includes its model
settings, CLI, and the invoking repository's model-ID scan.

- `claude` — Anthropic model settings and native Claude Code
- `codex` — OpenAI model settings and mise-managed Codex CLI
- `gemini` — Google model settings and mise-managed Gemini CLI
- `all` — all three model settings and CLIs

Reject unknown providers before making network calls.

Examples:

```text
$my-update-models          # all model settings, CLIs, and the repo scan
$my-update-models codex    # Codex model settings, CLI, and the repo scan
$my-update-models gemini   # Gemini model settings, CLI, and the repo scan
```

## Dotfiles Config Files

All paths are relative to `/home/yuki/ghq/github.com/Ynakatsuka/dotfiles/`.
Always edit in the ghq repo, never in `~/`.

| File | Field | Example value | Notes |
|---|---|---|---|
| `home/dot_claude/settings.json` | top-level `model` | `"opus"` | Default Claude Code model alias. Effort is managed separately via the top-level `effortLevel`. |
| `home/dot_claude/settings.json` | `env.CLAUDE_CODE_SUBAGENT_MODEL` | `"opus"` | Subagent model alias. Only present on some setups — skip if the key is absent. |
| `home/dot_claude/settings.json` | `autoUpdatesChannel` | `"latest"` | Native Claude Code update channel. Read it when checking or updating the CLI; do not change it unless requested. |
| `home/dot_codex/private_config.toml.tmpl` | `model` | `"gpt-5.5"` | Codex CLI default model (full ID, not an alias). |
| `home/dot_codex/private_config.toml.tmpl` | `[tui.model_availability_nux]` key | `"gpt-5.5" = 4` | NUX banner suppression — must be bumped together with `model` to keep the key in sync. |
| `home/dot_gemini/settings.json` | `model.name` | `"pro"` | Accepts aliases (`auto`, `pro`, `flash`, `flash-lite`) or full IDs (e.g. `gemini-2.5-pro`). Aliases auto-track the CLI default across releases — keep the alias unless the user wants a pinned version. |

Do NOT modify model IDs that appear inside skill examples
(e.g., `home/dot_claude/skills/my-agent/SKILL.md`). Those are illustrative only.

## CLI Management

Keep the configured split ownership. Do not migrate a CLI to another
manager as part of this skill.

| CLI | Expected manager | Current version | Latest/install/update command |
|---|---|---|---|
| Codex | mise entry `npm:@openai/codex = "latest"` | `codex --version` | Latest: `mise latest npm:@openai/codex`; install: `mise install npm:@openai/codex@latest`; update: `mise upgrade npm:@openai/codex --yes` |
| Gemini | mise entry `npm:@google/gemini-cli = "latest"` | `gemini --version` | Latest: `mise latest npm:@google/gemini-cli`; install: `mise install npm:@google/gemini-cli@latest`; update: `mise upgrade npm:@google/gemini-cli --yes` |
| Claude Code | Anthropic native installer under `~/.local/share/claude/versions/` | `claude --version` | Check the configured channel and official releases; update with `claude update` |

For Codex and Gemini, first verify the expected mise entry and inspect the
installed state:

```bash
mise ls --json npm:@openai/codex
mise ls --json npm:@google/gemini-cli
```

If the selected package is configured but not installed, report its installed
version as `not installed` and propose the table's `mise install` command. This
is not an ownership mismatch. For an installed mise package, resolve the
executable with `command -v`, inspect the symlink with `realpath`, and run its
version command. Resolve Claude Code the same way before proposing an update.

Stop and report an ownership mismatch if the configured manager or resolved
executable differs from the table. Do not fall back to `npm install -g`,
`curl | sh`, or another installer. For Claude Code, also stop if
`DISABLE_UPDATES=1` prevents manual updates.

## Primary Sources

Use primary sources only. If a required primary source is unavailable, report
the failure and stop before proposing or applying an update.

### Anthropic (Claude / Claude Code)
- Models overview: https://docs.anthropic.com/en/docs/about-claude/models/overview
- API pricing: https://platform.claude.com/docs/en/about-claude/pricing
- News: https://www.anthropic.com/news
- Claude Code setup and updates: https://docs.anthropic.com/en/docs/claude-code/setup
- Claude Code release notes: https://docs.claude.com/en/release-notes/claude-code
- Claude Code releases: https://github.com/anthropics/claude-code/releases

### OpenAI (Codex)
- Models reference: https://platform.openai.com/docs/models
- API pricing: https://developers.openai.com/api/docs/pricing
- Prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- News: https://openai.com/news
- Codex CLI repo (releases / changelog): https://github.com/openai/codex

### Google (Gemini)
- Models reference: https://ai.google.dev/gemini-api/docs/models
- API pricing: https://ai.google.dev/gemini-api/docs/pricing
- Context caching: https://ai.google.dev/gemini-api/docs/caching
- Gemini CLI installation and release channels: https://github.com/google-gemini/gemini-cli/blob/main/docs/get-started/installation.mdx
- Gemini CLI releases: https://github.com/google-gemini/gemini-cli/releases
- Gemini CLI default + alias table: https://github.com/google-gemini/gemini-cli/blob/main/packages/core/src/config/models.ts

## Workflow

1. **Parse scope.** Resolve `$provider` using the default and validation rules
   above. Report the selected provider(s), model settings, CLIs, and invoking
   repository before continuing.
2. **Read current state.** Open the managed model settings for the selected
   provider(s), verify each selected CLI's ownership, and capture the current
   model values and installed CLI versions. Report the current state up front.
3. **Fetch latest info.** Use WebFetch on the primary sources. If a required
   source cannot be read, report the failure and stop before proposing an
   update. Fetch only information required by the selected provider(s):
   - Newest available model IDs (new Claude family generation, new
     `gpt-*-codex` release, new `gemini-*` generation)
   - Release date and any deprecation notice on the currently configured model
   - Whether a new alias has been introduced (e.g., a new Claude family, or a
     new Gemini alias)
   - When a model update is available, the current and proposed models' API
     prices, including every published cache write, cache read/hit, and cache
     storage rate
   - Latest selected CLI versions. Use `mise latest npm:@openai/codex` for
     Codex and `mise latest npm:@google/gemini-cli` for Gemini. For Claude Code
     on the `latest` channel, use the official GitHub release and cross-check it
     against the changelog. For another channel, report the channel explicitly
     and use only a target documented for it. The mise-managed Gemini entry
     tracks npm's `latest` dist-tag, so compare it with the newest stable,
     non-prerelease GitHub release and report any mismatch.
4. **Compare models.** Build a short table:
   `file | field | current | proposed | reason`. Note trade-offs (capability,
   latency, cost) when relevant.
5. **Compare prices when an update is available.** Before asking for approval,
   show the pricing table defined below. Include adjacent `current` and
   `proposed` rows for every model change. Omit this table only when no model
   update is available.
6. **Compare CLIs.** Build a short table:
   `CLI | manager | installed | latest | action`.
7. **Confirm before mutating anything.** Let the user independently approve
   model config edits, each CLI update, and repo-scan edits. If the user picks a
   different choice, follow it.
8. **Update selected CLIs.** Run only the approved install or update command
   from the CLI Management table. For a mise-managed CLI, use `mise install`
   when it is configured but absent and `mise upgrade` when it is installed.
   Run `mise reshim --force` once after any successful mise install or upgrade.
   If a command fails, surface the error and stop that update; do not switch
   installers or claim partial success as complete.
9. **Verify CLI updates.** Re-resolve each updated executable, run its
   `--version` command, and compare the result with the proposed version. Report
   an error if the executable moved to an unexpected manager or the installed
   version did not change as expected.
10. **Apply approved model edits.** Edit the ghq repo with the Edit tool. Change
   one field per edit.
11. **Scan the invoking repository.** Scan for hardcoded model IDs as described
   below.
12. **Deploy model config changes.** Tell the user the deploy steps; only run
   them if asked.
   The chezmoi source dir is the ghq clone, so the canonical sequence is:
   ```bash
   chezmoi git pull -- --ff-only
   chezmoi diff
   chezmoi apply -v
   ```
   Per repo policy, do not commit automatically — wait for explicit approval.
13. **Verify model config changes.** After `chezmoi apply`, read `~/.codex/config.toml`,
   `~/.claude/settings.json`, and `~/.gemini/settings.json` to confirm the
   change landed.

## Model Price Comparison

When at least one configured model has a newer proposed model, ALWAYS show both
the current and proposed models in this exact table shape:

| Provider | Role | Model | Input | Cache write | Cache read/hit | Cache storage | Output | Pricing basis |
|---|---|---|---:|---:|---:|---:|---:|---|
| ... | current | ... | ... | ... | ... | ... | ... | ... |
| ... | proposed | ... | ... | ... | ... | ... | ... | ... |

Use the public paid, standard, on-demand API tier as the common comparison
basis unless the configured model is available only through another documented
tier. State the currency and units, normally `USD per 1M tokens`; include
`per hour` for cache storage. Preserve context-length bands and other pricing
thresholds instead of choosing the cheapest row. If the CLI or subscription
plan bills differently from the API, say that the API prices are comparison
figures and do not represent the subscription charge.

Never leave a cache column blank and never use an unexplained dash. Copy every
applicable cache rate from the provider's official pricing page:

- Include all cache-write durations when they have different rates, such as
  5-minute and 1-hour writes.
- Include both the cached-input/read rate and token-hour storage rate when the
  provider prices them separately.
- If the official pricing scheme has no separate charge for a cache operation,
  write `not separately charged` and cite the official source.
- If the provider does not publish any input, cache, storage, or output rate,
  write `not published (checked YYYY-MM-DD)` in that cell. Do not substitute a
  sibling model's price or infer a value.

Put the official pricing link in `Pricing basis` for each row. Use the same
pricing basis for the current and proposed rows so the comparison is valid.

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
