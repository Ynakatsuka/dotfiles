# dotfiles

## Quick Start

```bash
# macOS
make -C bootstrap macos-dotfiles

# Ubuntu 22.04
make -C bootstrap linux-dotfiles
```

## Commands & Shortcuts

### Zsh Keybindings

| Keybinding | Description |
|------------|-------------|
| `Ctrl+H` | FZF history search |
| `Ctrl+F` | FZF recent directory navigation (cdr) |
| `Ctrl+G` | GCloud configuration selector with login |
| `Ctrl+R` | FZF ghq repository search |
| `Ctrl+O` | Copy last command output to clipboard |

### Hammerspoon Window Management

| Keybinding | Description |
|------------|-------------|
| `Alt+Ctrl+H` | Smart layout (auto-detect display type) |
| `Alt+Ctrl+E` | Force external display layout (4-split) |
| `Alt+Ctrl+I` | Force built-in display layout |

**External Display Layout:**
- Left 45%: Sublime Text (top 20%) / Chrome (bottom 80%)
- Right 55%: ghostty (top 25%) / Cursor (bottom 75%)

**Built-in Display Layout:**
- Top 40%: Sublime Text, ghostty
- Fullscreen: Chrome, Cursor

### Git Aliases

| Alias | Command |
|-------|---------|
| `st` | `git status` |
| `ch` | `git checkout` |
| `chb` | `git checkout -b` |
| `ps` | `git push` |
| `pl` | `git pull` |
| `ft` | `git fetch` |
| `cm` | `git commit` |
| `br` | `git branch` |
| `lb` | Select branch with FZF |

### Git Worktree Management

| Command | Description |
|---------|-------------|
| `gw` | Smart worktree manager (create/switch with FZF) |
| `gw <branch>` | Create or switch to worktree for branch |
| `gwc` | Cleanup worktrees (FZF multi-select) |
| `gwt` | `git worktree` |
| `gwta` | `git worktree add` |
| `gwtl` | `git worktree list` |
| `gwtr` | `git worktree remove` |

### Docker Aliases

| Alias | Command |
|-------|---------|
| `dc` | `docker compose` |
| `dcps` | `docker compose ps` |
| `dcud` | `docker compose up -d` |
| `dcudb` | `docker compose up -d --build` |
| `dcudf` | `docker compose up -d --force-recreate` |
| `dce` | `docker compose exec` (auto-select service) |
| `dcl` | `docker compose logs` |
| `dcd` | `docker compose down` |
| `de` | Interactive docker exec with FZF |

### GCloud Aliases

| Alias | Command |
|-------|---------|
| `gca` | `gcloud config configurations activate` |
| `gcl` | `gcloud config configurations list` |
| `gal` | `gcloud auth application-default login` |
| `gcsp` | `gcloud config set project` |

### Claude Code

| Command | Description |
|---------|-------------|
| `cl` | Launch Claude Code with MCP config (auto-detect) |

### Tmux

Default prefix: `Ctrl+b`

| Keybinding | Description |
|------------|-------------|
| `prefix + I` | Install plugins (TPM) |

Installed plugins:
- `tmux-plugins/tpm` - Plugin manager
- `tmux-plugins/tmux-sensible` - Sensible defaults
- `Morantron/tmux-fingers` - Copy text with hints

## Chezmoi Usage

### Basic Operations

| Command | Description |
|---------|-------------|
| `chezmoi managed` | List managed files |
| `chezmoi add <file>` | Add file to management |
| `chezmoi forget <file>` | Remove file from management |
| `chezmoi edit <file>` | Edit a managed file |
| `chezmoi apply -v` | Apply changes |
| `chezmoi cd` | Go to chezmoi source directory |
| `chezmoi update -v` | Pull and apply remote changes |

### Force Sync

```bash
chezmoi init --apply https://github.com/Ynakatsuka/dotfiles.git --force
```

### Reload Configs

```bash
source $HOME/.zshrc
tmux source $HOME/.tmux.conf
```

## Other Dependencies

### bash-completion (Ubuntu)

```bash
sudo apt-get update && sudo apt-get install -y bash-completion
```

## Other Tricks

### Change Default Shell

```bash
chsh -s $(which zsh)
```

### Reload Tmux Config

```bash
tmux source ~/.tmux.conf
```

Then press `prefix + I` to install plugins.

## Bootstrap (Linux/macOS)

Please see `bootstrap/README.md` for complete, up‑to‑date bootstrap instructions for macOS and Ubuntu 22.04.

## References

- https://www.chezmoi.io/
- https://mise.jdx.dev/
