# dotfiles

Personal dotfiles managed with `chezmoi`.

This repository bootstraps a working shell and development environment for macOS and Ubuntu, with a bias toward fast terminal workflows and reproducible machine setup.

## What This Repo Manages

- Shell environment: `zsh`, `bash`, aliases, FZF helpers
- Git workflow: aliases, worktree helpers
- Terminal tools: `tmux`, `mise`, `direnv`, CLI setup
- Desktop automation: Hammerspoon window layouts
- AI tooling: Claude Code / Codex / Antigravity CLI related config
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
make -C bootstrap verify    # Verify chezmoi and mise bootstrap convergence
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
| `make -C bootstrap verify` | Verify the full declared chezmoi and mise bootstrap state |

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

`mise run maintenance` pulls the dotfiles source, applies it with `--force`,
and verifies the managed target state before updating tools. Managed target
changes and files listed in `home/.chezmoiremove` are overwritten or removed
during apply; unmanaged files are outside this cleanup.

### Tests

Run every repository test from one command, or list and select cases by name:

```bash
bash scripts/test.sh
bash scripts/test.sh --list
bash scripts/test.sh test-delegation my-handoff
```

The runner covers `scripts/test-*.sh`, `scripts/test-*.zsh`, the Japanese editor's Python unit tests, and the handoff Node tests. It checks required tools before running selected cases and reports all failures at the end. `test-prune-old-worktrees` uses GNU `date` and `touch`, so the full suite reports it as skipped on macOS; selecting it there is an error. CI runs the full suite on Linux.

### Reload Config

```bash
source ~/.zshrc
tmux source ~/.tmux.conf
```

For a forced re-init:

```bash
chezmoi -S "$HOME/ghq/github.com/Ynakatsuka/dotfiles" init --apply https://github.com/Ynakatsuka/dotfiles.git --force
```

### Agent Instructions

Agent instructions are layered by scope. Root files describe only this repository. Files under `home/` are deployed globally and therefore must not contain dotfiles- or chezmoi-specific rules:

| Source | Scope / Destination |
|--------|---------------------|
| `AGENTS.md` | This repository, shared across compatible agents |
| `CLAUDE.md` | This repository, Claude-specific additions |
| `home/AGENTS.md` | Global shared rules → `~/AGENTS.md` |
| `home/dot_claude/CLAUDE.md.tmpl` | Global Claude additions → `~/.claude/CLAUDE.md` |
| `home/dot_codex/AGENTS.md.tmpl` | Global Codex additions → `~/.codex/AGENTS.md` |
| `home/dot_gemini/GEMINI.md.tmpl` | Global Antigravity CLI (`agy`) rules → `~/.gemini/GEMINI.md` |

Run these checks after changing agent instructions or shell tool management:

```bash
mise run check-agent-environment
bash scripts/test-rtk-rewrite-hook.sh
bash scripts/test-delegation.sh
codex exec --ephemeral --sandbox read-only -c 'approval_policy="never"' \
  "Summarize the current instructions and list their source files. Do not modify files."
```

For interactive clients, use `/memory` in Claude Code to inspect the loaded instruction context. Restart an active session after changing persistent instructions.

### Codex Subagent Policy

`home/dot_codex/private_config.toml.tmpl` is the sole managed source for
Codex subagent defaults. Its standard `[agents]` section is deployed to
`~/.codex/config.toml` by:

```bash
chezmoi apply
```

The config template preserves Codex-managed desktop preferences, hook trust
state, the ChatGPT app's `notify`, `marketplaces`, `plugins`, and `mcp_servers`
entries, and project entries whose paths do not exactly match the home directory
or a ghq repository root. Those exact paths remain trusted by the dotfiles
policy; existing entries for subdirectories are preserved while their paths
exist. Entries for paths that no longer exist, such as removed worktrees, are
dropped when the template renders. `cdx` trusts its project and Git root for
each run through `-c projects={...}` instead of writing them to `config.toml`.
Run `bash scripts/test-codex-config.sh` to verify config preservation and
idempotence, and `bash scripts/test-codex-cdx-trust.sh` to verify `cdx` trust.

The Browser service registration belongs to the ChatGPT app, not to a pinned
dotfiles version. Before preserving an enabled `node_repl` registration, the
template checks that its absolute `browser` service path names an existing
file. A missing file stops rendering, including `chezmoi diff` and `apply`,
with a repair message instead of copying the stale registration forward.
Other trusted services and MCP servers remain unchanged. Module specifiers
and file URLs are resolved by the runtime and are not checked by this guard.

The ChatGPT app copies its bundled plugins into `~/.codex/plugins/cache/` only
at startup. If that copy fails, the app can still register the new version's
path. To repair it:

1. Quit ChatGPT and relaunch it from the Dock or Finder, or run
   `env -u CODEX_HOME open -a ChatGPT`. `open` passes the shell environment to
   the app, so a terminal `CODEX_HOME`, such as the one Orca sets, would make
   the app start with that Codex home instead of `~/.codex`.
2. Confirm that the registered service path now exists. If it is still
   missing, stop and report the registration and plugin versions through
   `/feedback`; do not guess a replacement path.
3. Run `chezmoi diff ~/.codex/config.toml` and inspect the change before a
   targeted `chezmoi apply ~/.codex/config.toml`.

Do not delete `node_repl` or its other service registrations, broaden trusted
code paths, select the newest cache directory, or create a `latest` symlink.
This guard detects missing files; it does not prove that existing client and
service versions are compatible or change the app's trusted executable.

Personal skills are managed under `~/.claude/skills/` and linked into
`~/.agents/skills/` for Codex; no duplicates are generated under `~/.codex/skills/`.

CCV (Claude Code Viewer) runs only on Linux hosts, so the `my-ccv` skill,
`~/.config/ccv-preview/`, `prune-old-worktrees`, and the CCV status line proxy
deploy only there. `~/.claude/scripts/statusline.sh` routes the Claude Code
status line through that proxy on Linux and runs `ccusage` directly elsewhere.

### RTK Command Rewriting

RTK reduces token-heavy shell output. Codex is instructed to invoke it directly, while Claude Code uses the ordered Bash `PreToolUse` hooks in `home/.chezmoitemplates/claude-settings.json`:

1. `bulk-read-guard` denies unbounded reads of text files over 350 lines (see Model Delegation).
2. `ensure-mise-path.sh` exposes mise-managed tools.
3. `rtk-rewrite.sh` delegates supported commands to `rtk rewrite`.

Run `bash scripts/test-rtk-rewrite-hook.sh` after changing RTK, either hook, or their ordering.

### Model Delegation

Reading a whole large file loads it into the agent's context. Following the
model-routing pattern from Spotify's Portal write-up, `~/.local/bin/bulk-read`
sends files with a question to a cheaper Codex reader (`gpt-6-luna`,
reasoning effort `max`) and prints only its answer, `~/.local/bin/code-write`
has the same model write a predictable file (tests, scaffolding, pattern
copies) in place and returns only a path and summary, and
`~/.local/bin/bulk-read-guard` is a `PreToolUse` hook that denies unbounded
`Read` and `cat` of text files over 350 lines. The guard catches accidental
whole-file reads; it is not a security boundary. It is registered for
Claude Code in `home/.chezmoitemplates/claude-settings.json` and for Codex by
`home/dot_codex/hooks.json.tmpl`; the shared `my-bulk-read` and
`my-code-write` skills under `~/.claude/skills/` are linked into
`~/.agents/skills/` and tell both agents when to delegate.

Codex treats the guard as an unmanaged hook. After `chezmoi apply`, review and
trust it with `/hooks` in an interactive Codex session; until then Codex skips
it. Run `bash scripts/test-delegation.sh` after changing any of the scripts,
the threshold, or the hook registration.

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

`Ctrl+K` lists the 100 most recently updated Claude Code and Codex sessions in total
for the current directory, with the first and latest prompts. The preview shows both
prompts in full. Set `FZF_SESSION_RESUME_LIMIT` to a positive integer to lower the
limit; values above 100 are capped at 100.

Codex sessions come from `$CODEX_HOME/sessions`, `~/.codex/sessions`, and each
Orca account home under `codex-accounts/*/home/sessions` in Orca's data directory
(`$ORCA_USER_DATA_PATH`, otherwise `~/Library/Application Support/orca` on macOS
or `${XDG_CONFIG_HOME:-~/.config}/orca` on Linux). A session stored in several
homes is listed once. When it belongs to a home other than the current one, the
command line sets `CODEX_HOME` for `codex resume`. Compressed `*.jsonl.zst`
rollouts are not listed; use `codex resume` for them.

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
| `gwai [-c\|-x] <prompt>` | Create an AI-named worktree via `gw` and start Claude (`-c`, default) or Codex (`-x`) with the prompt |
| `gwai-orca` | Create an AI-named top-level Orca worktree in the selected workspace's repository and start Claude (default) or Codex |
| `gwai-worktree-name <prompt>` | Print the `YYMMDD-<Japanese name>` that `gwai` and `gwai-orca` use, generated by Claude Haiku; `YYMMDD-<client>-<Japanese name>` when the prompt names a client company |
| `gwc [-j jobs]` | Remove worktrees in parallel with multi-select confirmation |
| `gwt` | `git worktree` |
| `gwta` | `git worktree add` |
| `gwtl` | `git worktree list` |
| `gwtr` | `git worktree remove` |

On Linux, `worktree-prune.timer` checks `~/ghq` every day. CCV's web UI controls
whether cleanup is enabled, the 1–365 day retention period, and whether merged
local branches are also deleted. A `{repo}-worktree/*` worktree is removed only
when both its latest project-file timestamp and latest CCV session timestamp
exceed the configured retention period. A worktree with no session history is
evaluated using its project-file timestamp alone. In merged-branch mode, a local
branch is deleted only when its captured commit is an ancestor of its upstream
or the highest-priority existing `origin/staging`, `origin/main`, or
`origin/master`.
Protected, detached, and unmerged branches remain. Agent session logs are never
deleted. Run `prune-old-worktrees` without `--apply` to preview candidates.

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
| `Cmd+Space` | Launch or focus Orca |
| `Alt+Ctrl+H` | Apply the smart layout for the current display setup |
| `Alt+Ctrl+E` | Force the external display layout |
| `Alt+Ctrl+I` | Force the built-in display layout |
| `Alt+Ctrl+J` | Move the active window to the other display and maximize it |
| `Alt+Ctrl+L` | Maximize Orca when no external display is connected |

External display layout:

- Left 50%: Sublime Text (top 20%), Google Chrome (bottom 80%)
- Right 50%: Orca (full height), Cursor (bottom 55%, overlapping Orca)

Built-in display layout:

- Top 80%: Sublime Text, Orca
- Fullscreen: Google Chrome, Cursor

### Orca

Run `aio` in Raycast to create an AI-named top-level worktree in the selected Orca workspace's repository and start a Claude (default) or Codex session.

After installing Orca on a new machine, create the non-secret browser profile managed by these dotfiles:

```bash
orca-browser-setup
```

The command starts Orca when needed and idempotently creates an imported-session profile named `Work`.
It exits successfully without changing anything when the platform-specific Orca CLI is not installed.
Then open **Settings > Browser > Session & Cookies** and import the required Chrome work profile into `Work`.
Cookies, passwords, profile IDs, and browser storage remain machine-local and are never stored in this repository.
The shared `orca-cli` skill loads the guide bundled with the installed Orca version, so agents use the matching CLI contract.

Dotfiles sets Claude as Orca's default agent and enables `refreshLocalBaseRefOnWorktreeCreate` through `chezmoi apply`.
`mise run maintenance` updates the Orca IDE through its Homebrew Cask.
Orca fetches remote base refs during worktree creation; this setting also updates the corresponding local branch when it can safely fast-forward.
No manual pull is needed for each new workspace. Without a repository-specific base ref, Orca prefers `origin/HEAD`; set a repository override when development uses a different branch, such as `origin/staging`.
Fetch failures can leave Orca using an older ref, so this does not guarantee the latest remote commit when fetching fails.

Claude sessions run the `orca-claude-hook` hook. Orca normally announces "Agent Task Complete" when a turn only waits for background work, such as a `run_in_background` shell, a background agent, or a monitor. The hook keeps a guard in Orca's `~/.orca/agent-hooks/claude-hook.sh` that drops that Stop, so the pane stays working and the only banner arrives when Claude finishes after the work completes. Orca rewrites the script at every app start; the hook reinstalls the guard at the next Claude session start or prompt.
A turn that leaves a never-ending process running, such as a dev server, keeps the pane working and gets no banner.
Session crons, such as `/loop`, still produce a banner for each turn unless background work is also running.

The hook does not change the workspace board status, so workspaces stay in their sidebar group until you move them. The `Mark workspace Done` Quick Command runs `orca-workspace-done` to move the current workspace to Done.

| Keybinding | Action |
|------------|--------|
| `Cmd+Shift+Right` / `Cmd+Shift+Left` | Move to the next / previous tab |
| `Cmd+Alt+Right` / `Cmd+Alt+Down` | Focus the next terminal pane |
| `Cmd+Alt+Left` / `Cmd+Alt+Up` | Focus the previous terminal pane |

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

The same cached identity can be backed up to the **Personal / chezmoi age key** Document in 1Password:

```bash
bash bootstrap/age-key.sh backup
```

The backup command downloads the saved document again, compares it with the original identity, and verifies that it decrypts this repository's encrypted SSH configuration. An existing document with different contents is not overwritten.

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

With 1Password, restore the identity from a repository checkout before initializing chezmoi:

```bash
bash bootstrap/age-key.sh restore
chezmoi -S "$HOME/ghq/github.com/Ynakatsuka/dotfiles" init https://github.com/Ynakatsuka/dotfiles.git
chezmoi apply -v
```

This requires `op`, `age`, `jq`, and `python3`, plus a signed-in 1Password account. See the [bootstrap recovery instructions](bootstrap/README.md#age-key-backup-and-restoration) to install the tools before chezmoi is initialized. Restoration validates the downloaded key before installing it with mode `600`, and refuses to overwrite an existing file or symlink at `~/.config/chezmoi/key.txt`.

To initialize with the repository key's passphrase:

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
