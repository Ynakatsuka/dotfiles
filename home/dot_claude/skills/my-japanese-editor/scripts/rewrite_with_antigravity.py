"""Rewrite Japanese text with Gemini through Antigravity CLI."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ANTIGRAVITY_MODEL = "gemini-3.8-flash-high"
ANTIGRAVITY_TIMEOUT_SECONDS = 150
ANTIGRAVITY_PRINT_TIMEOUT = "120s"
SKILL_ROOT = Path(__file__).resolve().parent.parent
PROMPT_PATHS = {
    "rewrite": SKILL_ROOT / "prompts" / "gemini-rewrite.md",
    "repair": SKILL_ROOT / "prompts" / "gemini-repair.md",
}


class AntigravityRewriteError(Exception):
    """Raised when an Antigravity response cannot be safely accepted."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Rewrite or repair Japanese text with Gemini through Antigravity CLI."
    )
    parser.add_argument("mode", choices=tuple(PROMPT_PATHS))
    return parser.parse_args()


def load_job(mode: str) -> dict[str, Any]:
    try:
        job = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        raise AntigravityRewriteError(f"input is not valid JSON: {error}") from error

    if not isinstance(job, dict):
        raise AntigravityRewriteError("input must be a JSON object")

    blocks = job.get("blocks")
    if not isinstance(blocks, list) or not blocks:
        raise AntigravityRewriteError("blocks must be a non-empty array")

    seen_ids: set[str] = set()
    for index, block in enumerate(blocks):
        if not isinstance(block, dict):
            raise AntigravityRewriteError(f"blocks[{index}] must be an object")

        block_id = block.get("id")
        original = block.get("original")
        if not isinstance(block_id, str) or not block_id:
            raise AntigravityRewriteError(
                f"blocks[{index}].id must be a non-empty string"
            )
        if block_id in seen_ids:
            raise AntigravityRewriteError(f"duplicate block id: {block_id}")
        seen_ids.add(block_id)

        if not isinstance(original, str) or not original.strip():
            raise AntigravityRewriteError(
                f"blocks[{index}].original must be a non-empty string"
            )

        guidance = block.get("guidance")
        if guidance is not None and not isinstance(guidance, str):
            raise AntigravityRewriteError(
                f"blocks[{index}].guidance must be a string when present"
            )

        if mode == "repair":
            candidate = block.get("candidate")
            issues = block.get("issues")
            if not isinstance(candidate, str) or not candidate.strip():
                raise AntigravityRewriteError(
                    f"blocks[{index}].candidate must be a non-empty string"
                )
            if (
                not isinstance(issues, list)
                or not issues
                or any(
                    not isinstance(issue, str) or not issue.strip() for issue in issues
                )
            ):
                raise AntigravityRewriteError(
                    f"blocks[{index}].issues must be a non-empty array of strings"
                )

    return job


def build_stream_input(prompt: str, job: dict[str, Any]) -> str:
    payload = json.dumps(
        {"instructions": prompt, "job": job},
        ensure_ascii=False,
        separators=(",", ":"),
    )
    event = {
        "event": "user",
        "message": {
            "role": "user",
            "content": [{"type": "text", "text": payload}],
        },
    }
    return json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n"


def run_antigravity(stream_input: str) -> str:
    agy_path = shutil.which("agy")
    if agy_path is None:
        raise AntigravityRewriteError("agy is not installed or not available on PATH")

    command = [
        agy_path,
        "--print=",
        "--model",
        ANTIGRAVITY_MODEL,
        "--effort",
        "high",
        "--sandbox",
        "--disable-slash-commands",
        "--input-format",
        "stream-json",
        "--output-format",
        "stream-json",
        "--print-timeout",
        ANTIGRAVITY_PRINT_TIMEOUT,
    ]

    try:
        with tempfile.TemporaryDirectory(prefix="japanese-editor-") as workdir:
            result = subprocess.run(
                command,
                input=stream_input,
                text=True,
                encoding="utf-8",
                capture_output=True,
                cwd=workdir,
                timeout=ANTIGRAVITY_TIMEOUT_SECONDS,
                check=False,
            )
    except subprocess.TimeoutExpired as error:
        raise AntigravityRewriteError(
            f"agy timed out after {ANTIGRAVITY_TIMEOUT_SECONDS} seconds"
        ) from error

    if result.returncode != 0:
        detail = result.stderr.strip() or "no diagnostic output"
        raise AntigravityRewriteError(
            f"agy exited with status {result.returncode}: {detail}"
        )

    return parse_antigravity_events(result.stdout)


def parse_antigravity_events(stdout: str) -> str:
    init_events: list[dict[str, Any]] = []
    result_events: list[dict[str, Any]] = []

    for line_number, line in enumerate(stdout.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            raise AntigravityRewriteError(
                f"agy output line {line_number} is not valid JSON"
            ) from error
        if not isinstance(event, dict):
            raise AntigravityRewriteError(
                f"agy output line {line_number} is not a JSON object"
            )

        event_type = event.get("event")
        if event_type == "init":
            init_events.append(event)
        elif event_type == "result":
            result_events.append(event)
        elif event_type == "step_update":
            step_update = event.get("step_update")
            if isinstance(step_update, dict) and step_update.get("step_type") == "tool":
                tool_name = step_update.get("tool_name", "unknown")
                raise AntigravityRewriteError(
                    f"Gemini attempted to use a tool: {tool_name}"
                )

    if len(init_events) != 1:
        raise AntigravityRewriteError(
            f"expected one agy init event, received {len(init_events)}"
        )
    init = init_events[0].get("init")
    if not isinstance(init, dict) or init.get("model") != ANTIGRAVITY_MODEL:
        actual_model = init.get("model") if isinstance(init, dict) else None
        raise AntigravityRewriteError(f"agy used unexpected model: {actual_model!r}")
    if len(result_events) != 1:
        raise AntigravityRewriteError(
            f"expected one agy result event, received {len(result_events)}"
        )
    result = result_events[0].get("result")
    if not isinstance(result, dict):
        raise AntigravityRewriteError("agy result payload is missing")
    if result.get("status") != "SUCCESS":
        detail = result.get("error") or result.get("status")
        raise AntigravityRewriteError(f"agy did not complete successfully: {detail}")

    response = result.get("response")
    if not isinstance(response, str) or not response.strip():
        raise AntigravityRewriteError("agy returned an empty response")
    return response


def validate_response(response: str, job: dict[str, Any]) -> dict[str, Any]:
    try:
        candidate = json.loads(response)
    except json.JSONDecodeError as error:
        raise AntigravityRewriteError("Gemini response is not valid JSON") from error

    if not isinstance(candidate, dict):
        raise AntigravityRewriteError("Gemini response must be a JSON object")
    blocks = candidate.get("blocks")
    if not isinstance(blocks, list):
        raise AntigravityRewriteError("Gemini response blocks must be an array")

    expected_ids = [block["id"] for block in job["blocks"]]
    actual_ids: list[str] = []
    for index, block in enumerate(blocks):
        if not isinstance(block, dict):
            raise AntigravityRewriteError(
                f"Gemini response blocks[{index}] must be an object"
            )
        block_id = block.get("id")
        text = block.get("text")
        if not isinstance(block_id, str):
            raise AntigravityRewriteError(
                f"Gemini response blocks[{index}].id must be a string"
            )
        if not isinstance(text, str) or not text.strip():
            raise AntigravityRewriteError(
                f"Gemini response blocks[{index}].text must be a non-empty string"
            )
        actual_ids.append(block_id)

    if actual_ids != expected_ids:
        raise AntigravityRewriteError(
            f"Gemini response block ids differ: expected {expected_ids}, received {actual_ids}"
        )

    return {"blocks": blocks}


def main() -> int:
    args = parse_args()
    try:
        job = load_job(args.mode)
        prompt = PROMPT_PATHS[args.mode].read_text(encoding="utf-8")
        stream_input = build_stream_input(prompt, job)
        response = run_antigravity(stream_input)
        candidate = validate_response(response, job)
    except (AntigravityRewriteError, OSError) as error:
        print(f"Antigravity rewrite unavailable: {error}", file=sys.stderr)
        return 1

    json.dump(candidate, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
