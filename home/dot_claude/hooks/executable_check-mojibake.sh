#!/bin/bash
# PreToolUse: Write/Edit/MultiEdit の入力にU+FFFDが含まれていたら書き込みを阻止する

if ! command -v jq &>/dev/null; then
  echo "[check-mojibake] WARNING: jq is not installed. Hook cannot inspect tool input. Install jq: https://jqlang.github.io/jq/download/" >&2
  exit 0
fi

INPUT=$(cat)

# tool_input から書き込み内容を抽出して検査（MultiEdit は .edits[].new_string）
CONTENT=$(echo "$INPUT" | jq -r '
  .tool_input |
  (.content // empty),
  (.new_string // empty),
  (.edits[]?.new_string // empty)
')

if echo "$CONTENT" | grep -q $'\xef\xbf\xbd'; then
  echo "U+FFFD detected in tool input. Rewrite affected lines with correct characters." >&2
  echo "$CONTENT" | grep -n $'\xef\xbf\xbd' | head -5 >&2
  exit 2
fi
