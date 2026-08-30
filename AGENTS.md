# Dotfiles Repository Instructions

## Repository Scope

- This repository manages personal dotfiles for macOS and Ubuntu with chezmoi.
- `.chezmoiroot` points to `home/`; only files under `home/` are deployed to `$HOME`.
- Files outside `home/`, including this file, are repository-only.
- `home/.chezmoiremove` declaratively removes stale deployed targets.

## Source Layout

- `home/`: chezmoi source state
- `bootstrap/`: platform-specific setup scripts
- `scripts/`: repository maintenance and validation scripts
- `home/dot_claude/`: global Claude Code configuration
- `home/dot_codex/`: global Codex configuration
- `home/dot_gemini/`: global Gemini CLI configuration
- `home/private_dot_config/zsh/`: zsh modules loaded by `home/dot_zshrc`

Inside `home/`, follow chezmoi naming conventions:

- `dot_` becomes `.`
- `private_` requests restricted permissions
- `.tmpl` is rendered as a Go template
- `executable_` requests executable permissions

## Editing and Deployment

- Edit the source under `home/`; never edit a deployed file under `$HOME` as the authoritative change.
- Verify the source-to-target mapping before adding or moving a managed file.
- Run `chezmoi diff` before `chezmoi apply` and inspect target drift.
- If non-interactive apply requires a decision, stop and report instead of forcing an overwrite.
- Apply and validate managed changes before any requested commit or push.
- Do not create configuration directly in `~/.claude/`, `~/.codex/`, `~/.gemini/`, or `~/.config/`; create the corresponding source under `home/` first.

## 環境変数

- 環境変数を追加できるのは、秘密情報か、実行環境によって値が異なる場合に限る。秘密情報でない場合は、異なる値を必要とする実際の実行環境を少なくとも二つ挙げる。挙げられない場合は環境変数を使わない。
- 実行ごとの動作には明示的なCLIオプション、バージョン管理する方針にはリポジトリ内の設定、不変値にはコード上の定数を使う。
- 固定されたプロジェクト識別子やアプリケーション定数、機能や実装の選択、ビルドで確定する値、常に一致させる必要がある重複した選択値には環境変数を使わない。
- 環境変数を追加、改名、削除する前に、設定元と利用箇所、テスト、テンプレート、配備設定をすべて調べる。管理元を一つに定め、暗黙の既定値を避け、環境変数テンプレートも同じ変更で更新する。

## Agent Instruction Sources

- `home/AGENTS.md` contains global rules for work in every repository. Do not put dotfiles- or chezmoi-specific guidance there.
- Root `AGENTS.md` contains shared instructions for this repository.
- Root `CLAUDE.md` imports root `AGENTS.md` and adds only Claude-specific guidance.
- Product-specific global templates under `home/dot_{claude,codex,gemini}/` include `home/AGENTS.md` and append only product-specific tool behavior.
- Keep global, repository-specific, and product-specific instructions separate; do not duplicate rule text across layers.

## Common Commands

```bash
make -C bootstrap full
make -C bootstrap standard
make -C bootstrap minimal

chezmoi diff
chezmoi apply -v
```

## Verification

- Run the narrowest relevant checks first.
- For general repository changes, run `prek run --files <changed-files>` and `bash scripts/check-stale.sh`.
- For agent instructions or shell tool management, also run:

```bash
mise run check-agent-environment
bash scripts/test-rtk-rewrite-hook.sh
```

- After changing managed files, verify both `chezmoi diff` and the deployed behavior.
- Shell configuration changes require a fresh shell or `source ~/.zshrc` as appropriate.
- Hammerspoon changes require `hs -c "hs.reload()"` or the documented AppleScript reload path.
- Bootstrap scripts should use their dry-run mode when available.

## RTK Integration

- RTK is installed through `home/private_dot_config/mise/config.toml` and updated by maintenance.
- Claude Bash commands pass through two ordered `PreToolUse` hooks configured in `home/dot_claude/settings.json`: `ensure-mise-path.sh` first, then `rtk-rewrite.sh`.
- `home/dot_claude/hooks/executable_rtk-rewrite.sh` delegates supported rewrites and permission decisions to `rtk rewrite`. It requires `jq` and RTK 0.23.0 or newer.
- Preserve the rewrite protocol: exit 0 rewrites and auto-allows, exit 1 or 2 passes through, exit 3 rewrites without auto-allowing so Claude can ask, and unexpected failures emit a warning before passing through.
- RTK 0.43.0 cannot execute some compound `find` expressions that it rewrites. Keep native `find` for expressions containing `-o`, `-not`, `-exec`, `-execdir`, `-delete`, or parentheses until upstream behavior is verified compatible.
- Any change to RTK versions, hook ordering, rewrite handling, or the compound-`find` guard must run `bash scripts/test-rtk-rewrite-hook.sh` and the agent environment check.
- Do not remove a compatibility guard solely because RTK was upgraded; reproduce the formerly failing command against the installed version first.

## Specialized Changes

- When adding a tool to `home/private_dot_config/mise/config.toml`, run `mise install` and ensure shims resolve in a clean shell.
- Keep the deployed Claude rule files documented and intact: `rules/bigquery.md`, `rules/git.md`, `rules/gpu.md`, and `rules/python.md`.
