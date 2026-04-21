---
name: my-update-models
description: >-
  Check the latest Claude (Anthropic), OpenAI Codex, and Google Gemini model
  releases from official primary sources, then update model selections in this
  dotfiles repo (dot_claude/settings.json, dot_codex/config.toml.tmpl,
  dot_gemini/settings.json). Also scans the invoking repository for hardcoded
  model IDs in GitHub Actions workflows, Python code, and shell scripts, and
  offers to bump them. Use when the user asks to "モデル更新", "モデルを最新に",
  "最新モデル確認", "model bump", "update models", or
  "claude/codex/gemini のモデル更新". Do NOT use for one-off model selection in
  a single conversation, general model questions, or non-config code changes.
argument-hint: "[claude|codex|gemini|all]"
---

# Update Models

Refresh the default model selections in this dotfiles repo using the latest
official release information from Anthropic, OpenAI, and Google, then sweep
the invoking repository for any hardcoded model IDs that should be bumped too.

## Scope (argument)

Default: `all`.

- `claude` — only Anthropic settings (`dot_claude/settings.json`)
- `codex`  — only OpenAI Codex settings (`dot_codex/config.toml.tmpl`)
- `gemini` — only Google Gemini settings (`dot_gemini/settings.json`)
- `all`    — all three providers

Regardless of argument, always run the repo-scan step (see below) so stale
model IDs in CI or app code do not silently drift out of sync.

## Dotfiles Config Files

All paths are relative to `/home/yuki/ghq/github.com/Ynakatsuka/dotfiles/`.
Always edit in the ghq repo, never in `~/`.

| File | Field | Example value | Notes |
|---|---|---|---|
| `dot_claude/settings.json` | top-level `model` | `"opus[1m]"` | Default Claude Code model. `[1m]` is the effort suffix — preserve unless the user asks to change it. |
| `dot_claude/settings.json` | `env.CLAUDE_CODE_SUBAGENT_MODEL` | `"opus"` | Subagent model alias. Only present on some setups — skip if the key is absent. |
| `dot_codex/config.toml.tmpl` | `model` | `"gpt-5.4"` | Codex CLI default model (full ID, not an alias). |
| `dot_gemini/settings.json` | `model.name` | `"pro"` | Accepts aliases (`auto`, `pro`, `flash`, `flash-lite`) or full IDs (e.g. `gemini-2.5-pro`). Aliases auto-track the CLI default across releases — keep the alias unless the user wants a pinned version. |

Do NOT modify model IDs that appear inside skill examples
(e.g., `dot_claude/skills/my-codex/SKILL.md`,
`dot_claude/skills/my-gemini/SKILL.md`). Those are illustrative only.

## Primary Sources

Always prefer primary sources over blog posts or third-party summaries.
If a primary page is unavailable, corroborate any secondary source against
another primary source before acting.

### Anthropic (Claude / Claude Code)
- Models overview: https://docs.anthropic.com/en/docs/about-claude/models/overview
- News: https://www.anthropic.com/news
- Claude Code release notes: https://docs.claude.com/en/release-notes/claude-code

### OpenAI (Codex)
- Models reference: https://platform.openai.com/docs/models
- News: https://openai.com/news
- Codex CLI repo (releases / changelog): https://github.com/openai/codex

### Google (Gemini)
- Models reference: https://ai.google.dev/gemini-api/docs/models
- Gemini CLI releases: https://github.com/google-gemini/gemini-cli/releases
- Gemini CLI default + alias table: https://github.com/google-gemini/gemini-cli/blob/main/packages/core/src/config/models.ts

## Workflow

1. **Read current settings.** Open the managed files for the selected
   provider(s) and capture the current model values. Report them up front.
2. **Fetch latest info.** Use WebFetch (or WebSearch when WebFetch is blocked)
   on the primary sources. Look for:
   - Newest available model IDs (new Claude family generation, new
     `gpt-*-codex` release, new `gemini-*` generation)
   - Release date and any deprecation notice on the currently configured model
   - Whether a new alias has been introduced (e.g., a new Claude family, or a
     new Gemini alias)
3. **Compare.** Build a short table: `file | field | current | proposed | reason`.
   Note trade-offs (capability, latency, cost) when relevant.
4. **Confirm with the user before editing.** If the user picks a different
   choice, follow it.
5. **Apply edits in the ghq repo** with the Edit tool. One field per edit.
6. **Scan the invoking repository** for hardcoded model IDs (see next section).
7. **Deploy.** Tell the user the deploy steps; only run them if asked.
   The chezmoi source dir is a separate clone, so the canonical sequence is:
   ```bash
   git -C ~/.local/share/chezmoi pull   # after the user commits + pushes in ghq
   chezmoi diff
   chezmoi apply -v
   ```
   Per repo policy, do not commit automatically — wait for explicit approval.
8. **Verify.** After `chezmoi apply`, read `~/.codex/config.toml`,
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
   claude-(opus|sonnet|haiku)-[0-9]|gpt-[0-9]|gemini-[0-9]|\bo[134](-mini|-preview)?\b
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
     - files under `.claude/skills/` or `dot_claude/skills/` that only
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
  `model_reasoning_effort` in `dot_codex/config.toml.tmpl` and the `[1m]`
  effort suffix on the Claude Code `model` field.
