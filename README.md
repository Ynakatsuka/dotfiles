# dotfiles

## Quick Start

githubにログインした後、

```bash
# zprezto
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
# tpm
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
~/.local/bin/chezmoi init https://github.com/Ynakatsuka/dotfiles.git
~/.local/bin/chezmoi update -v
# mise (development tools manager)
curl https://mise.run | sh
source ~/.zshrc
# install development tools
mise up
```

## Development Tools Management

このリポジトリでは [mise](https://mise.jdx.dev/) を使用して開発ツールを統一管理しています。
chezmoiと連携し、`~/.mise.toml` が自動で配置・同期されます。

### 管理対象ツール

| ツール | 実行コマンド | 説明 |
|--------|--------------|------|
| Claude Code | `claude` | Anthropic AI コーディングアシスタント |
| Gemini CLI | `gemini` | Google AI CLI |
| uv | `uv` | 高速Python パッケージインストーラー |
| typos | `typos` | ソースコードスペルチェッカー |
| OpenAI Codex | `codex` | OpenAI Codex CLI |

### 基本的な使用方法

```bash
# すべてのツールを最新版に更新
mise up

# インストール済みツールの確認
mise list

# ツールの状態確認
mise doctor

# 特定ツールのバージョン確認
claude --version
gemini --version
uv --version
typos --version
codex --version
```

### 新しい環境での setup

```bash
# 1. このdotfilesリポジトリをセットアップ（Quick Start参照）
# 2. mise設定が自動で ~/.mise.toml に配置される
# 3. 開発ツールをインストール
mise up
```

### ツール設定の更新

新しいツールを追加したい場合は、`~/.local/share/chezmoi/dot_mise.toml` を編集してcommit・pushしてください。
他の環境では `chezmoi update && mise up` で同期されます。

## その他

### 管理ファイルの確認

```
chezmoi managed
```

### 管理ファイルの追加

```
chezmoi add README.md
```

### 管理ファイルの削除

```
chezmoi forget README.md
```

### ファイルの編集

```
chezmoi edit README.md
```

### ファイルの編集後、変更を反映する場合

```
chezmoi apply -v
```

### リポジトリへ移動する場合

```
chezmoi cd
```

### 最新のリモートリポジトリを反映する場合

```
chezmoi update -v
```

### 全ファイルの強制同期

```
chezmoi init --apply https://github.com/Ynakatsuka/dotfiles.git --force
```

### 再読み込みをする場合

```
source $HOME/.bashrc
source $HOME/.zshrc
tmux source $HOME/.tmux.conf
```

## Other Dependencies

### bash-completion

```
sudo apt-get update && sudo apt-get install -y bash-completion
```

## Other Tricks

shell を変更

```
chsh -s $(which zsh)
```

tmux の設定の反映

```
tmux source ~/.tmux.conf
```

then, `prefix + I`

## Custom Commands Installation

### Install custom commands to Claude or Cursor

The `install_custom_commands.py` script installs custom commands from `dot_codex/prompts` to Claude or Cursor directories.

```bash
./install_custom_commands.py /path/to/project {claude,cursor} [--overwrite]
```

## References

- https://www.chezmoi.io/
- https://mise.jdx.dev/
