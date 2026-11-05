#!/usr/bin/env python3
"""Claude Code Stop hook: block an English final reply to a user who writes Japanese.

Long tool runs and compaction summaries fill the context with English, and the
final report drifts to English even though the language instruction is still
loaded. When the prose of the final reply (`last_assistant_message`) is English
and the user's latest prompt with language evidence is Japanese, the hook asks
Claude to resend the reply in Japanese. Code spans, code blocks, and URLs are
not prose, so a reply made only of them passes. A prompt that mentions English
turns the check off until the user writes Japanese again, because blocking a
reply the user wanted in English costs more than missing one. It never blocks
twice in a row (`stop_hook_active`).
"""

import json
import os
import re
import sys

JAPANESE = re.compile(r"[぀-ヿ一-鿿]")
# Fenced code, inline code, and URLs say nothing about the reply's language.
NON_PROSE = re.compile(r"```.*?(?:```|\Z)|`[^`\n]*`|https?://\S+", re.DOTALL)
# A whitespace-delimited plain word. Paths, flags, and identifiers with digits,
# underscores, or other symbols do not match, which keeps most unfenced commands
# under MIN_ENGLISH_WORDS.
ENGLISH_WORD = re.compile(r"(?<!\S)\(?[A-Za-z]+(?:['’][A-Za-z]+)?[.,:;!?)]*(?!\S)")
ENGLISH_REQUEST = re.compile(r"英語|英文|英訳|english", re.IGNORECASE)

# Shorter replies are labels or commands rather than sentences.
MIN_ENGLISH_WORDS = 5
# Japanese replies carry at least 2 Japanese characters per English word and
# English replies that quote Japanese names at most 0.2, across 821 final
# replies from real sessions.
MAX_JAPANESE_CHARS_PER_ENGLISH_WORD = 0.5


def is_english_prose(reply: str) -> bool:
    prose = NON_PROSE.sub(" ", reply)
    english_words = len(ENGLISH_WORD.findall(prose))
    japanese_chars = len(JAPANESE.findall(prose))
    return (
        english_words >= MIN_ENGLISH_WORDS
        and japanese_chars < english_words * MAX_JAPANESE_CHARS_PER_ENGLISH_WORD
    )


def typed_prompts(transcript_path: str) -> list[str]:
    """Return the prompts the user typed in the main conversation, oldest first."""
    prompts = []
    with open(transcript_path, "rb") as transcript:
        for line in transcript:
            # Most of a transcript is tool traffic; parse only user records.
            if b'"type":"user"' not in line:
                continue
            record = json.loads(line)
            if (
                record.get("type") != "user"
                or record.get("isSidechain")
                or record.get("isMeta")
                or record.get("isCompactSummary")
            ):
                continue
            content = record["message"]["content"]
            if isinstance(content, list):
                if any(block.get("type") == "tool_result" for block in content):
                    continue
                content = "\n".join(
                    block["text"] for block in content if block.get("type") == "text"
                )
            # Slash commands, task notifications, and command output arrive as
            # user records wrapped in a tag; the user did not write them.
            if not content.lstrip().startswith("<"):
                prompts.append(content)
    return prompts


def user_expects_japanese(transcript_path: str) -> bool:
    """Decide from the latest prompt that shows which language the user wants.

    Prompts without Japanese or a mention of English, such as "1" or a scheduled
    wakeup, are skipped: they do not change the language of the conversation.
    """
    for prompt in reversed(typed_prompts(transcript_path)):
        if ENGLISH_REQUEST.search(prompt):
            return False
        if JAPANESE.search(prompt):
            return True
    return False


def main() -> int:
    hook_input = json.load(sys.stdin)
    if hook_input["stop_hook_active"]:
        return 0

    # Absent when the final message has no text, which leaves nothing to check.
    if not is_english_prose(hook_input.get("last_assistant_message") or ""):
        return 0

    transcript_path = os.path.expanduser(hook_input["transcript_path"])
    # A session started with --no-session-persistence has no transcript, so the
    # user's language is unknown.
    if not os.path.exists(transcript_path):
        return 0
    if not user_expects_japanese(transcript_path):
        return 0

    reason = (
        "The user writes in Japanese, but this final reply is in English. Resend "
        "the same reply in Japanese, keeping code, commands, identifiers, and "
        "quoted text as they are. If the user asked for this reply in another "
        "language, resend it unchanged."
    )
    json.dump({"decision": "block", "reason": reason}, sys.stdout, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
