#!/usr/bin/env python3
"""Convert standard Markdown to Slack mrkdwn format.

Usage:
    md2slack.py INPUT_FILE [OUTPUT_FILE]
    cat file.md | md2slack.py -

If OUTPUT_FILE is omitted, prints to stdout.

Key conversions:
    ## Heading       → *Heading*
    **bold**         → *bold*
    *italic*         → _italic_
    [text](url)      → <url|text>
    `code`           → `code`  (unchanged)
    ```block```      → ```block```  (unchanged)
    ![alt](url)      → <url|alt> (image as link)
    > blockquote     → > blockquote (unchanged, Slack supports this)
    ---              → ──────────── (visual separator)
    - list item      → • list item
"""

import re
import sys


def convert_md_to_slack(text: str) -> str:
    """Convert Markdown text to Slack mrkdwn format."""
    lines = text.split("\n")
    result = []
    in_code_block = False

    for line in lines:
        # Toggle code block state
        if line.strip().startswith("```"):
            in_code_block = not in_code_block
            result.append(line)
            continue

        # Don't transform inside code blocks
        if in_code_block:
            result.append(line)
            continue

        line = _convert_line(line)
        result.append(line)

    return "\n".join(result)


def _convert_line(line: str) -> str:
    """Convert a single non-code-block line."""
    stripped = line.strip()

    # Horizontal rule
    if re.match(r"^-{3,}$|^\*{3,}$|^_{3,}$", stripped):
        return "────────────────"

    # Headings: ## Heading → *Heading*
    heading_match = re.match(r"^(#{1,6})\s+(.*)", line)
    if heading_match:
        heading_text = heading_match.group(2).strip()
        return f"*{heading_text}*"

    # Unordered list: - item or * item → • item (preserve indentation)
    list_match = re.match(r"^(\s*)[-*]\s+(.*)", line)
    if list_match:
        indent = list_match.group(1)
        content = list_match.group(2)
        content = _convert_inline(content)
        return f"{indent}• {content}"

    # Ordered list: 1. item → 1. item (keep as-is, convert inline)
    ordered_match = re.match(r"^(\s*)(\d+\.)\s+(.*)", line)
    if ordered_match:
        indent = ordered_match.group(1)
        number = ordered_match.group(2)
        content = ordered_match.group(3)
        content = _convert_inline(content)
        return f"{indent}{number} {content}"

    # Regular line: convert inline formatting
    return _convert_inline(line)


def _convert_inline(text: str) -> str:
    """Convert inline Markdown formatting to Slack mrkdwn."""
    # Protect inline code spans from further conversion
    code_spans: list[str] = []

    def _save_code(m: re.Match) -> str:
        code_spans.append(m.group(0))
        return f"\x00CODE{len(code_spans) - 1}\x00"

    text = re.sub(r"`[^`]+`", _save_code, text)

    # Images: ![alt](url) → <url|alt>
    text = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", r"<\2|\1>", text)

    # Links: [text](url) → <url|text>
    text = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"<\2|\1>", text)

    # Bold+italic: ***text*** or ___text___ → placeholder
    bold_italic_spans: list[str] = []

    def _save_bold_italic(m: re.Match) -> str:
        bold_italic_spans.append(m.group(1))
        return f"\x00BI{len(bold_italic_spans) - 1}\x00"

    text = re.sub(r"\*{3}(.+?)\*{3}", _save_bold_italic, text)
    text = re.sub(r"_{3}(.+?)_{3}", _save_bold_italic, text)

    # Bold: **text** → placeholder
    bold_spans: list[str] = []

    def _save_bold(m: re.Match) -> str:
        bold_spans.append(m.group(1))
        return f"\x00BOLD{len(bold_spans) - 1}\x00"

    text = re.sub(r"\*{2}(.+?)\*{2}", _save_bold, text)

    # Italic: *text* → _text_
    text = re.sub(r"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)", r"_\1_", text)

    # Restore placeholders
    for i, content in enumerate(bold_italic_spans):
        text = text.replace(f"\x00BI{i}\x00", f"*_{ content}_*")
    for i, content in enumerate(bold_spans):
        text = text.replace(f"\x00BOLD{i}\x00", f"*{content}*")

    # Strikethrough: ~~text~~ → ~text~
    text = re.sub(r"~~(.+?)~~", r"~\1~", text)

    # Restore code spans
    for i, code in enumerate(code_spans):
        text = text.replace(f"\x00CODE{i}\x00", code)

    return text


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: md2slack.py INPUT_FILE [OUTPUT_FILE]", file=sys.stderr)
        print("       cat file.md | md2slack.py -", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]

    if input_path == "-":
        text = sys.stdin.read()
    else:
        with open(input_path) as f:
            text = f.read()

    converted = convert_md_to_slack(text)

    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
        with open(output_path, "w") as f:
            f.write(converted)
    else:
        print(converted, end="")


if __name__ == "__main__":
    main()
