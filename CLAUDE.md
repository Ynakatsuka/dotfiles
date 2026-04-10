# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Chezmoi-based dotfiles management system** for macOS and Ubuntu 22.04. Chezmoi handles configuration file deployment with conditional templating across multiple systems.

## Key Concepts

### Chezmoi File Naming Conventions

- `dot_` prefix → deployed as `.` (e.g., `dot_zshrc` → `~/.zshrc`)
- `private_` prefix → restricted permissions (600)
- `.tmpl` suffix → Go template files processed during deployment
- Files in `private_dot_config/` → deployed to `~/.config/`

### Directory Structure

- `bootstrap/` - Platform-specific setup scripts (modular, numbered 00-99)
- `dot_claude/` - Claude Code global configuration (deployed to `~/.claude/`)
- `dot_cursor/` - Cursor editor configuration
- `dot_hammerspoon/` - macOS window management (Lua)

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

This repository may have multiple clones on the system:
- **Primary (authoritative)**: `~/ghq/github.com/Ynakatsuka/dotfiles/`
- **Chezmoi source**: `~/.local/share/chezmoi/` (used by chezmoi for deployment)

Always edit files in the `ghq` directory. Changes need to be committed/pushed from there and pulled into the chezmoi source directory, or applied directly to both locations.

### Template Processing

Files ending in `.tmpl` use Go templates. Common patterns:
- `{{- include "AGENTS.md" -}}` - Include another file
- Platform-conditional content using chezmoi's built-in variables

### Bootstrap Modules

Bootstrap scripts are numbered for execution order:
- `00_*` - Prerequisites (Xcode, Homebrew)
- `10_*` - Core tools (Git)
- `20-30_*` - System configuration
- `40_*` - SSH and dotfiles deployment

### Claude Configuration Structure

The `dot_claude/` directory deploys as `~/.claude/`:
- `CLAUDE.md.tmpl` → Global instructions (includes AGENTS.md)
- `rules/` → Domain-specific rules (bigquery, python, gpu, git)
- `skills/` → Skill definitions for Claude Code

## Skill Authoring

When creating or modifying skills (`dot_claude/skills/*/SKILL.md`), always use the `my-skill-creator` skill first to ensure compliance with the frontmatter spec and design guidelines.

## Critical Rules

### File Placement

**NEVER create files directly under `~/` (e.g., `~/.claude/`, `~/.codex/`).** All configuration files MUST be created in this dotfiles repository (`dot_` prefixed) first, then deployed. Creating files outside this repo means they won't be tracked by Git.

- `~/.claude/` files → create in `dot_claude/`
- `~/.codex/` files → create in `dot_codex/`
- `~/.config/` files → create in `private_dot_config/`

After editing, manually copy to the deploy target or run `chezmoi apply`.

## When Editing

### Shell Configuration (`dot_zshrc`)

Contains extensive FZF integrations, git worktree management, and tool initialization. Changes require `source ~/.zshrc` to test.

### Adding New Tools to mise (`dot_mise.toml`)

After editing, run `mise install` to install new tools.

### Hammerspoon (`dot_hammerspoon/init.lua`)

After editing, the config must be reloaded inside the running Hammerspoon app (see reload commands below). The repo enables both reload paths via `require("hs.ipc")` and `hs.allowAppleScript(true)`:

```bash
hs -c "hs.reload()"
# or
osascript -e 'tell application "Hammerspoon" to execute lua code "hs.reload()"'
```

Note: after a fresh install you must Reload Config **once manually** from the Hammerspoon menu bar before the CLI/AppleScript paths work.

### Chezmoi Source vs ghq Clone

The chezmoi source dir (`~/.local/share/chezmoi/`) is a separate git clone from the authoritative ghq dir. `chezmoi apply` reads from the chezmoi source, NOT the ghq dir. After committing in ghq, sync the chezmoi source before applying:

```bash
git -C ~/.local/share/chezmoi pull
chezmoi apply -v
```

### Modifying Bootstrap Scripts

Test with `--dry-run` flag when available. Scripts use confirmation prompts for destructive actions.
