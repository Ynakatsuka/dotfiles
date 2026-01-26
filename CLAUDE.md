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
- `commands/` - Claude/Cursor command templates and skills
- `dot_claude/` - Claude Code global configuration (deployed to `~/.claude/`)
- `dot_cursor/` - Cursor editor configuration
- `dot_hammerspoon/` - macOS window management (Lua)

## Common Commands

### Bootstrap

```bash
# Full setup
make -C bootstrap macos           # macOS with apps
make -C bootstrap linux           # Ubuntu 22.04

# Dotfiles only
make -C bootstrap macos-dotfiles
make -C bootstrap linux-dotfiles
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
- `commands/` → Skill definitions for Claude Code

## When Editing

### Shell Configuration (`dot_zshrc`)

Contains extensive FZF integrations, git worktree management, and tool initialization. Changes require `source ~/.zshrc` to test.

### Adding New Tools to mise (`dot_mise.toml`)

After editing, run `mise install` to install new tools.

### Modifying Bootstrap Scripts

Test with `--dry-run` flag when available. Scripts use confirmation prompts for destructive actions.
