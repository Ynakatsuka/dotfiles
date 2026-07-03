# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Chezmoi-based dotfiles management system** for macOS and Ubuntu 22.04. Chezmoi handles configuration file deployment with conditional templating across multiple systems.

## Key Concepts

### Repository Layout

- `.chezmoiroot` points chezmoi at `home/`: **only files under `home/` deploy to `$HOME`**.
- Everything outside `home/` (`bootstrap/`, `scripts/`, `CLAUDE.md`, `README.md`, ...) is repo-only and never deployed.
- `home/.chezmoiremove` declaratively deletes stale, previously deployed targets on `chezmoi apply`.
- `home/.chezmoitemplates/` holds include-only sources (`mcp.json` manifest, shared `age-command.tmpl` resolution).

### Chezmoi File Naming Conventions (inside `home/`)

- `dot_` prefix → deployed as `.` (e.g., `home/dot_zshrc` → `~/.zshrc`)
- `private_` prefix → restricted permissions (600)
- `.tmpl` suffix → Go template files processed during deployment
- Files in `home/private_dot_config/` → deployed to `~/.config/`

### Directory Structure

- `home/` - Chezmoi source state (everything deployed to `$HOME`)
- `bootstrap/` - Platform-specific setup scripts (repo-only)
- `scripts/` - Repo maintenance utilities (repo-only)
- `home/dot_claude/` - Claude Code global configuration (deployed to `~/.claude/`)
- `home/dot_hammerspoon/` - macOS window management (Lua)

### Agent Instruction Pipeline

`home/AGENTS.md` is the single source of global agent rules. It reaches every agent via chezmoi:

- `~/AGENTS.md` (deployed verbatim)
- `~/CLAUDE.md` (via `home/CLAUDE.md.tmpl`)
- `~/.claude/CLAUDE.md` (via `home/dot_claude/CLAUDE.md.tmpl`)
- `~/.codex/AGENTS.md` (via `home/dot_codex/AGENTS.md.tmpl`, which appends Codex-only extras)
- `~/.gemini/GEMINI.md` (via `home/dot_gemini/GEMINI.md.tmpl`)

Edit `home/AGENTS.md` once; never fork rule text into the templates. Claude-only domain detail lives in `home/dot_claude/rules/*.md` (path-scoped via `paths:` frontmatter where applicable). Repo-specific guidance stays in this file, which is intentionally NOT deployed.

## Common Commands

### Bootstrap

OS is auto-detected via `uname`. Choose a plan:

```bash
make -C bootstrap full      # Everything: system packages, apps, CLIs, dotfiles, age, mise
make -C bootstrap standard  # CLIs + dotfiles + mise (no sudo on Linux, no age)
make -C bootstrap minimal   # Dotfiles only (chezmoi apply)
```

### Chezmoi Operations

```bash
chezmoi managed            # List all managed files
chezmoi add <file>         # Add file to management
chezmoi edit <file>        # Edit a managed file
chezmoi apply -v           # Apply changes to home directory
chezmoi update -v          # Pull remote changes and apply
chezmoi diff               # Preview changes before applying
```

### Testing Changes

```bash
# Preview what chezmoi will deploy (dry run)
chezmoi diff

# Apply and verify
chezmoi apply -v
source ~/.zshrc            # Reload shell config
tmux source ~/.tmux.conf   # Reload tmux config
```

## Architecture Notes

### Repository Location

The authoritative repository and chezmoi source are both `~/ghq/github.com/Ynakatsuka/dotfiles/`.
`~/.config/chezmoi/chezmoi.toml` sets `sourceDir` to that path; `.chezmoiroot` then narrows the source state to `home/`.

### Template Processing

Files ending in `.tmpl` use Go templates. Common patterns:
- `{{- include "AGENTS.md" -}}` - Include another file (paths resolve relative to `home/`)
- Platform-conditional content using chezmoi's built-in variables (`{{ if eq .chezmoi.os "darwin" }}`)

### Bootstrap Modules

Each platform has its own numbered module set, orchestrated by `main.sh`:

- `bootstrap/macos/`: `00_xcode_brew`, `10_git`, `20_defaults`, `22_pointer`, `25_hotcorners`, `31_cmux`, `40_ssh`, `45_dotfiles`
- `bootstrap/linux/modules/`: `00_base`, `05_expressvpn`, `10_gpu_nvidia`, `20_docker`, `25_nvidia_container`, `30_clis`, `40_dotfiles`, `99_cleanup`

Numbers control execution order only; see each `main.sh` for which modules a plan runs.

### Claude Configuration Structure

The `home/dot_claude/` directory deploys as `~/.claude/`:
- `CLAUDE.md.tmpl` → Global instructions (includes AGENTS.md)
- `rules/` → Domain-specific rules (bigquery, git, gpu, python)
- `skills/` → Skill definitions for Claude Code (also symlinked into `~/.codex/skills/` by a run_onchange script)

## Skill Authoring

When creating or modifying skills (`home/dot_claude/skills/*/SKILL.md`), always use the `my-skill-creator` skill first to ensure compliance with the frontmatter spec and design guidelines.

## Critical Rules

### File Placement

**NEVER create files directly under `~/` (e.g., `~/.claude/`, `~/.codex/`).** All configuration files MUST be created in this dotfiles repository (under `home/`) first, then deployed. Creating files outside this repo means they won't be tracked by Git.

- `~/.claude/` files → create in `home/dot_claude/`
- `~/.codex/` files → create in `home/dot_codex/`
- `~/.config/` files → create in `home/private_dot_config/`

After editing, run `chezmoi apply` (or `chezmoi diff` first to preview).

## When Editing

### Shell Configuration

`home/dot_zshrc` is a thin loader; the actual FZF integrations, git worktree helpers, and tool initialization live in `home/private_dot_config/zsh/*.zsh` modules. Changes require `source ~/.zshrc` to test.

### Adding New Tools to mise (`home/dot_mise.toml`)

After editing, run `mise install` to install new tools.

### Hammerspoon (`home/dot_hammerspoon/init.lua`)

After editing, the config must be reloaded inside the running Hammerspoon app (see reload commands below). The repo enables both reload paths via `require("hs.ipc")` and `hs.allowAppleScript(true)`:

```bash
hs -c "hs.reload()"
# or
osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"'
```

Note: after a fresh install you must Reload Config **once manually** from the Hammerspoon menu bar before the CLI/AppleScript paths work.

### Chezmoi Source

```bash
chezmoi git pull -- --ff-only
chezmoi apply -v
```

### Modifying Bootstrap Scripts

Test with `--dry-run` flag when available. Scripts use confirmation prompts for destructive actions.
