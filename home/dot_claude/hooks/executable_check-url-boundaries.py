#!/usr/bin/env python3
"""Claude Code Stop hook: block a final reply that glues text onto a URL.

Terminals extend a link until whitespace, so text written right after a URL,
such as a full-width bracket or Japanese, becomes part of the clicked link.
When the final reply (`last_assistant_message`) has a URL followed directly by
a non-ASCII character, the hook asks Claude to resend the affected lines. It
never blocks twice in a row (`stop_hook_active`).
"""

import json
import re
import sys

# An ASCII URL run followed immediately by a non-ASCII character.
GLUED_URL = re.compile(r"https?://[!-~]+(?=[^\x00-\x7f])")
CONTEXT_CHARS = 12


def main() -> int:
    hook_input = json.load(sys.stdin)
    if hook_input["stop_hook_active"]:
        return 0

    # Absent when the final message has no text, which leaves nothing to check.
    reply = hook_input.get("last_assistant_message") or ""
    glued = [
        reply[match.start() : match.end() + CONTEXT_CHARS].splitlines()[0]
        for match in GLUED_URL.finditer(reply)
    ]
    if not glued:
        return 0

    examples = "\n".join(f"- {snippet}" for snippet in glued)
    reason = (
        "Text is attached directly to these URLs, so terminals include it in the "
        f"link:\n{examples}\n"
        "Resend only the affected lines, with a space or line break right after "
        "each URL."
    )
    json.dump({"decision": "block", "reason": reason}, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
