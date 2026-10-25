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
# Full setup: system packages/apps (including 1Password) + CLIs (with age) + dotfiles + mise install
make -C bootstrap full

# Standard: CLIs (no age) + dotfiles + mise install (no sudo on Linux)
make -C bootstrap standard

# Minimal: dotfiles only (chezmoi apply)
make -C bootstrap minimal

# Verify managed dotfiles, mise tools, and declared bootstrap state
make -C bootstrap verify
```

On macOS, `verify` checks the full declared state. Run it after the `full` plan; the `standard` plan intentionally leaves system defaults unapplied.

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
  - Applies system, pointer, trackpad, and Hot Corner settings declared in `home/private_dot_config/mise/config.toml`
  - Sets Git identity, SSH, dotfiles (prezto/tpm/chezmoi/mise), then cleanup

- Ubuntu 22.04 (full)
  - Validates OS version, installs base packages
  - Installs 1Password (amd64), Docker + CLIs, cleans up
  - Uses the official 1Password `.deb`, which configures its signing key and APT repository for updates
  - Detects NVIDIA GPU and offers driver/CUDA install with confirmation

- Ubuntu (user-only, `--user-only`)
  - Skips base packages and system-level setup (no sudo required)
  - Installs user-local CLIs (uv, mise, Claude Code, etc.); gh/gcloud/direnv/rye come from `mise install`
  - Sets up dotfiles (prezto, tpm, chezmoi)

### Customize

- macOS apps: edit `bootstrap/macos/Brewfile`
- Ubuntu system apps: edit `bootstrap/linux/modules/` and `bootstrap/linux/main.sh`
- macOS defaults: edit `home/private_dot_config/mise/config.toml`

### Manual Steps

- `gh auth login`, `tailscale up`
- On macOS with Orca installed, run `orca-browser-setup`, then import the Chrome work session into Orca's `Work` browser profile
- Re-login after adding user to Docker group
- Google Japanese IME may require macOS restart

### Support

- macOS (Homebrew-based)
- Ubuntu 22.04 LTS (full setup)
- Ubuntu (any version, user-only mode)

## Troubleshooting

- If a Brew cask name changes (e.g., third-party apps), update `bootstrap/macos/Brewfile` and re-run `brew bundle`.
- Use `--dry-run` with Linux bootstrap to preview planned actions without executing.

### 1Password on Ubuntu

The `full` plan installs the desktop app on amd64 Ubuntu. The `standard` and `minimal` plans do not install it because they run without sudo. ARM installations are not managed by this bootstrap.

To install only 1Password (without running the rest of the full setup):

```bash
bash bootstrap/linux/modules/15_1password.sh --dry-run
bash bootstrap/linux/modules/15_1password.sh
```

The orchestrator also accepts `--with-1password` alongside other system modules. After installation, update it with `sudo apt-get update && sudo apt-get install --only-upgrade 1password`.

Installation follows the [official 1Password Linux instructions](https://support.1password.com/install-linux/#debian-or-ubuntu). Open the app and sign in manually after installation.

### 1Password CLI and developer tools

`op` is managed by mise on macOS and Linux. To install it after updating the dotfiles:

```bash
chezmoi diff ~/.config/mise/config.toml
chezmoi apply ~/.config/mise/config.toml
mise install op
op --version
```

Open and unlock 1Password, then enable **Settings > Developer > Integrate with 1Password CLI**. Enable Touch ID on macOS, or **Settings > Security > Unlock using system authentication** on Linux, to authenticate through the app. Run `op whoami` to verify authentication. For multiple accounts, select one with `op signin` or pass `--account` per command.

On Linux, app integration also requires PolKit, a running authentication agent, and the CLI permissions described in the [official installation guide](https://developer.1password.com/docs/cli/get-started/). For the mise-managed binary:

```bash
sudo groupadd -f onepassword-cli
sudo chgrp onepassword-cli "$(mise which op)"
sudo chmod g+s "$(mise which op)"
```

Repeat the permission commands after mise installs a new CLI version. On headless Linux, use the CLI's manual sign-in or a scoped service account instead of desktop integration.

For development, store credentials in 1Password and copy each field's secret reference from the app. Put references in a project-local `.env.op` file, for example:

```dotenv
DATABASE_PASSWORD=op://Development/database/password
```

The vault, item, and field names above are placeholders. Use your copied reference, then inject the secret only into the process that needs it:

```bash
op run --env-file=.env.op -- npm run dev
```

For tools that require a configuration file, use `op inject -i config.yml.tpl -o config.yml` with references such as `{{ op://Development/database/password }}` in the template. The generated file contains plaintext secrets: exclude it from Git and remove it when no longer needed.

For API keys shared across projects, `with-api-key` supplies the selected key to a command from any directory:

```bash
with-api-key openai python app.py
with-api-key gemini gemini
with-api-key claude python app.py
with-api-key deepseek python app.py
with-api-key notion python sync.py
```

Save the keys as **API Credential** items named **OpenAI API**, **Gemini API**, **Claude API**, **DeepSeek API**, and **Notion API** in the **Personal** vault, using each item's **credential** field. The command sets `OPENAI_API_KEY`, `GEMINI_API_KEY`, `CLAUDE_API_KEY`, `DEEPSEEK_API_KEY`, or `NOTION_API_KEY` to the corresponding secret reference and resolves it with `op run`. The `claude` option preserves the existing `CLAUDE_API_KEY` variable name; it does not set `ANTHROPIC_API_KEY`. Use it with consumers of that variable. The command preserves any other environment variables inherited from the calling shell. It does not fetch keys when a shell starts. After verifying the commands that use each key, remove the old plaintext assignments from their original configuration and restart those shells or applications.

SSH and Git signing use the desktop app's built-in agent independently of `op`. Before applying the SSH and signing configuration on a new machine, import the GitHub private key matching `~/.ssh/1password-github.pub` into your Personal vault and enable **Settings > Developer > Use the SSH agent**. The public key is managed in this repository; the private key stays in 1Password.

The age-encrypted `~/.ssh/config` includes `~/.ssh/config.d/1password.conf`, which selects the 1Password agent for `github.com` with the socket path for macOS or Linux when the desktop app's SSH signer is installed. Machines without the app and other SSH hosts retain their existing authentication settings. SSH Bookmarks must not automatically edit this managed configuration.

When the desktop app's SSH signer is installed, the managed Git configuration includes `~/.config/git/1password.gitconfig` to sign commits with the same key. The managed `allowed_signers` file enables local signature verification. Machine-specific overrides can still go in `~/.gitconfig.local`. Register the public key in GitHub as a **Signing key** as well as an authentication key; both registrations are required to use one key for SSH access and GitHub-verified signatures. See the [SSH setup guide](https://developer.1password.com/docs/ssh/get-started/) and [Git signing guide](https://developer.1password.com/docs/ssh/git-commit-signing/).

See the official guides for [app integration](https://developer.1password.com/docs/cli/app-integration/) and [loading secrets into an application](https://developer.1password.com/docs/cli/secrets-environment-variables/).

### age key backup and restoration

`age-key.sh` backs up the existing `~/.config/chezmoi/key.txt` as a Document named **chezmoi age key** in the **Personal** 1Password vault. Run it from the repository checkout in a terminal authorized for 1Password CLI:

```bash
bash bootstrap/age-key.sh backup
```

It verifies that the local identity decrypts the repository's encrypted SSH configuration, saves it when no document exists, then downloads and compares the backup. A conflicting or ambiguous document fails without overwriting it.

On a new machine, install and sign in to the 1Password desktop app and enable CLI integration. From the checkout, install the required tools (including Python for exclusive key-file creation) from the managed mise configuration and restore the key before running `chezmoi init` or `chezmoi apply`:

```bash
mise -C home/private_dot_config/mise install op age jq python
mise -C home/private_dot_config/mise exec op age jq python -- bash "$PWD/bootstrap/age-key.sh" restore
```

The downloaded identity must decrypt this repository's encrypted SSH configuration before it is installed with mode `600`. Existing destination files and symlinks are refused, including files created while the download is in progress. An optional second argument selects another key-file path for backup or restoration. The key contents are never printed.

The repository's passphrase-protected `.age-key.age` and initial decryption script also remain available for passphrase-based setup. Daily chezmoi operations use the cached local identity.

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
