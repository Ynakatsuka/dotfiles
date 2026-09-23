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


class RunAntigravityTest(unittest.TestCase):
    @mock.patch.object(rewrite_with_antigravity.shutil, "which", return_value="/usr/bin/agy")
    @mock.patch.object(rewrite_with_antigravity.subprocess, "run")
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


if __name__ == "__main__":
    unittest.main()
