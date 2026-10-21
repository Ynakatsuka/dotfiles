# Dotfiles Repository Instructions

## Source and Deployment

- This repository manages macOS and Ubuntu dotfiles with chezmoi. `.chezmoiroot` selects `home/`; only that directory deploys to `$HOME`. Root files, `bootstrap/`, and `scripts/` are repository-only.
- Edit sources under `home/`, not deployed files. Verify target mappings when adding or moving files; declare stale targets in `home/.chezmoiremove`.
- chezmoi names: `dot_` → `.`, `private_` → restricted permissions, `.tmpl` → Go template, `executable_` → executable permissions.
- Inspect `chezmoi diff` before applying. Apply and validate managed changes before any requested commit or push; stop if apply requires an unresolved overwrite decision.

## Instruction Sources

- `home/AGENTS.md` holds global rules; root `AGENTS.md` holds repository rules. Root `CLAUDE.md` imports this file.
- Templates in `home/dot_{claude,codex,gemini}/` include `home/AGENTS.md` and add only product-specific tool behavior. Do not duplicate rules across layers.
- Skills live in `home/dot_claude/skills/` and are linked into Codex. Use `my-skill-creator` before editing a `SKILL.md`.
- Keep deployed global Claude rules intact and documented: `rules/bigquery.md`, `rules/git.md`, `rules/gpu.md`, and `rules/python.md`.

## Environment Variables

- Add environment variables only for secrets or values that differ between actual execution environments. For non-secrets, identify at least two environments requiring different values.
- Use CLI options for per-run behavior, repository configuration for policy, and code constants for fixed values.
- Before adding, renaming, or removing a variable, inspect its producers, consumers, tests, templates, and deployment settings. Keep one source of truth and update templates together.

## Verification

For repository changes:

```bash
prek run --files <changed-files>
bash scripts/check-stale.sh
```

For agent instructions or shell tool management, also run:

```bash
mise run check-agent-environment
bash scripts/test-rtk-rewrite-hook.sh
bash scripts/test-delegation.sh
```

- After managed changes, apply the affected targets and verify `chezmoi diff` plus deployed behavior.
- Shell changes require a fresh shell or `source ~/.zshrc`. Hammerspoon changes require `hs -c "hs.reload()"` or the documented AppleScript path. Use bootstrap dry-run modes when available.

## Configuration Details

- Bootstrap profiles: `make -C bootstrap full`, `standard`, or `minimal`.
- Tools are managed in `home/private_dot_config/mise/config.toml`. After adding one, run `mise install` and verify its shim in a clean shell.
- Claude Bash hooks run in this order: `bulk-read-guard`, `ensure-mise-path.sh`, `rtk-rewrite.sh`. The last delegates rewriting and permission decisions to `rtk rewrite`; preserve its exit-code protocol. Reproduce compatibility issues with installed RTK before adding guards.
- Edit Claude settings in `home/.chezmoitemplates/claude-settings.json`. Its `modify_settings.json.tmpl` script preserves Orca hook groups through `modify-settings-keep-orca-hooks.sh`; run `bash scripts/test-orca-hook-settings.sh` when changing that merge.
- Delegation commands and the read guard live in `home/dot_local/bin/`. The guard is registered in the Claude settings template and `home/dot_codex/hooks.json.tmpl`; Codex requires trust through `/hooks` after apply.
