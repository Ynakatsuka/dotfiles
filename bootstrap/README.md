## Bootstrap (Mac / Ubuntu)

Minimal, reproducible setup for new machines. Destructive actions always ask for confirmation.

### Quick Start

- macOS (apps + system defaults included)
  ```bash
  make -C bootstrap full
  ```

- Ubuntu 22.04 (requires sudo)
  ```bash
  make -C bootstrap full
  ```

### Make Targets

```bash
# Full setup: system packages/apps + CLIs (with age) + dotfiles + mise install
make -C bootstrap full

# Standard: CLIs (no age) + dotfiles + mise install (no sudo on Linux)
make -C bootstrap standard

# Minimal: dotfiles only (chezmoi apply)
make -C bootstrap minimal
```

### Quick Setup (No Git Clone Required)

Set up user-local environment with a single command. Requires `curl`, `git`, and `make`.

```bash
DOTFILES_SOURCE="$HOME/ghq/github.com/Ynakatsuka/dotfiles" && \
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" && \
  "$HOME/.local/bin/chezmoi" -S "$DOTFILES_SOURCE" init --apply Ynakatsuka/dotfiles && \
  make -C "$DOTFILES_SOURCE/bootstrap" standard
```

### Pre‑clone Setup (Fresh Machines)

If the machine does not have Git yet, use one of these minimal flows to obtain this repository first.

- macOS
  ```bash
  xcode-select --install
  git clone https://github.com/Ynakatsuka/dotfiles.git "$HOME/ghq/github.com/Ynakatsuka/dotfiles"
  cd "$HOME/ghq/github.com/Ynakatsuka/dotfiles"
  make -C bootstrap full
  ```

- Ubuntu 22.04
  ```bash
  sudo apt-get update && sudo apt-get install -y git curl
  git clone https://github.com/Ynakatsuka/dotfiles.git "$HOME/ghq/github.com/Ynakatsuka/dotfiles"
  cd "$HOME/ghq/github.com/Ynakatsuka/dotfiles"
  make -C bootstrap full
  ```

### What It Does

- macOS
  - Installs Homebrew apps from `macos/Brewfile` (VS Code, Docker, Claude, ChatGPT, Discord, Zoom, etc.)
  - Applies system defaults (`20_defaults.sh`)
  - Applies pointer/trackpad settings from `macos/pointer/prefs/pointer_values.sh`
  - Sets Git identity, SSH, dotfiles (prezto/tpm/chezmoi/mise), then cleanup

- Ubuntu 22.04 (full)
  - Validates OS version, installs base packages
  - Installs Docker + CLIs, cleans up
  - Detects NVIDIA GPU and offers driver/CUDA install with confirmation

- Ubuntu (user-only, `--user-only`)
  - Skips base packages and system-level setup (no sudo required)
  - Installs user-local CLIs (uv, mise, Claude Code, etc.); gh/gcloud/direnv/rye come from `mise install`
  - Sets up dotfiles (prezto, tpm, chezmoi)

### Customize

- Apps: edit `bootstrap/macos/Brewfile`
- Pointer: edit `bootstrap/macos/pointer/prefs/pointer_values.sh`

### Manual Steps

- `gh auth login`, `tailscale up`
- Re-login after adding user to Docker group
- Google Japanese IME may require macOS restart

### Support

- macOS (Homebrew-based)
- Ubuntu 22.04 LTS (full setup)
- Ubuntu (any version, user-only mode)

## Troubleshooting

- If a Brew cask name changes (e.g., third-party apps), update `bootstrap/macos/Brewfile` and re-run `brew bundle`.
- Use `--dry-run` with Linux bootstrap to preview planned actions without executing.

## SSH Setup (Client vs Server)

This section documents a simple and repeatable SSH setup flow. Adjust hostnames and usernames for your environment.

### Client Side (macOS/Linux)

Generate a key and add it to your agent.

```bash
# Generate an ed25519 key (recommended for new setups)
ssh-keygen -t ed25519

# Add the key to your agent (macOS: adds to Keychain when supported)
ssh-add -A ~/.ssh/id_ed25519 || ssh-add ~/.ssh/id_ed25519
```

Install `ssh-copy-id` and register your public key on servers.

```bash
brew install ssh-copy-id   # macOS; on Linux use your distro package manager

# Register your key on target servers
ssh-copy-id <user>@<server-ip>
```

Maintain a user SSH config (example guidance):

- Reference: ssh-agent article (Japanese): https://zenn.dev/naoki_mochizuki/articles/ce381be617cd312ffe7f

### Server Side (Linux)

Verify SSH server is running and, if desired, tighten authentication.

```bash
sudo systemctl status sshd.service            # should be active (running)
sudo sudoedit /etc/ssh/sshd_config           # optionally set: PasswordAuthentication no
sudo systemctl reload sshd                   # apply config changes
```

After running `ssh-copy-id` from the client, confirm the key landed:

```bash
sudo ls -l /home/<user>/.ssh/authorized_keys
```

Connectivity test from client:

```bash
ssh -T git@github.com        # validates agent forwarding to GitHub if configured
ssh <user>@<server-ip>       # verify interactive shell login
```

Notes:
- If you use Tailscale, prefer the Tailscale IP/hostname when available.
- Disable password auth only after confirming key-based login works, to avoid lockout.
