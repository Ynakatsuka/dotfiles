---
name: my-update-models
description: >-
  Check the latest Claude (Anthropic) and OpenAI Codex model releases from official
  primary sources, then update model selections in this dotfiles repo
  (dot_claude/settings.json, dot_codex/config.toml.tmpl). Use when the user asks
  to "モデル更新", "モデルを最新に", "最新モデル確認", "model bump", "update models",
  or "claude/codex のモデル更新". Do NOT use for one-off model selection in a single
  conversation, general model questions, or non-config code changes.
argument-hint: "[claude|codex|all]"
---

# Update Models

Refresh the default model selections in this dotfiles repo using the latest
official release information from Anthropic and OpenAI.

## Scope (argument)

Default: `all`.

- `claude` — only Anthropic settings (`dot_claude/settings.json`)
- `codex`  — only OpenAI Codex settings (`dot_codex/config.toml.tmpl`)
- `all`    — both providers

## Files Managed

All paths are relative to `/home/yuki/ghq/github.com/Ynakatsuka/dotfiles/`.
Always edit in the ghq repo, never in `~/`.

| File | Field | Example value | Notes |
|---|---|---|---|
| `dot_claude/settings.json` | top-level `model` | `"opus[1m]"` | Default Claude Code model. `[1m]` is the effort suffix — preserve unless the user asks to change it. |
| `dot_claude/settings.json` | `env.CLAUDE_CODE_SUBAGENT_MODEL` | `"opus"` | Subagent model alias. Usually matches the default family. |
| `dot_codex/config.toml.tmpl` | `model` | `"gpt-5.4"` | Codex CLI default model (full ID, not an alias). |

Do NOT modify model IDs that appear inside skill examples
(e.g., `dot_claude/skills/my-codex/SKILL.md`). Those are illustrative only.

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

## Workflow

1. **Read current settings.** Open the managed files and capture the current
   model values. Report them back to the user up front.
2. **Fetch latest info.** Use WebFetch (or WebSearch when WebFetch is blocked)
   on the primary sources for the requested provider(s). Look for:
   - Newest available model IDs (e.g., a new Claude family generation, or a
     new `gpt-*-codex` release)
   - Release date and any deprecation notice on the currently configured model
   - Whether a new alias has been introduced beyond `opus`/`sonnet`/`haiku`
3. **Compare.** Build a short table: `field | current | proposed | reason`.
   Note trade-offs (capability, latency, cost) when relevant.
4. **Confirm with the user before editing.** If the user picks a different
   choice, follow it.
5. **Apply edits in the ghq repo** with the Edit tool. One field per edit.
6. **Deploy.** Tell the user the deploy steps; only run them if asked.
   The chezmoi source dir is a separate clone, so the canonical sequence is:
   ```bash
   git -C ~/.local/share/chezmoi pull   # after the user commits + pushes in ghq
   chezmoi diff
   chezmoi apply -v
   ```
   Per repo policy, do not commit automatically — wait for explicit approval.
7. **Verify.** After `chezmoi apply`, read `~/.codex/config.toml` and
   `~/.claude/settings.json` to confirm the change landed.

## Notes

- Claude Code uses friendly aliases (`opus`, `sonnet`, `haiku`). Anthropic
  rotates the underlying model behind each alias on release, so the alias
  itself usually does not need to change. Switch the alias only when picking
  a different family (e.g., dropping from `opus` to `sonnet` for cost) or
  when a new family ships.
- Codex uses full model IDs. Always update to a specific ID announced on
  the OpenAI models page or the Codex CLI release notes.
- If the new model has different reasoning controls, also re-evaluate
  `model_reasoning_effort` in `dot_codex/config.toml.tmpl` and the `[1m]`
  effort suffix on the Claude Code `model` field.
