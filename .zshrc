# --------------------------------------------
# 言語設定
# --------------------------------------------
# 日本語設定
export LANG=ja_JP.UTF-8

# 補完候補リストの日本語を表示可能にする
setopt print_eight_bit

# --------------------------------------------
# PROMPT
# --------------------------------------------
autoload -Uz colors && colors
if [ -e $(brew --prefix)/opt/zsh-git-prompt/zshrc.sh ]; then
    source $(brew --prefix)/opt/zsh-git-prompt/zshrc.sh
fi
PROMPT='%F{034}%n%f %F{036}($(arch))%f:%F{020}%~%f $(git_super_status)'
PROMPT+=""$'\n'"%# "

# --------------------------------------------
# 補完
# --------------------------------------------
if [ -e /usr/local/share/zsh-completions ]; then
  fpath=(/usr/local/share/zsh-completions $fpath)
fi

# 補完を有効にする
autoload -Uz compinit
compinit

# タブキーの連打で自動的にメニュー補完
setopt auto_menu

# 補完候補が複数ある時に、一覧表示
setopt auto_list

#補完対象のファイルの末尾に識別マークをつける
setopt list_types

# ファイル名の展開でディレクトリにマッチした場合 末尾に / を付加
setopt mark_dirs

# ディレクトリ名の補完で末尾の / を自動的に付加し、次の補完に備える
setopt auto_param_slash

# キャッシュによる補完の高速化
zstyle ':completion::complete:*' use-cache true

# 補完候補をハイライト
zstyle ':completion:*:default' menu select=1

# 補完関数の表示を強化する
zstyle ':completion:*' verbose yes
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:messages' format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings' format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'$DEFAULT

# マッチ種別を別々に表示
zstyle ':completion:*' group-name ''

# 語の途中でもカーソル位置で補完
setopt complete_in_word

# 補完候補など表示する時はその場に表示し、終了時に画面から消す
setopt always_last_prompt

# コマンドラインの引数で --prefix=/usr などの = 以降でも補完できる
setopt magic_equal_subst

# カッコの対応などを自動的に補完
setopt auto_param_keys

# コマンドのスペルの訂正を使用する
setopt correct

# 引数のスペルの訂正を使用する
unsetopt correct_all

# 拡張グロブで補完(~とか^とか。例えばless *.txt~memo.txt ならmemo.txt 以外の *.txt にマッチ)
setopt extended_glob

# 明確なドットの指定なしで.から始まるファイルをマッチ
setopt globdots

# 補完でカラーを使用する
autoload colors
zstyle ':completion:*' list-colors "${LS_COLORS}"

# --------------------------------------------
# History
# --------------------------------------------
# ヒストリーサイズ設定
HISTFILE=$HOME/.zsh_history
HISTSIZE=1000000
SAVEHIST=1000000

# ヒストリの一覧を読みやすい形に変更
HISTTIMEFORMAT="[%Y/%M/%D %H:%M:%S] "

# 履歴を他のシェルとリアルタイム共有する
setopt share_history

# 同じコマンドをhistoryに残さない
setopt hist_ignore_all_dups

# historyに保存するときに余分なスペースを削除する
setopt hist_ignore_space       
setopt hist_reduce_blanks

# 重複するコマンドが保存されるとき、古い方を削除する
setopt hist_save_no_dups

# 実行時に履歴をファイルに追加していく
setopt inc_append_history

# --------------------------------------------
# zplug
# --------------------------------------------
export ZPLUG_HOME=~/.zplug
source $ZPLUG_HOME/init.zsh
zplug 'zplug/zplug', hook-build:'zplug --self-manage'

# zshの補完機能を更に強力にする
# https://github.com/zsh-users/zsh-completions
zplug "zsh-users/zsh-completions"

# コマンドライン自体の色付けを行う
# https://github.com/zsh-users/zsh-syntax-highlighting
zplug "zsh-users/zsh-syntax-highlighting", defer:3

# zshのヒストリーサーチを便利にする
# https://github.com/zsh-users/zsh-history-substring-search
zplug "zsh-users/zsh-history-substring-search", defer:3

# ヒストリーから現在入力中のコマンドを探して, 補完を薄文字で表示する
# https://github.com/zsh-users/zsh-autosuggestions
zplug "zsh-users/zsh-autosuggestions"

# ターミナルを256色使用可能にする
# https://github.com/chrissicool/zsh-256color
zplug "chrissicool/zsh-256color"

# oh-my-zsh のリポジトリにある plugin/ 以下をコマンド/プラグインとして管理する
zplug "plugins/git", from:oh-my-zsh

# preztoのプラグインを使う
zplug "modules/editor", from:prezto
zplug "modules/history", from:prezto

# インタラクティブフィルタ
zplug "junegunn/fzf-bin", as:command, from:gh-r, rename-to:fzf
zplug "junegunn/fzf", as:command, use:bin/fzf-tmux   # tmux用の拡張

# https://github.com/denysdovhan/spaceship-prompt
zplug "denysdovhan/spaceship-prompt", use:spaceship.zsh, from:github, as:theme

# pluginがなかったらインストールする
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# source plugins and add commands to $PATH
zplug load
