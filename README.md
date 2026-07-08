# dotfiles

Personal dotfiles managed with `chezmoi`.

This repository bootstraps a working shell and development environment for macOS and Ubuntu, with a bias toward fast terminal workflows and reproducible machine setup.

## What This Repo Manages

- Shell environment: `zsh`, `bash`, aliases, FZF helpers
- Git workflow: aliases, worktree helpers
- Terminal tools: `tmux`, `mise`, `direnv`, CLI setup
- Desktop automation: Hammerspoon window layouts
- AI tooling: Claude Code / Codex / Gemini related config
- Secrets with encryption: SSH and gcloud config via `age`

## Repository Layout

`.chezmoiroot` points chezmoi at `home/`, so only files under `home/` deploy to `$HOME`:

| Path | Purpose |
|------|---------|
| `home/` | Chezmoi source state (deployed to `$HOME`) |
| `bootstrap/` | Machine setup scripts (repo-only) |
| `scripts/` | Repo maintenance utilities (repo-only) |

## Quick Start

OS (macOS / Linux) is auto-detected. Choose a plan:

```bash
make -C bootstrap full      # Everything: system packages, apps, CLIs, dotfiles, mise tools
make -C bootstrap standard  # CLIs + dotfiles + mise tools (no sudo on Linux)
make -C bootstrap minimal   # Dotfiles only (chezmoi apply)
```

### One-Liner Install

No Git clone required. Fastest path for a user-local Linux setup:

```bash
DOTFILES_SOURCE="$HOME/ghq/github.com/Ynakatsuka/dotfiles" && \
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" && \
  "$HOME/.local/bin/chezmoi" -S "$DOTFILES_SOURCE" init --apply Ynakatsuka/dotfiles && \
  make -C "$DOTFILES_SOURCE/bootstrap" standard
```

Detailed bootstrap behavior lives in [bootstrap/README.md](bootstrap/README.md).

## Common Tasks

### Bootstrap Plans

| Command | Purpose |
|---------|---------|
| `make -C bootstrap full` | Full bootstrap (system packages + apps + CLIs + dotfiles + age + mise) |
| `make -C bootstrap standard` | CLIs + dotfiles + mise (no sudo on Linux, no age encryption) |
| `make -C bootstrap minimal` | Dotfiles only (chezmoi apply) |

### Chezmoi

| Command | Purpose |
|---------|---------|
| `chezmoi managed` | List managed files |
| `chezmoi add <file>` | Add a file to management |
| `chezmoi forget <file>` | Stop managing a file |
| `chezmoi edit <file>` | Edit a managed file |
| `chezmoi apply -v` | Apply local source changes |
| `chezmoi update -v` | Pull remote changes and apply them |
| `chezmoi cd` | Jump to the source directory |

### Reload Config

```bash
source ~/.zshrc
tmux source ~/.tmux.conf
```

For a forced re-init:

```bash
chezmoi -S "$HOME/ghq/github.com/Ynakatsuka/dotfiles" init --apply https://github.com/Ynakatsuka/dotfiles.git --force
```

## Shortcuts

### Shell Keybindings

| Keybinding | Action |
|------------|--------|
| `Ctrl+H` | FZF history search |
| `Ctrl+B` | FZF git branch checkout |
| `Ctrl+F` | FZF recent directory navigation (`cdr`) |
| `Ctrl+G` | GCloud configuration selector with login |
| `Ctrl+R` | FZF `ghq` repository search |
| `Ctrl+O` | Copy the last command output to the clipboard |
| `Ctrl+K` | Resume a recent Claude Code or Codex session for the current directory |

`Ctrl+K` lists up to 50 recent sessions by default. Set `FZF_SESSION_RESUME_LIMIT` to adjust the limit.

### Git

| Alias / Command | Action |
|-----------------|--------|
| `st` | `git status` |
| `ch` | `git checkout` |
| `chb` | `git checkout -b` |
| `ps` | `git push` |
| `pl` | `git pull` |
| `ft` | `git fetch` |
| `cm` | `git commit` |
| `br` | `git branch` |
| `lb` | Select a branch with FZF |
| `gw` | Create or switch a worktree with FZF, newest first |
| `gw <branch>` | Open or create a worktree for a branch |
| `gwai-cmux` | Open a left-sidebar cmux tab, create an AI-named worktree from the top cmux tab, and start Claude/Codex |
| `gwc [-j jobs]` | Remove worktrees in parallel with multi-select confirmation |
| `gwt` | `git worktree` |
| `gwta` | `git worktree add` |
| `gwtl` | `git worktree list` |
| `gwtr` | `git worktree remove` |

### Docker

| Alias | Action |
|-------|--------|
| `dc` | `docker compose` |
| `dcps` | `docker compose ps` |
| `dcud` | `docker compose up -d` |
| `dcudb` | `docker compose up -d --build` |
| `dcudf` | `docker compose up -d --force-recreate` |
| `dce` | `docker compose exec` with service selection |
| `dcl` | `docker compose logs` |
| `dcd` | `docker compose down` |
| `de` | Interactive `docker exec` with FZF |

### GCloud

| Alias | Action |
|-------|--------|
| `gca` | `gcloud config configurations activate` |
| `gcl` | `gcloud config configurations list` |
| `gal` | `gcloud auth application-default login` |
| `gcsp` | `gcloud config set project` |

### Claude Code

| Command | Action |
|---------|--------|
| `cl` | Launch Claude Code with repo-local MCP config when available |

### Hammerspoon

| Keybinding | Action |
|------------|--------|
| `Alt+Ctrl+H` | Apply the smart layout for the current display setup |
| `Alt+Ctrl+E` | Force the external display layout |
| `Alt+Ctrl+I` | Force the built-in display layout |

External display layout:

- Left 45%: Sublime Text (top 20%), Google Chrome (bottom 80%)
- Right 55%: ghostty (top 25%), Cursor (bottom 75%)

Built-in display layout:

- Top 40%: Sublime Text, ghostty
- Fullscreen: Google Chrome, Cursor

### Tmux

Default prefix: `Ctrl+b`

| Keybinding | Action |
|------------|--------|
| `prefix + I` | Install plugins with TPM |

Installed plugins:

- `tmux-plugins/tpm`
- `tmux-plugins/tmux-sensible`

## Encrypted Files

Sensitive files are managed with [`age`](https://github.com/FiloSottile/age) encryption.

The repository stores the `age` private key itself as a passphrase-protected file (`.age-key.age`). On the first `chezmoi apply`, that key is decrypted and cached at `~/.config/chezmoi/key.txt`. After that, the passphrase is not required again on the same machine.

### Encrypted Paths

| Source | Deployed To |
|--------|-------------|
| `home/private_dot_ssh/encrypted_private_config.age` | `~/.ssh/config` |
| `home/private_dot_config/gcloud/configurations/encrypted_config_*.age` | `~/.config/gcloud/configurations/` |
| `home/.age-key.age` | `~/.config/chezmoi/key.txt` |

### Add a New Encrypted File

```bash
chezmoi add --encrypt <file>
```

### Install `age`

```bash
# macOS
brew install age

# Ubuntu
sudo apt-get install -y age
```

Bootstrap on Linux also installs `age`.

### First-Time Setup on a New Machine

```bash
chezmoi -S "$HOME/ghq/github.com/Ynakatsuka/dotfiles" init https://github.com/Ynakatsuka/dotfiles.git
chezmoi apply -v
```

You will be asked for the passphrase once to decrypt the repository key.

## Notes

### bash-completion on Ubuntu

```bash
sudo apt-get update && sudo apt-get install -y bash-completion
```

### Change the Default Shell

```bash
chsh -s "$(which zsh)"
```

## References

- https://www.chezmoi.io/
- https://mise.jdx.dev/
