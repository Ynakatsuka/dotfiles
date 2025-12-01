#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Save Window Snapshot
# @raycast.mode compact

# Optional parameters:
# @raycast.icon 📸
# @raycast.argument1 { "type": "text", "placeholder": "Snapshot name" }
# @raycast.packageName Window Manager

# Documentation:
# @raycast.description Save current window positions and sizes as a named snapshot
# @raycast.author yuki
# @raycast.authorURL https://github.com/yourusername

set -euo pipefail

# Constants
readonly SNAPSHOTS_DIR="$HOME/.window-snapshots"
readonly SNAPSHOT_NAME="$1"

# Ensure snapshots directory exists
mkdir -p "$SNAPSHOTS_DIR"

# Validate snapshot name
if [[ -z "$SNAPSHOT_NAME" ]]; then
    echo "Error: Snapshot name is required"
    exit 1
fi

# Sanitize snapshot name for filename
sanitized_name=$(echo "$SNAPSHOT_NAME" | sed 's/[^a-zA-Z0-9_-]/_/g')
snapshot_file="$SNAPSHOTS_DIR/${sanitized_name}.json"

# Get script directory
script_dir=$(dirname "$0")

# Get window information using Swift helper (no accessibility permission required)
window_data=$(swift "$script_dir/window-list.swift" 2>/dev/null)

# Fallback to yabai if Swift fails
if [[ -z "$window_data" ]] || [[ "$window_data" == "[]" ]]; then
    if command -v yabai &> /dev/null; then
        window_data=$(yabai -m query --windows | python3 -c "
import json
import sys
windows = json.load(sys.stdin)
result = []
for w in windows:
    result.append({
        'app': w.get('app', ''),
        'title': w.get('title', ''),
        'x': w.get('frame', {}).get('x', 0),
        'y': w.get('frame', {}).get('y', 0),
        'width': w.get('frame', {}).get('w', 0),
        'height': w.get('frame', {}).get('h', 0),
        'pid': w.get('pid', 0)
    })
print(json.dumps(result))
")
    fi
fi

# Final check
if [[ -z "$window_data" ]] || [[ "$window_data" == "[]" ]]; then
    echo "Error: Could not get window information."
    echo "Please ensure Raycast has Accessibility permissions in System Settings > Privacy & Security > Accessibility"
    exit 1
fi

# Create snapshot JSON with metadata
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use Python for safe JSON construction
snapshot_json=$(python3 << PYTHON
import json

name = """$SNAPSHOT_NAME"""
timestamp = "$timestamp"
windows = json.loads('''$window_data''')

snapshot = {
    "name": name,
    "created_at": timestamp,
    "windows": windows
}

print(json.dumps(snapshot, ensure_ascii=False, indent=2))
PYTHON
)

# Save to file
echo "$snapshot_json" > "$snapshot_file"

# Count windows
window_count=$(echo "$window_data" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")

echo "✅ Saved '$SNAPSHOT_NAME' ($window_count windows)"
