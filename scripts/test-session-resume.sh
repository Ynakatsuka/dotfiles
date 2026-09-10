#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null && pwd)
session_resume_list="$repo_root/home/dot_local/bin/executable_session-resume-list"

python3 - "$repo_root" "$session_resume_list" <<'PY'
import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
import uuid
from pathlib import Path

REPO_ROOT = Path(sys.argv[1])
HELPER = Path(sys.argv[2])


class SessionResumeTest(unittest.TestCase):
    @staticmethod
    def dirs(temporary):
        root = Path(temporary).resolve()
        cwd, home = root / "work", root / "home"
        cwd.mkdir()
        home.mkdir()
        return root, cwd, home

    @staticmethod
    def rows(output):
        return [line.split("\t") for line in output.splitlines() if line]

    def run_cli(self, cwd, home, *args):
        env = os.environ.copy()
        env["HOME"] = str(home)
        env.pop("CLAUDE_CONFIG_DIR", None)
        env.pop("CODEX_HOME", None)
        return subprocess.run([sys.executable, str(HELPER), *map(str, args)], cwd=str(cwd), env=env, text=True, capture_output=True)

    def assert_rows(self, rows):
        for row in rows:
            self.assertEqual(len(row), 6, row)
            self.assertIn(row[0], ("claude", "codex"), row)
            self.assertTrue(row[1], row)
            self.assertTrue(row[2].startswith("First: "), row)
            self.assertTrue(row[3].startswith("Latest: "), row)
            self.assertTrue(row[4] and row[5], row)

    @staticmethod
    def write_jsonl(path, records, trailing=True):
        path.parent.mkdir(parents=True, exist_ok=True)
        text = "\n".join(json.dumps(row, ensure_ascii=False) for row in records)
        path.write_text(text + ("\n" if trailing else ""), encoding="utf-8")
        return path

    def write_claude(self, home, cwd, session_id, records, mtime=None):
        project = str(cwd).replace("/", "-").replace(".", "-")
        path = home / ".claude" / "projects" / project / f"{session_id}.jsonl"
        records = [{**record, "sessionId": record.get("sessionId", session_id)} for record in records]
        self.write_jsonl(path, records)
        if mtime is not None:
            os.utime(path, ns=(mtime * 1_000_000_000,) * 2)
        return path

    def write_codex(self, home, cwd, session_id, records, mtime=None, name=None, trailing=True):
        path = home / ".codex" / "sessions" / "2026" / "09" / "10" / f"{name or session_id}.jsonl"
        self.write_jsonl(path, [self.codex_meta(cwd, session_id), *records], trailing)
        if mtime is not None:
            os.utime(path, ns=(mtime * 1_000_000_000,) * 2)
        return path

    @staticmethod
    def codex_meta(cwd, session_id):
        return {"type": "session_meta", "payload": {"cwd": str(cwd), "id": session_id}}

    @staticmethod
    def claude_user(text, **flags):
        row = {"type": "user", "message": {"role": "user", "content": [{"type": "text", "text": text}]}}
        row.update(flags)
        return row

    @staticmethod
    def codex_event(text):
        return {"type": "event_msg", "payload": {"type": "user_message", "message": text}}

    @staticmethod
    def codex_response(text, role="user"):
        block = "input_text" if role == "user" else "output_text"
        return {"type": "response_item", "payload": {"type": "message", "role": role, "content": [{"type": block, "text": text}]}}

    def test_limits_and_mtime_order_across_tools(self):
        with tempfile.TemporaryDirectory() as td:
            _, cwd, home = self.dirs(td)
            session_ids = []
            for index in range(110):
                session_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"session-{index}"))
                session_ids.append(session_id)
                if index % 2:
                    self.write_claude(home, cwd, session_id, [self.claude_user(f"prompt-{index}")], 1_700_000_000 + index)
                else:
                    self.write_codex(home, cwd, session_id, [self.codex_event(f"prompt-{index}")], 1_700_000_000 + index)
            result = self.run_cli(cwd, home)
            self.assertEqual(result.returncode, 0, result.stderr)
            rows = self.rows(result.stdout)
            self.assert_rows(rows)
            self.assertEqual(len(rows), 100)
            self.assertEqual([row[4] for row in rows], list(reversed(session_ids[10:])))
            self.assertEqual({row[0] for row in rows}, {"claude", "codex"})
            result = self.run_cli(cwd, home, "--limit", "3")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual([row[4] for row in self.rows(result.stdout)], list(reversed(session_ids[-3:])))
            result = self.run_cli(cwd, home, "--limit", "150")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(self.rows(result.stdout)), 100)

    def test_codex_metadata_cwd_is_the_filter(self):
        with tempfile.TemporaryDirectory() as td:
            root, cwd, home = self.dirs(td)
            keep_id, skip_id = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"
            self.write_codex(home, cwd, keep_id, [self.codex_event("keep"), self.codex_response("kept latest")], 1_700_000_002)
            self.write_codex(home, root / "other", skip_id, [self.codex_event(f"contains target {cwd}")], 1_700_000_003, "wrong-cwd")
            result = self.run_cli(cwd, home)
            self.assertEqual(result.returncode, 0, result.stderr)
            rows = self.rows(result.stdout)
            self.assert_rows(rows)
            self.assertEqual([row[4] for row in rows], [keep_id])
            self.assertEqual(rows[0][2:4], ["First: keep", "Latest: kept latest"])

    def test_codex_first_latest_preview_and_trailing_record(self):
        with tempfile.TemporaryDirectory() as td:
            _, cwd, home = self.dirs(td)
            first, latest = "first-" + ("長いプロンプト" * 40), "latest prompt after 250 assistant records"
            records = [self.codex_event(first)] + [self.codex_response(f"assistant-{i}", "assistant") for i in range(250)]
            records.append(self.codex_response(latest))
            path = self.write_codex(home, cwd, "33333333-3333-4333-8333-333333333333", records, trailing=False)
            result = self.run_cli(cwd, home)
            self.assertEqual(result.returncode, 0, result.stderr)
            rows = self.rows(result.stdout)
            self.assert_rows(rows)
            self.assertEqual(len(rows), 1)
            first_field = rows[0][2][len("First: ") :]
            self.assertTrue(first_field.startswith(first[:30]))
            self.assertLess(len(first_field), len(first))
            self.assertLessEqual(len(first_field), 120)
            self.assertEqual(rows[0][3], "Latest: " + latest)
            preview = self.run_cli(cwd, home, "--preview", "codex", path)
            self.assertEqual(preview.returncode, 0, preview.stderr)
            self.assertIn(first, preview.stdout)
            self.assertIn(latest, preview.stdout)

    def test_prompt_compaction_and_claude_filters(self):
        with tempfile.TemporaryDirectory() as td:
            _, cwd, home = self.dirs(td)
            long_prompt = "初回\t質問\n二行目 " + "x" * 180
            codex_id = "44444444-4444-4444-8444-444444444444"
            injected = [
                self.codex_response(f"# AGENTS.md instructions for {cwd}\n<INSTRUCTIONS>ignored</INSTRUCTIONS>"),
                self.codex_response("<environment_context>\n  <cwd>ignored</cwd>\n</environment_context>"),
            ]
            self.write_codex(home, cwd, codex_id, injected + [self.codex_event(long_prompt), self.codex_response("最後\nの質問\tです")])
            result = self.run_cli(cwd, home)
            self.assertEqual(result.returncode, 0, result.stderr)
            row = self.rows(result.stdout)[0]
            self.assert_rows([row])
            self.assertNotIn("\n", row[2] + row[3])
            self.assertNotIn("\t", row[2] + row[3])
            self.assertTrue(row[2].startswith("First: 初回 質問 二行目"), row)
            self.assertLessEqual(len(row[2][len("First: ") :]), 120)
            self.assertEqual(row[3], "Latest: 最後 の質問 です")
            claude_id = "55555555-5555-4555-8555-555555555555"
            records = [self.claude_user("ignore", isMeta=True), self.claude_user("summary", isCompactSummary=True), {"type": "user", "message": {"role": "user", "content": [{"type": "tool_result", "content": "ignore"}]}}, self.claude_user("claude first"), self.claude_user("claude latest")]
            self.write_claude(home, cwd, claude_id, records, 1_700_000_010)
            result = self.run_cli(cwd, home)
            self.assertEqual(result.returncode, 0, result.stderr)
            by_tool = {row[0]: row for row in self.rows(result.stdout)}
            self.assertEqual(by_tool["claude"][2:4], ["First: claude first", "Latest: claude latest"])

    def test_one_prompt_session_has_same_first_and_latest(self):
        with tempfile.TemporaryDirectory() as td:
            _, cwd, home = self.dirs(td)
            self.write_codex(home, cwd, "66666666-6666-4666-8666-666666666666", [self.codex_response("only prompt")], 1_700_000_001)
            self.write_claude(home, cwd, "77777777-7777-4777-8777-777777777777", [self.claude_user("only prompt")], 1_700_000_002)
            result = self.run_cli(cwd, home)
            self.assertEqual(result.returncode, 0, result.stderr)
            rows = {row[0]: row for row in self.rows(result.stdout)}
            self.assertEqual(rows["codex"][2:4], ["First: only prompt", "Latest: only prompt"])
            self.assertEqual(rows["claude"][2:4], ["First: only prompt", "Latest: only prompt"])

    def test_invalid_limit_and_malformed_matching_metadata_fail(self):
        with tempfile.TemporaryDirectory() as td:
            _, cwd, home = self.dirs(td)
            result = self.run_cli(cwd, home, "--limit", "0")
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertIn("--limit must be a positive integer", result.stderr)
            malformed = home / ".codex" / "sessions" / "2026" / "09" / "10" / "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa.jsonl"
            self.write_jsonl(malformed, [{"type": "session_meta", "payload": {"cwd": str(cwd)}}])
            result = self.run_cli(cwd, home)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertIn("'id'", result.stderr)

    def test_zsh_widget_resume_commands_and_fzf_columns(self):
        claude_zsh = REPO_ROOT / "home/private_dot_config/zsh/claude.zsh"
        with tempfile.TemporaryDirectory() as td:
            root, cwd, home = self.dirs(td)
            claude_id, codex_id = "88888888-8888-4888-8888-888888888888", "99999999-9999-4999-8999-999999999999"
            self.write_claude(home, cwd, claude_id, [self.claude_user("claude")], 1_700_000_001)
            self.write_codex(home, cwd, codex_id, [self.codex_event("codex")], 1_700_000_002)
            for tool, session_id, expected in (("claude", claude_id, f"cl --resume={claude_id}"), ("codex", codex_id, f"codex resume {codex_id}")):
                args_log = root / f"fzf-{tool}.args"
                script = textwrap.dedent(
                    """
                    zle() { return 0; }
                    source "$TEST_CLAUDE_ZSH"
                    session-resume-list() { "$TEST_PYTHON" "$TEST_HELPER" "$@"; }
                    fzf() {
                      printf '%s\n' "$@" > "$TEST_FZF_ARGS"
                      local line tool_name
                      while IFS= read -r line; do
                        [[ -z "$line" ]] && continue
                        tool_name=${line%%$'\t'*}
                        if [[ "$tool_name" == "$TEST_FZF_TOOL" ]]; then
                          printf '%s\n' "$line"
                          return 0
                        fi
                      done
                      return 1
                    }
                    BUFFER=''; LBUFFER=''; RBUFFER=''; CURSOR=0
                    fzf-session-resume
                    printf '%s' "$BUFFER"
                    """
                )
                env = os.environ.copy()
                env.update({"HOME": str(home), "TEST_CLAUDE_ZSH": str(claude_zsh), "TEST_FZF_ARGS": str(args_log), "TEST_FZF_TOOL": tool, "TEST_HELPER": str(HELPER), "TEST_PYTHON": sys.executable})
                env.pop("FZF_SESSION_RESUME_LIMIT", None)
                env.pop("CLAUDE_CONFIG_DIR", None)
                env.pop("CODEX_HOME", None)
                result = subprocess.run(["zsh", "-f"], cwd=str(cwd), env=env, input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, expected)
                fzf_args = args_log.read_text(encoding="utf-8").splitlines()
                self.assertIn("--with-nth=1,2,3,4", fzf_args)
                preview_args = " ".join(fzf_args)
                self.assertIn("{1}", preview_args)
                self.assertIn("{6}", preview_args)


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]], verbosity=2)
PY
