# dotfiles

## Quick Start

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

## Bootstrap (Linux/macOS)

Please see `bootstrap/README.md` for complete, up‑to‑date bootstrap instructions for macOS and Ubuntu 22.04.

## References

- https://www.chezmoi.io/
- https://mise.jdx.dev/
