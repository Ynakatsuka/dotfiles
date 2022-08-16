#!/bin/bash
#*******************************************************************************
#
# Ref: https://tech.kanmu.co.jp/entry/2021/05/20/134419
# Ref: https://github.com/yonchu/dotfiles
# ワンラインでdotfilesのシンボリックリンクを作る
#
#*******************************************************************************

create_symlink() {
  if [ ! -e "$1" ]; then
    echo "リンク先が存在しません: $1"
  elif [ -e "$2" ]; then
    echo "同名のファイルが既に存在します: $2"
  else
    ln -s "$1" "$2"
    echo "シンボリックリンクを作成しました: $2 -> $1"
  fi
}

create_dotfiles_symlinks() {
    DOT_FILES=(
        .bashrc
        .gitignore
        .gitconfig
        .zshrc)

    (
        cd "$HOME"

        for file in ${DOT_FILES[@]}; do
            create_symlink "dotfiles/$file" "$HOME/$file"
        done

    )
}

# --------------------------------------------
# Main
# --------------------------------------------
DOT_DIR="$HOME/dotfiles"

# clone
git clone https://github.com/Ynakatsuka/dotfiles.git ${DOT_DIR}

# シンボリックリンク作成
create_dotfiles_symlinks
