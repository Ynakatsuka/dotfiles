from __future__ import annotations

import importlib.util
import json
import subprocess
import unittest
from pathlib import Path
from unittest import mock

SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "rewrite_with_antigravity.py"
)
MODULE_SPEC = importlib.util.spec_from_file_location(
    "rewrite_with_antigravity", SCRIPT_PATH
)
if MODULE_SPEC is None or MODULE_SPEC.loader is None:
    raise RuntimeError(f"Unable to load {SCRIPT_PATH}")
rewrite_with_antigravity = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(rewrite_with_antigravity)


def stream_output(*events: dict[str, object]) -> str:
    return "\n".join(json.dumps(event) for event in events) + "\n"


def init_event(*, tools: list[str] | None = None) -> dict[str, object]:
    return {
        "event": "init",
        "init": {
            "model": rewrite_with_antigravity.ANTIGRAVITY_MODEL,
            "tools": ["run_command"] if tools is None else tools,
        },
    }


def result_event(response: str) -> dict[str, object]:
    return {
        "event": "result",
        "result": {"status": "SUCCESS", "response": response},
    }


PRINT_TIMEOUT_STDERR = (
    "[agy] print timeout after 2m0s with turn in progress; returning partial output\n"
)
SINGLE_BLOCK_JOB = {"blocks": [{"id": "p001", "original": "一"}]}
SINGLE_BLOCK_RESPONSE = '{"blocks":[{"id":"p001","text":"一つ"}]}'


class ParseAntigravityEventsTest(unittest.TestCase):
    def test_accepts_success_without_tool_attempt(self) -> None:
        output = stream_output(init_event(), result_event('{"blocks":[]}'))

        self.assertEqual(
            rewrite_with_antigravity.parse_antigravity_events(output),
            '{"blocks":[]}',
        )

    def test_rejects_tool_attempt(self) -> None:
        output = stream_output(
            init_event(),
            {
                "event": "step_update",
                "step_update": {"step_type": "tool", "tool_name": "run_command"},
            },
            result_event('{"blocks":[]}'),
        )

        with self.assertRaisesRegex(
            rewrite_with_antigravity.AntigravityRewriteError,
            "attempted to use a tool",
        ):
            rewrite_with_antigravity.parse_antigravity_events(output)


class ValidateResponseTest(unittest.TestCase):
    def test_rejects_reordered_block_ids(self) -> None:
        job = {
            "blocks": [
                {"id": "p001", "original": "一"},
                {"id": "p002", "original": "二"},
            ]
        }
        response = json.dumps(
            {
                "blocks": [
                    {"id": "p002", "text": "二"},
                    {"id": "p001", "text": "一"},
                ]
            },
            ensure_ascii=False,
        )

        with self.assertRaisesRegex(
            rewrite_with_antigravity.AntigravityRewriteError,
            "block ids differ",
        ):
            rewrite_with_antigravity.validate_response(response, job)

    def test_accepts_response_in_json_code_fence(self) -> None:
        response = f"```json\n{SINGLE_BLOCK_RESPONSE}\n```\n"

        self.assertEqual(
            rewrite_with_antigravity.validate_response(response, SINGLE_BLOCK_JOB),
            {"blocks": [{"id": "p001", "text": "一つ"}]},
        )

    def test_accepts_trailing_text_after_valid_object(self) -> None:
        response = SINGLE_BLOCK_RESPONSE + "'"

        self.assertEqual(
            rewrite_with_antigravity.validate_response(response, SINGLE_BLOCK_JOB),
            {"blocks": [{"id": "p001", "text": "一つ"}]},
        )

    def test_validates_object_before_trailing_text(self) -> None:
        response = '{"blocks":[]}' + "'"

        with self.assertRaisesRegex(
            rewrite_with_antigravity.AntigravityRewriteError,
            "block ids differ",
        ):
            rewrite_with_antigravity.validate_response(response, SINGLE_BLOCK_JOB)

    def test_rejects_text_before_json(self) -> None:
        response = "結果です。\n" + SINGLE_BLOCK_RESPONSE

        with self.assertRaisesRegex(
            rewrite_with_antigravity.AntigravityRewriteError,
            "not valid JSON",
        ):
            rewrite_with_antigravity.validate_response(response, SINGLE_BLOCK_JOB)


@mock.patch.object(
    rewrite_with_antigravity.shutil, "which", return_value="/usr/bin/agy"
)
@mock.patch.object(rewrite_with_antigravity.subprocess, "run")
class RunAntigravityTest(unittest.TestCase):
    def test_runs_in_sandbox_and_disables_slash_commands(
        self, run: mock.Mock, _which: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=stream_output(init_event(), result_event('{"blocks":[]}')),
            stderr="",
        )

        rewrite_with_antigravity.run_antigravity("{}\n")

        command = run.call_args.args[0]
        self.assertIn("--sandbox", command)
        self.assertIn("--disable-slash-commands", command)
        self.assertNotIn("--dangerously-skip-permissions", command)
        self.assertEqual(run.call_args.kwargs["encoding"], "utf-8")
        self.assertTrue(
            Path(run.call_args.kwargs["cwd"]).name.startswith("japanese-editor-")
        )

    def test_uses_medium_effort_matching_model(
        self, run: mock.Mock, _which: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=stream_output(init_event(), result_event('{"blocks":[]}')),
            stderr="",
        )

        rewrite_with_antigravity.run_antigravity("{}\n")

        command = run.call_args.args[0]
        model = command[command.index("--model") + 1]
        effort = command[command.index("--effort") + 1]
        self.assertEqual(effort, "medium")
        self.assertEqual(model.rsplit("-", 1)[1], effort)

    def test_reports_print_timeout_with_empty_response(
        self, run: mock.Mock, _which: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=stream_output(init_event(), result_event("")),
            stderr=PRINT_TIMEOUT_STDERR,
        )

        with self.assertRaisesRegex(
            rewrite_with_antigravity.AntigravityRewriteError,
            "timed out after 120s",
        ):
            rewrite_with_antigravity.run_antigravity("{}\n")

    def test_rejects_partial_response_after_print_timeout(
        self, run: mock.Mock, _which: mock.Mock
    ) -> None:
        run.return_value = subprocess.CompletedProcess(
            args=[],
            returncode=0,
            stdout=stream_output(init_event(), result_event(SINGLE_BLOCK_RESPONSE)),
            stderr=PRINT_TIMEOUT_STDERR,
        )

        with self.assertRaisesRegex(
            rewrite_with_antigravity.AntigravityRewriteError,
            "timed out after 120s",
        ):
            rewrite_with_antigravity.run_antigravity("{}\n")


if __name__ == "__main__":
    unittest.main()
