## Bootstrap (Mac / Ubuntu 22.04)

Minimal, reproducible setup for new machines. Destructive actions always ask for confirmation.

### Quick Start

- macOS (apps included)
  ```bash
  make -C bootstrap macos
  ```

- Ubuntu 22.04
  ```bash
  make -C bootstrap linux
  ```

### What It Does

- macOS
  - Installs Homebrew apps from `macos/Brewfile` (VS Code, Docker, Claude, ChatGPT, Discord, Zoom, etc.)
  - Applies system defaults (`20_defaults.sh`)
  - Applies pointer/trackpad settings from `macos/pointer/prefs/pointer_values.sh`
  - Binds iTerm2 prefs if `bootstrap/iterm2/com.googlecode.iterm2.plist` exists
  - Sets Git identity, SSH, dotfiles (prezto/tpm/chezmoi/mise), then cleanup

- Ubuntu 22.04
  - Validates OS version, installs base packages
  - Installs Docker + CLIs, cleans up
  - Detects NVIDIA GPU and offers driver/CUDA install with confirmation

### Customize

- Apps: edit `bootstrap/macos/Brewfile`
- Pointer: edit `bootstrap/macos/pointer/prefs/pointer_values.sh`
- iTerm2: put `bootstrap/iterm2/com.googlecode.iterm2.plist` and re-run macOS setup

### Manual Steps

- `gh auth login`, `tailscale up`
- Re-login after adding user to Docker group
- iTerm2 restart after prefs binding; Google Japanese IME may require macOS restart

### Support

- macOS (Homebrew-based)
- Ubuntu 22.04 LTS only

## Troubleshooting

- If a Brew cask name changes (e.g., third-party apps), update `bootstrap/macos/Brewfile` and re-run `brew bundle`.
- If iTerm2 prefs do not apply, confirm the file exists: `bootstrap/iterm2/com.googlecode.iterm2.plist`, then re-run `bash bootstrap/macos/35_iterm_prefs.sh` and restart iTerm2.
- Use `--dry-run` with Linux bootstrap to preview planned actions without executing.

## SSH Setup (Client vs Server)

This section documents a simple and repeatable SSH setup flow. Adjust hostnames and usernames for your environment.

### Client Side (macOS/Linux)

Generate a key and add it to your agent.

```bash
# Generate a key (RSA to match your current workflow). Consider ed25519 for new setups.
ssh-keygen -t rsa

# Add the key to your agent (macOS: adds to Keychain when supported)
ssh-add -A ~/.ssh/id_rsa || ssh-add ~/.ssh/id_rsa
```

Install `ssh-copy-id` and register your public key on servers.

```bash
brew install ssh-copy-id   # macOS; on Linux use your distro package manager

# Register your key on target servers
ssh-copy-id yuki@192.168.11.11
ssh-copy-id yuki@192.168.11.15
```

Maintain a user SSH config (example guidance):

- Reference: ssh-agent article (Japanese): https://zenn.dev/naoki_mochizuki/articles/ce381be617cd312ffe7f
- Your detailed host config: https://www.notion.so/ssh-config-65a76bc48a77480ba01782c073ff5ca4?pvs=21

### Server Side (Linux)

Verify SSH server is running and, if desired, tighten authentication.

```bash
sudo systemctl status sshd.service            # should be active (running)
sudo sudoedit /etc/ssh/sshd_config           # optionally set: PasswordAuthentication no
sudo systemctl reload sshd                   # apply config changes
```

After running `ssh-copy-id` from the client, confirm the key landed:

```bash
sudo ls -l /home/yuki/.ssh/authorized_keys
```

Connectivity test from client:

```bash
ssh -T git@github.com        # validates agent forwarding to GitHub if configured
ssh yuki@192.168.11.11       # verify interactive shell login
```

Notes:
- If you use Tailscale, prefer the Tailscale IP/hostname when available.
- Disable password auth only after confirming key-based login works, to avoid lockout.
