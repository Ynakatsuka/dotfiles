#
# Yazi file manager
#
# Wrapper from the yazi quick-start guide. Running `y` launches yazi and,
# on exit, changes the current shell's directory to wherever you navigated
# to inside yazi. See https://yazi-rs.github.io/docs/quick-start/
#

if command -v yazi >/dev/null 2>&1; then
  function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
  }
fi
