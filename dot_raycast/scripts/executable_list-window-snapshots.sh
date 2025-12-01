#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title List Window Snapshots
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📋
# @raycast.packageName Window Manager

# Documentation:
# @raycast.description List all saved window snapshots
# @raycast.author yuki
# @raycast.authorURL https://github.com/yourusername

set -euo pipefail

# Constants
readonly SNAPSHOTS_DIR="$HOME/.window-snapshots"

# Check if directory exists
if [[ ! -d "$SNAPSHOTS_DIR" ]]; then
    echo "No snapshots found."
    echo "Use 'Save Window Snapshot' to create one."
    exit 0
fi

# List snapshots
snapshots=($(ls -1 "$SNAPSHOTS_DIR"/*.json 2>/dev/null || true))

if [[ ${#snapshots[@]} -eq 0 ]]; then
    echo "No snapshots found."
    echo "Use 'Save Window Snapshot' to create one."
    exit 0
fi

echo "📸 Saved Window Snapshots"
echo "========================="
echo ""

for snapshot_file in "${snapshots[@]}"; do
    filename=$(basename "$snapshot_file" .json)

    # Parse snapshot info using Python
    info=$(python3 << EOF
import json
from datetime import datetime

with open('$snapshot_file', 'r') as f:
    data = json.load(f)

name = data.get('name', '$filename')
created = data.get('created_at', 'Unknown')
windows = data.get('windows', [])
window_count = len(windows)

# Get unique apps
apps = sorted(set(w.get('app', 'Unknown') for w in windows))
apps_str = ', '.join(apps[:5])
if len(apps) > 5:
    apps_str += f' (+{len(apps) - 5} more)'

# Format date
try:
    dt = datetime.fromisoformat(created.replace('Z', '+00:00'))
    created_formatted = dt.strftime('%Y-%m-%d %H:%M')
except:
    created_formatted = created

print(f"Name: {name}")
print(f"Created: {created_formatted}")
print(f"Windows: {window_count}")
print(f"Apps: {apps_str}")
EOF
)

    echo "📌 $filename"
    echo "$info" | sed 's/^/   /'
    echo ""
done

echo "Use 'Restore Window Snapshot' with the snapshot name to restore."
