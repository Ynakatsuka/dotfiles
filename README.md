# dotfiles

## Quick Start

githubにログインした後、

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin -- init --apply git@github.com:Ynakatsuka/dotfiles.git
```

## その他

### ファイルの編集後、変更を反映する場合

```
chezmoi apply -v
```

### 最新のリモートリポジトリを反映する場合

```
chezmoi update -v
```

### 再読み込みをする場合

```
source $HOME/.bashrc
source $HOME/.zshrc
tmux source $HOME/.tmux.conf
```

## Dependencies

### chezmoi

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
```

### zsh

```
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
```

### bash

```
sudo apt-get update && sudo apt-get install -y bash-completion
```

### tpm

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
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

## References

- https://www.chezmoi.io/
