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
cat .gitconfig <(echo "") >> $HOME/.gitconfig
```

## Dependencies

- zsh

```
brew install zsh-completions zsh-git-prompt zplug
```

- bash

```
sudo apt-get update && sudo apt-get install -y bash-completion
```

## Other Tricks

- Ubuntu の shell を変更する場合

```
chsh -s $(which zsh)
```

## References

- https://github.com/yonchu/dotfiles
- https://github.com/reireias/dotfiles
