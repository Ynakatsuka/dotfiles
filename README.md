# dotfiles

## Quick Start

- リポジトリが public の場合

```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Ynakatsuka/dotfiles/main/install.sh)"
```

- リポジトリが private の場合

```
git clone git@github.com:Ynakatsuka/dotfiles.git
cd dotfiles
./create_symlink.sh
```

- すでに dotfile がある場合

```
cat .bashrc <(echo "") >> $HOME/.bashrc
cat .zshrc <(echo "") >> $HOME/.zshrc
cat .gitconfig <(echo "") >> $HOME/.gitconfig
```

## Dependencies

- zsh

```
brew install zsh-completions zsh-git-prompt zsh-autosuggestions
```

- bash

```
sudo apt-get update && sudo apt-get install -y bash-completion
```

- tpm

```
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

## Other Tricks

- shell を変更する場合

```
chsh -s $(which zsh)
```

- tmux の設定の反映

```
tmux source ~/.tmux.conf
```

then, `prefix + I`

## References

- https://github.com/yonchu/dotfiles
- https://github.com/reireias/dotfiles
- https://github.com/shunk031/dotfiles
