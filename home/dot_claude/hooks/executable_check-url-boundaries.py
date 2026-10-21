#!/usr/bin/env python3
"""Claude Code Stop hook: block a final reply that glues text onto a URL.

Claude Code renders a bare URL as a GFM autolink, which extends until
whitespace, so text written right after it, such as a full-width bracket or
Japanese, becomes part of the link target. When the final reply
(`last_assistant_message`) has a bare URL followed directly by a non-ASCII
character, the hook asks Claude to resend the affected lines. Markdown links and
`<URL>` autolinks keep their exact target, so they are not checked. It never
blocks twice in a row (`stop_hook_active`).
"""

import json
import re
import sys

# An ASCII URL run followed immediately by a non-ASCII character.
GLUED_URL = re.compile(r"https?://[!-~]+(?=[^\x00-\x7f])")
# Links whose target ends at an explicit delimiter: [text](url) and <url>.
DELIMITED_LINK = re.compile(r"\[[^\]\n]*\]\([^)\s]*\)|<https?://[^>\s]*>")
CONTEXT_CHARS = 12


def main() -> int:
    hook_input = json.load(sys.stdin)
    if hook_input["stop_hook_active"]:
        return 0

    # Absent when the final message has no text, which leaves nothing to check.
    reply = DELIMITED_LINK.sub(" ", hook_input.get("last_assistant_message") or "")
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
