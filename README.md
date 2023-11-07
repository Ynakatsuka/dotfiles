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

- すでに dotfile があり、追記する場合

```
cat .bashrc <(echo "") >> $HOME/.bashrc
cat .zshrc <(echo "") >> $HOME/.zshrc
cat .gitconfig <(echo "") >> $HOME/.gitconfig
cat .tmux.conf <(echo "") >> $HOME/.tmux.conf
```

- すでに dotfile があり、置換する場合

```
cp .bashrc $HOME/
cp zsh/.z* $HOME/
cp .gitconfig $HOME/
cp .tmux.conf $HOME/
```

- 再読み込み

```
source $HOME/.bashrc
source $HOME/.zshrc
tmux source $HOME/.tmux.conf
```

## Dependencies

- zsh

```
git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
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
