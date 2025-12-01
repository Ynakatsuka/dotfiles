#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Restore Window Snapshot
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 🔄
# @raycast.argument1 { "type": "text", "placeholder": "Snapshot name" }
# @raycast.packageName Window Manager

# Documentation:
# @raycast.description Restore window positions and sizes from a saved snapshot
# @raycast.author yuki
# @raycast.authorURL https://github.com/yourusername

set -euo pipefail

# Constants
readonly SNAPSHOTS_DIR="$HOME/.window-snapshots"
readonly SNAPSHOT_NAME="$1"

# Validate snapshot name
if [[ -z "$SNAPSHOT_NAME" ]]; then
    echo "Error: Snapshot name is required"
    exit 1
fi

# Sanitize snapshot name for filename
sanitized_name=$(echo "$SNAPSHOT_NAME" | sed 's/[^a-zA-Z0-9_-]/_/g')
snapshot_file="$SNAPSHOTS_DIR/${sanitized_name}.json"

# Check if snapshot exists
if [[ ! -f "$snapshot_file" ]]; then
    echo "Error: Snapshot '$SNAPSHOT_NAME' not found"
    echo "Available snapshots:"
    if [[ -d "$SNAPSHOTS_DIR" ]]; then
        ls -1 "$SNAPSHOTS_DIR" 2>/dev/null | sed 's/\.json$//' | sed 's/^/  - /'
    fi
    exit 1
fi

# Extract windows list and create restore script
restore_script=$(python3 << PYTHON
import json

with open('$snapshot_file', 'r') as f:
    data = json.load(f)

windows = data.get('windows', [])

# Generate AppleScript for each window
scripts = []
for w in windows:
    app = w.get('app', '')
    x = int(w.get('x', 0))
    y = int(w.get('y', 0))
    width = int(w.get('width', 0))
    height = int(w.get('height', 0))
    title = w.get('title', '').replace('"', '\\"')

    if app and width > 0 and height > 0:
        script = f'''
try
    tell application "System Events"
        if exists process "{app}" then
            tell process "{app}"
                if (count of windows) > 0 then
                    set targetWin to window 1
                    set position of targetWin to {{{x}, {y}}}
                    set size of targetWin to {{{width}, {height}}}
                end if
            end tell
        end if
    end tell
end try
'''
        scripts.append(script)

print('\\n'.join(scripts))
print(f'return {len(scripts)}')
PYTHON
)

# Check if yabai is available (better window management)
if command -v yabai &> /dev/null; then
    restored_count=$(python3 << PYTHON
import json
import subprocess

with open('$snapshot_file', 'r') as f:
    data = json.load(f)

windows = data.get('windows', [])
restored = 0

# Get current windows
try:
    result = subprocess.run(['yabai', '-m', 'query', '--windows'], capture_output=True, text=True)
    current_windows = json.loads(result.stdout)
except:
    current_windows = []

# Create app -> window id mapping
app_windows = {}
for w in current_windows:
    app = w.get('app', '')
    if app not in app_windows:
        app_windows[app] = []
    app_windows[app].append(w['id'])

# Restore each window
for w in windows:
    app = w.get('app', '')
    x = int(w.get('x', 0))
    y = int(w.get('y', 0))
    width = int(w.get('width', 0))
    height = int(w.get('height', 0))

    if app in app_windows and app_windows[app]:
        win_id = app_windows[app].pop(0)
        try:
            subprocess.run(['yabai', '-m', 'window', str(win_id), '--move', f'abs:{x}:{y}'], check=True)
            subprocess.run(['yabai', '-m', 'window', str(win_id), '--resize', f'abs:{width}:{height}'], check=True)
            restored += 1
        except:
            pass

print(restored)
PYTHON
)
else
    # Use AppleScript
    restored_count=$(osascript << EOF
$restore_script
EOF
)
fi

echo "✅ Restored $restored_count windows from '$SNAPSHOT_NAME'"
