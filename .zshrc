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
PROMPT="%F{green}%n%f %F{cyan}($(arch))%f:%F{blue}%C%f$ "

# --------------------------------------------
# 補完
# --------------------------------------------
# 補完を有効にする
if type brew &>/dev/null; then
  FPATH=$(brew --prefix)/share/zsh-completions:$FPATH
  source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  autoload -Uz compinit && compinit
fi

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
# alias
# --------------------------------------------
# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# docker alias
alias dc='docker compose'
alias dcps='docker compose ps'
alias dcud='docker compose up -d'
alias dcudb='docker compose up -d --build'
alias dce='docker compose exec $(docker compose ps --services)'
alias dcl='docker compose logs'
alias dcd='docker compose down'
