#
# zsh-abbr (fish-style abbreviations)
# https://github.com/olets/zsh-abbr
#
# Abbreviations expand inline on space/enter, so the actual command is
# preserved in history and on screen. Declared as session abbreviations
# (-S) so they live in this file rather than the on-disk user store.
#

_abbr_plugin=""
for _candidate in \
  /opt/homebrew/share/zsh-abbr/zsh-abbr.zsh \
  /usr/local/share/zsh-abbr/zsh-abbr.zsh; do
  if [[ -f "$_candidate" ]]; then
    _abbr_plugin="$_candidate"
    break
  fi
done

if [[ -n "$_abbr_plugin" ]]; then
  source "$_abbr_plugin"

  abbr -S -q add dc='docker compose'
  abbr -S -q add dcps='docker compose ps'
  abbr -S -q add dcud='docker compose up -d'
  abbr -S -q add dcudb='docker compose up -d --build'
  abbr -S -q add dcudf='docker compose up -d --force-recreate'
  abbr -S -q add dcl='docker compose logs'
  abbr -S -q add dcd='docker compose down'

  abbr -S -q add ghopen='gh repo view --web'
fi

unset _abbr_plugin _candidate
