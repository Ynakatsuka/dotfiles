#
# code-server: VS Code in the browser
#

# Settings directory for code-server (VS Code settings)
_CS_SETTINGS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/code-server/User"
_CS_SETTINGS_FILE="$_CS_SETTINGS_DIR/settings.json"

# Ensure dark theme and Cursor-like settings on first run
_cs-ensure-settings() {
  # Ensure keybindings (Ctrl+W → close editor for cmux browser compatibility)
  local keybindings_file="$_CS_SETTINGS_DIR/keybindings.json"
  if [[ ! -f "$keybindings_file" ]]; then
    mkdir -p "$_CS_SETTINGS_DIR"
    cat > "$keybindings_file" << 'KEYBINDINGS'
[
    {
        "key": "ctrl+w",
        "command": "workbench.action.closeActiveEditor"
    }
]
KEYBINDINGS
  fi

  if [[ ! -f "$_CS_SETTINGS_FILE" ]] || ! grep -q "GitHub Dark" "$_CS_SETTINGS_FILE" 2>/dev/null; then
    mkdir -p "$_CS_SETTINGS_DIR"
    cat > "$_CS_SETTINGS_FILE" << 'SETTINGS'
{
    "workbench.colorTheme": "GitHub Dark",
    "workbench.iconTheme": "vscode-icons",
    "editor.minimap.enabled": false,
    "editor.fontSize": 14,
    "editor.tabSize": 2,
    "editor.formatOnSave": true,
    "editor.bracketPairColorization.enabled": true,
    "editor.guides.bracketPairs": "active",
    "terminal.integrated.fontSize": 13,
    "window.autoDetectColorScheme": false,
    "workbench.preferredDarkColorTheme": "GitHub Dark",
    "workbench.activityBar.orientation": "vertical",
    "security.workspace.trust.enabled": false,
    "git.autoRepositoryDetection": "openEditors",
    "workbench.startupEditor": "none",
    "workbench.secondarySideBar.visible": false,
    "window.restoreWindows": "none",
    "chat.commandCenter.enabled": false,
    "chat.experimental.enabled": false,
    "update.mode": "none",
    "extensions.autoCheckUpdates": false,
    "scm.defaultViewMode": "tree",
    "[python]": {
        "editor.tabSize": 4
    }
}
SETTINGS
    echo "code-server settings initialized (GitHub Dark theme)."
  fi
}

# Auto-install extensions if not yet installed
_cs-ensure-extensions() {
  local marker="${XDG_DATA_HOME:-$HOME/.local/share}/code-server/.extensions-installed"
  [[ -f "$marker" ]] && return 0

  local extensions=(
    GitHub.github-vscode-theme
    vscode-icons-team.vscode-icons
    ms-python.python
    ms-python.pylance
    esbenp.prettier-vscode
    rust-lang.rust-analyzer
    golang.go
  )
  echo "Installing code-server extensions (first run) ..."
  for ext in "${extensions[@]}"; do
    code-server --install-extension "$ext" --force >/dev/null 2>&1 || true
  done
  touch "$marker"
  echo "Extensions installed."
}

# Open code-server on an available port in the 9000 range
cs() {
  if ! command -v code-server >/dev/null 2>&1; then
    echo "code-server is not installed. Run: brew install code-server" >&2
    return 1
  fi

  local dir="${1:-.}"
  dir="$(cd "$dir" && pwd)"
  local port=""

  # Find an available port in 9000-9099
  for p in $(seq 9000 9099); do
    if ! lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
      port=$p
      break
    fi
  done

  if [[ -z "$port" ]]; then
    echo "No available port in 9000-9099 range." >&2
    return 1
  fi

  _cs-ensure-settings

  local encoded_dir
  encoded_dir=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$dir'))")
  local url="http://127.0.0.1:${port}/?folder=${encoded_dir}"
  local log_file="/tmp/code-server-${port}.log"

  : > "$log_file"
  echo "Starting code-server on port $port (log: $log_file) ..."
  echo "Opening: $dir"
  nohup code-server --bind-addr "127.0.0.1:${port}" --auth none --disable-workspace-trust "$dir" >> "$log_file" 2>&1 &
  disown %% 2>/dev/null

  # Wait for server to be ready (up to 10s)
  local ready=0
  for _ in $(seq 1 20); do
    if lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 0.5
  done
  if [[ "$ready" -eq 0 ]]; then
    echo "code-server failed to start. Check $log_file" >&2
    return 1
  fi

  # Install extensions in background after first startup
  ( _cs-ensure-extensions ) &>/dev/null &
  disown %% 2>/dev/null

  # Open in cmux browser tab if inside cmux, otherwise system browser
  if [[ -n "$CMUX_WORKSPACE_ID" ]] && command -v cmux >/dev/null 2>&1; then
    cmux browser open "$url"
  else
    open "$url"
  fi
}

# Kill running code-server instances via fzf
csc() {
  local lines
  lines=$(ps aux | grep '[c]ode-server --bind-addr')

  if [[ -z "$lines" ]]; then
    echo "No running code-server instances found."
    return 0
  fi

  local selected
  selected=$(echo "$lines" \
    | awk '{
        pid=$2;
        # Extract port from --bind-addr
        port="?";
        for(i=1;i<=NF;i++) if($i ~ /--bind-addr/) { split($(i+1),a,":"); port=a[2] }
        # Extract directory (last argument)
        dir=$NF;
        printf "%-6s  %-6s  %s\n", pid, port, dir
      }' \
    | fzf --multi --prompt="Kill code-server> " --height=40% --reverse \
        --header="PID    PORT    DIR")

  if [[ -z "$selected" ]]; then
    return 0
  fi

  echo "$selected" | awk '{print $1}' | xargs kill
  echo "Killed selected code-server instance(s)."
}
