#!/usr/bin/env python3
"""PR briefing helpers: index a combined git diff and render a self-contained HTML briefing.

Subcommands:
  index   parse a combined unified diff into files.json and print a compact file list
  render  merge files.json / pr.json / pr.diff with a hand-written briefing.json into HTML

The renderer copies every code excerpt verbatim out of the diff, so the briefing
never contains retyped code.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
import unicodedata
from dataclasses import dataclass, field
from itertools import count
from pathlib import Path
from typing import Any

DIFF_HEADER_RE = re.compile(r'^diff --git "?a/(.+?)"? "?b/(.+?)"?$')
HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$")

DETAILED_CATEGORIES = ("source", "config", "doc")
LISTED_CATEGORIES = ("test", "generated", "binary")
ATTENTION_LABELS = {"high": "要注目", "medium": "確認", "low": "参考"}
CATEGORY_LABELS = {
    "source": "実装",
    "config": "設定",
    "doc": "文書",
    "test": "テスト関連",
    "generated": "生成物",
    "binary": "binary",
}


class BriefingError(Exception):
    """Fatal input problem. The caller stops instead of rendering a partial briefing."""


@dataclass
class Hunk:
    index: int
    header: str
    old_start: int
    new_start: int
    lines: list[str] = field(default_factory=list)


@dataclass
class FileDiff:
    path: str
    old_path: str | None = None
    status: str = "modified"
    binary: bool = False
    additions: int = 0
    deletions: int = 0
    hunks: list[Hunk] = field(default_factory=list)

    def to_json(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "old_path": self.old_path,
            "status": self.status,
            "binary": self.binary,
            "additions": self.additions,
            "deletions": self.deletions,
            "hunks": [
                {"index": h.index, "header": h.header, "lines": len(h.lines)}
                for h in self.hunks
            ],
        }


def parse_diff(text: str) -> list[FileDiff]:
    """Parse a combined unified diff (``gh pr diff <pr>``) into per-file records."""
    files: list[FileDiff] = []
    current: FileDiff | None = None
    hunk: Hunk | None = None
    old_rem = 0
    new_rem = 0

    for line in text.split("\n"):
        in_body = hunk is not None and (old_rem > 0 or new_rem > 0)

        if not in_body and line.startswith("diff --git "):
            match = DIFF_HEADER_RE.match(line)
            if match is None:
                raise BriefingError(f"unparsable diff header: {line}")
            old_path, new_path = match.group(1), match.group(2)
            current = FileDiff(path=new_path, old_path=old_path)
            hunk = None
            old_rem = new_rem = 0
            files.append(current)
            continue

        if current is None:
            continue

        if in_body:
            assert hunk is not None
            marker = line[:1]
            if marker == "\\":
                hunk.lines.append(line)
                continue
            if marker == "+":
                new_rem -= 1
                current.additions += 1
            elif marker == "-":
                old_rem -= 1
                current.deletions += 1
            elif marker == " " or line == "":
                old_rem -= 1
                new_rem -= 1
            else:
                raise BriefingError(
                    f"unexpected line inside a hunk of {current.path}: {line!r}"
                )
            hunk.lines.append(line)
            continue

        hunk_match = HUNK_RE.match(line)
        if hunk_match is not None:
            old_start = int(hunk_match.group(1))
            old_count = int(hunk_match.group(2) or "1")
            new_start = int(hunk_match.group(3))
            new_count = int(hunk_match.group(4) or "1")
            hunk = Hunk(
                index=len(current.hunks) + 1,
                header=line,
                old_start=old_start,
                new_start=new_start,
            )
            current.hunks.append(hunk)
            old_rem, new_rem = old_count, new_count
            continue

        if line.startswith("new file mode"):
            current.status = "added"
        elif line.startswith("deleted file mode"):
            current.status = "deleted"
        elif line.startswith("rename to "):
            current.status = "renamed"
        elif line.startswith("Binary files ") or line.startswith("GIT binary patch"):
            current.binary = True
        elif line.startswith("--- ") and line[4:] == "/dev/null":
            current.status = "added"
            current.old_path = None
        elif line.startswith("+++ ") and line[4:] == "/dev/null":
            current.status = "deleted"
            current.path = current.old_path or current.path

    for entry in files:
        if entry.old_path == entry.path:
            entry.old_path = None
    return files


def load_json(route: Path) -> Any:
    try:
        return json.loads(route.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise BriefingError(f"file not found: {route}") from exc
    except json.JSONDecodeError as exc:
        raise BriefingError(f"invalid JSON in {route}: {exc}") from exc


def cmd_index(args: argparse.Namespace) -> int:
    diff_route = Path(args.diff)
    pr_json = load_json(Path(args.pr_json))
    files = parse_diff(diff_route.read_text(encoding="utf-8"))
    if not files:
        raise BriefingError(f"no file diffs found in {diff_route}")

    payload = {
        "pr": pr_json.get("number"),
        "diff_file": str(diff_route),
        "files": [entry.to_json() for entry in files],
    }
    Path(args.out).write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print(f"changed files: {len(files)}")
    for entry in files:
        flag = " binary" if entry.binary else ""
        rename = f" (from {entry.old_path})" if entry.old_path else ""
        print(
            f"  {entry.path}{rename}\t{entry.status}{flag}\t"
            f"+{entry.additions} -{entry.deletions}\thunks={len(entry.hunks)}"
        )
    return 0


def require_text(value: Any, label: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise BriefingError(f"{label} must be a non-empty string")
    return value


def require_list(value: Any, label: str) -> list[Any]:
    if not isinstance(value, list):
        raise BriefingError(f"{label} must be a list")
    return value


def check_keys(obj: dict[str, Any], allowed: set[str], label: str) -> None:
    unknown = sorted(set(obj) - allowed)
    if unknown:
        raise BriefingError(f"{label} has unknown keys: {', '.join(unknown)}")


def validate_nodes(value: Any, label: str) -> list[str]:
    """Validate an id/label list and return the declared ids."""
    entries = require_list(value, label)
    if not entries:
        raise BriefingError(f"{label} must not be empty")
    ids: list[str] = []
    for index, entry in enumerate(entries):
        item_label = f"{label}[{index}]"
        if not isinstance(entry, dict):
            raise BriefingError(f"{item_label} must be an object")
        check_keys(entry, {"id", "label"}, item_label)
        entry_id = require_text(entry.get("id"), f"{item_label}.id")
        require_text(entry.get("label"), f"{item_label}.label")
        if entry_id in ids:
            raise BriefingError(f"{item_label}.id is duplicated: {entry_id}")
        ids.append(entry_id)
    return ids


def validate_diagram(flow: dict[str, Any], label: str) -> None:
    if flow["kind"] == "flow":
        ids = validate_nodes(flow.get("nodes"), f"{label}.nodes")
        edges = require_list(flow.get("edges"), f"{label}.edges")
        if not edges:
            raise BriefingError(f"{label}.edges must not be empty")
        for index, edge in enumerate(edges):
            edge_label = f"{label}.edges[{index}]"
            if not isinstance(edge, dict):
                raise BriefingError(f"{edge_label} must be an object")
            check_keys(edge, {"from", "to", "label"}, edge_label)
            for side in ("from", "to"):
                node_id = require_text(edge.get(side), f"{edge_label}.{side}")
                if node_id not in ids:
                    raise BriefingError(
                        f"{edge_label}.{side} is not a declared node id: {node_id}"
                    )
            if "label" in edge:
                require_text(edge.get("label"), f"{edge_label}.label")
        return

    ids = validate_nodes(flow.get("actors"), f"{label}.actors")
    messages = require_list(flow.get("messages"), f"{label}.messages")
    if not messages:
        raise BriefingError(f"{label}.messages must not be empty")
    for index, message in enumerate(messages):
        message_label = f"{label}.messages[{index}]"
        if not isinstance(message, dict):
            raise BriefingError(f"{message_label} must be an object")
        check_keys(message, {"from", "to", "label", "kind"}, message_label)
        for side in ("from", "to"):
            actor_id = require_text(message.get(side), f"{message_label}.{side}")
            if actor_id not in ids:
                raise BriefingError(
                    f"{message_label}.{side} is not a declared actor id: {actor_id}"
                )
        require_text(message.get("label"), f"{message_label}.label")
        if message.get("kind", "call") not in ("call", "return"):
            raise BriefingError(f"{message_label}.kind must be 'call' or 'return'")


def validate_briefing(
    briefing: dict[str, Any], pr_json: dict[str, Any], files: list[FileDiff]
) -> None:
    check_keys(
        briefing,
        {"pr", "purpose", "flows", "files", "contracts", "priorities", "limits"},
        "briefing",
    )
    if briefing.get("pr") != pr_json.get("number"):
        raise BriefingError(
            f"briefing.pr ({briefing.get('pr')}) does not match "
            f"pr.json number ({pr_json.get('number')})"
        )

    purpose = briefing.get("purpose")
    if not isinstance(purpose, dict):
        raise BriefingError("briefing.purpose must be an object")
    check_keys(purpose, {"stated", "observed", "gaps"}, "briefing.purpose")
    require_text(purpose.get("stated"), "briefing.purpose.stated")
    require_text(purpose.get("observed"), "briefing.purpose.observed")

    diff_paths = [entry.path for entry in files]
    hunk_counts = {entry.path: len(entry.hunks) for entry in files}
    entries = require_list(briefing.get("files"), "briefing.files")
    seen: list[str] = []
    for index, entry in enumerate(entries):
        label = f"briefing.files[{index}]"
        if not isinstance(entry, dict):
            raise BriefingError(f"{label} must be an object")
        route = require_text(entry.get("path"), f"{label}.path")
        if route not in hunk_counts:
            raise BriefingError(f"{label}.path is not in the PR diff: {route}")
        if route in seen:
            raise BriefingError(f"{label}.path is duplicated: {route}")
        seen.append(route)

        category = entry.get("category")
        if category in DETAILED_CATEGORIES:
            check_keys(
                entry,
                {
                    "path",
                    "category",
                    "attention",
                    "role",
                    "change",
                    "excerpt",
                    "impact",
                    "review_points",
                },
                label,
            )
            if entry.get("attention") not in ATTENTION_LABELS:
                raise BriefingError(
                    f"{label}.attention must be one of {', '.join(ATTENTION_LABELS)}"
                )
            require_text(entry.get("role"), f"{label}.role")
            require_text(entry.get("change"), f"{label}.change")
            require_text(entry.get("impact"), f"{label}.impact")
            for point_index, point in enumerate(
                require_list(entry.get("review_points", []), f"{label}.review_points")
            ):
                require_text(point, f"{label}.review_points[{point_index}]")
            for hunk_index in require_list(entry.get("excerpt", []), f"{label}.excerpt"):
                if not isinstance(hunk_index, int) or not (
                    1 <= hunk_index <= hunk_counts[route]
                ):
                    raise BriefingError(
                        f"{label}.excerpt has hunk {hunk_index}, but {route} has "
                        f"{hunk_counts[route]} hunk(s)"
                    )
        elif category == "test":
            # Test content is deliberately never explained, so descriptive keys are rejected.
            check_keys(entry, {"path", "category"}, label)
        elif category in LISTED_CATEGORIES:
            check_keys(entry, {"path", "category", "note"}, label)
            if "note" in entry:
                require_text(entry.get("note"), f"{label}.note")
        else:
            raise BriefingError(
                f"{label}.category must be one of "
                f"{', '.join(DETAILED_CATEGORIES + LISTED_CATEGORIES)}"
            )

    missing = [route for route in diff_paths if route not in seen]
    if missing:
        raise BriefingError(
            "briefing.files is missing changed files: " + ", ".join(missing)
        )

    for index, flow in enumerate(require_list(briefing.get("flows", []), "briefing.flows")):
        label = f"briefing.flows[{index}]"
        if not isinstance(flow, dict):
            raise BriefingError(f"{label} must be an object")
        check_keys(
            flow,
            {
                "title",
                "kind",
                "steps",
                "columns",
                "rows",
                "nodes",
                "edges",
                "actors",
                "messages",
            },
            label,
        )
        require_text(flow.get("title"), f"{label}.title")
        if flow.get("kind") in ("flow", "sequence"):
            validate_diagram(flow, label)
        elif flow.get("kind") == "steps":
            steps = require_list(flow.get("steps"), f"{label}.steps")
            if not steps:
                raise BriefingError(f"{label}.steps must not be empty")
            for step_index, step in enumerate(steps):
                if not isinstance(step, dict):
                    raise BriefingError(f"{label}.steps[{step_index}] must be an object")
                check_keys(step, {"label", "detail"}, f"{label}.steps[{step_index}]")
                require_text(step.get("label"), f"{label}.steps[{step_index}].label")
        elif flow.get("kind") == "table":
            columns = require_list(flow.get("columns"), f"{label}.columns")
            for row_index, row in enumerate(require_list(flow.get("rows"), f"{label}.rows")):
                if not isinstance(row, list) or len(row) != len(columns):
                    raise BriefingError(
                        f"{label}.rows[{row_index}] must have {len(columns)} cells"
                    )
        else:
            raise BriefingError(
                f"{label}.kind must be 'flow', 'sequence', 'steps', or 'table'"
            )

    for index, contract in enumerate(
        require_list(briefing.get("contracts", []), "briefing.contracts")
    ):
        label = f"briefing.contracts[{index}]"
        if not isinstance(contract, dict):
            raise BriefingError(f"{label} must be an object")
        check_keys(contract, {"kind", "name", "before", "after", "note"}, label)
        require_text(contract.get("kind"), f"{label}.kind")
        require_text(contract.get("name"), f"{label}.name")
        require_text(contract.get("before"), f"{label}.before")
        require_text(contract.get("after"), f"{label}.after")

    for index, priority in enumerate(
        require_list(briefing.get("priorities", []), "briefing.priorities")
    ):
        label = f"briefing.priorities[{index}]"
        if not isinstance(priority, dict):
            raise BriefingError(f"{label} must be an object")
        check_keys(priority, {"path", "target", "reason"}, label)
        route = require_text(priority.get("path"), f"{label}.path")
        if route not in hunk_counts:
            raise BriefingError(f"{label}.path is not in the PR diff: {route}")
        require_text(priority.get("reason"), f"{label}.reason")

    for index, limit in enumerate(require_list(briefing.get("limits", []), "briefing.limits")):
        require_text(limit, f"briefing.limits[{index}]")


def esc(value: Any) -> str:
    return html.escape("" if value is None else str(value), quote=True)


def slugify(route: str) -> str:
    return "file-" + re.sub(r"[^A-Za-z0-9]+", "-", route).strip("-").lower()


def render_hunk(hunk: Hunk) -> str:
    rows = [
        f'<tr class="hunk"><td class="ln" colspan="2"></td>'
        f'<td class="code">{esc(hunk.header)}</td></tr>'
    ]
    old_no, new_no = hunk.old_start, hunk.new_start
    for line in hunk.lines:
        marker = line[:1]
        if marker == "\\":
            rows.append(
                f'<tr class="meta"><td class="ln"></td><td class="ln"></td>'
                f'<td class="code">{esc(line)}</td></tr>'
            )
            continue
        if marker == "+":
            left, right, kind = "", str(new_no), "add"
            new_no += 1
        elif marker == "-":
            left, right, kind = str(old_no), "", "del"
            old_no += 1
        else:
            left, right, kind = str(old_no), str(new_no), "ctx"
            old_no += 1
            new_no += 1
        rows.append(
            f'<tr class="{kind}"><td class="ln">{left}</td><td class="ln">{right}</td>'
            f'<td class="code">{esc(line)}</td></tr>'
        )
    return '<table class="diff">' + "".join(rows) + "</table>"


def render_purpose(purpose: dict[str, Any]) -> str:
    parts = [
        "<h2>目的</h2>",
        '<dl class="kv">',
        f"<dt>PR 本文の説明</dt><dd>{esc(purpose['stated'])}</dd>",
        f"<dt>実装から確認できる内容</dt><dd>{esc(purpose['observed'])}</dd>",
    ]
    gaps = purpose.get("gaps") or []
    if gaps:
        items = "".join(f"<li>{esc(gap)}</li>" for gap in gaps)
        parts.append(f"<dt>差異・不明点</dt><dd><ul>{items}</ul></dd>")
    parts.append("</dl>")
    return "".join(parts)


def render_map(
    detailed: list[dict[str, Any]], listed: list[dict[str, Any]], stats: dict[str, FileDiff]
) -> str:
    rows = []
    for entry in detailed:
        route = entry["path"]
        stat = stats[route]
        attention = entry["attention"]
        rows.append(
            f"<tr>"
            f'<td><a href="#{slugify(route)}"><code>{esc(route)}</code></a></td>'
            f"<td>{esc(entry['role'])}</td>"
            f"<td>{esc(entry['change'])}</td>"
            f'<td class="num"><span class="add">+{stat.additions}</span> '
            f'<span class="del">-{stat.deletions}</span></td>'
            f'<td><span class="badge {attention}">{ATTENTION_LABELS[attention]}</span></td>'
            f"</tr>"
        )
    table = (
        '<table class="map"><thead><tr><th>ファイル</th><th>役割</th>'
        "<th>変更の要点</th><th>増減</th><th>注目度</th></tr></thead>"
        f"<tbody>{''.join(rows)}</tbody></table>"
    )

    grouped: dict[str, list[dict[str, Any]]] = {}
    for entry in listed:
        grouped.setdefault(entry["category"], []).append(entry)
    blocks = []
    for category in LISTED_CATEGORIES:
        group = grouped.get(category)
        if not group:
            continue
        items = []
        for entry in group:
            stat = stats[entry["path"]]
            note = f" — {esc(entry['note'])}" if entry.get("note") else ""
            items.append(
                f"<li><code>{esc(entry['path'])}</code> "
                f'<span class="num">+{stat.additions} -{stat.deletions}</span>{note}</li>'
            )
        blocks.append(
            f'<details class="listed"><summary>{CATEGORY_LABELS[category]}: '
            f"{len(group)} 件（内容説明は省略）</summary><ul>{''.join(items)}</ul></details>"
        )
    return "<h2>変更マップ</h2>" + table + "".join(blocks)


DIAGRAM_FONT = 12
NODE_HEIGHT = 34
NODE_PAD_X = 14
NODE_MIN_WIDTH = 96
NODE_GAP = 24
LAYER_GAP = 46
ACTOR_HEIGHT = 30
ACTOR_GAP = 28
MESSAGE_ROW = 46
DIAGRAM_MARGIN = 12

_diagram_ids = count(1)


def text_width(text: str, font_size: int = DIAGRAM_FONT) -> float:
    """Estimate rendered width so SVG boxes fit both Japanese and ASCII labels."""
    units = sum(
        1.0 if unicodedata.east_asian_width(char) in "WF" else 0.56 for char in text
    )
    return units * font_size


def text_bounds(
    x: float, y: float, text: str, anchor: str, font_size: int
) -> tuple[float, float, float, float]:
    width = text_width(text, font_size)
    if anchor == "start":
        left, right = x, x + width
    elif anchor == "end":
        left, right = x - width, x
    else:
        left, right = x - width / 2, x + width / 2
    return (left, y - font_size, right, y + font_size * 0.5)


def svg_open(
    title: str, bounds: list[tuple[float, float, float, float]], marker: str
) -> str:
    """Open an SVG sized from the drawn geometry so no label is clipped."""
    pad = 6.0
    min_x = min(box[0] for box in bounds) - pad
    min_y = min(box[1] for box in bounds) - pad
    width = max(box[2] for box in bounds) + pad - min_x
    height = max(box[3] for box in bounds) + pad - min_y
    return (
        f'<svg class="diagram" viewBox="{min_x:.0f} {min_y:.0f} {width:.0f} {height:.0f}" '
        f'width="{width:.0f}" height="{height:.0f}" role="img" '
        f'aria-label="{esc(title)}"><defs>'
        f'<marker id="{marker}" viewBox="0 0 10 10" refX="9" refY="5" '
        f'markerWidth="6" markerHeight="6" orient="auto-start-reverse">'
        f'<path class="dg-head" d="M 0 0 L 10 5 L 0 10 z" /></marker></defs>'
    )


def layer_flow_nodes(
    node_ids: list[str], edges: list[dict[str, Any]]
) -> tuple[dict[str, int], set[int]]:
    """Assign each node a layer and report which edge indexes point backwards."""
    outgoing: dict[str, list[tuple[int, str]]] = {node: [] for node in node_ids}
    for index, edge in enumerate(edges):
        outgoing[edge["from"]].append((index, edge["to"]))

    back_edges: set[int] = set()
    state = {node: "new" for node in node_ids}
    indegree = {node: 0 for node in node_ids}
    for edge in edges:
        indegree[edge["to"]] += 1
    roots = [node for node in node_ids if indegree[node] == 0]
    if not roots and node_ids:
        raise BriefingError(
            "flow has no start node: every node has an incoming edge, so the "
            "diagram cannot be laid out"
        )

    for start in roots + node_ids:
        if state[start] != "new":
            continue
        stack: list[tuple[str, int]] = [(start, 0)]
        state[start] = "open"
        while stack:
            node, cursor = stack.pop()
            if cursor < len(outgoing[node]):
                stack.append((node, cursor + 1))
                edge_index, target = outgoing[node][cursor]
                if state[target] == "open":
                    back_edges.add(edge_index)
                elif state[target] == "new":
                    state[target] = "open"
                    stack.append((target, 0))
            else:
                state[node] = "done"

    forward = [
        (edge["from"], edge["to"])
        for index, edge in enumerate(edges)
        if index not in back_edges
    ]
    layer = {node: 0 for node in node_ids}
    pending = {node: 0 for node in node_ids}
    successors: dict[str, list[str]] = {node: [] for node in node_ids}
    for source, target in forward:
        pending[target] += 1
        successors[source].append(target)
    queue = [node for node in node_ids if pending[node] == 0]
    ordered: list[str] = []
    while queue:
        node = queue.pop(0)
        ordered.append(node)
        for target in successors[node]:
            layer[target] = max(layer[target], layer[node] + 1)
            pending[target] -= 1
            if pending[target] == 0:
                queue.append(target)
    if len(ordered) != len(node_ids):
        raise BriefingError("flow contains a cycle that could not be laid out")
    return layer, back_edges


def render_flow_diagram(flow: dict[str, Any]) -> str:
    nodes = flow["nodes"]
    edges = flow["edges"]
    node_ids = [node["id"] for node in nodes]
    layer, back_edges = layer_flow_nodes(node_ids, edges)

    widths = {
        node["id"]: max(NODE_MIN_WIDTH, text_width(node["label"]) + 2 * NODE_PAD_X)
        for node in nodes
    }
    rows: dict[int, list[str]] = {}
    for node_id in node_ids:
        rows.setdefault(layer[node_id], []).append(node_id)

    row_widths = {
        index: sum(widths[node] for node in row) + NODE_GAP * (len(row) - 1)
        for index, row in rows.items()
    }
    content_width = max(row_widths.values())
    # Long and backward edges bow outwards of the node columns.
    bow = 44

    position: dict[str, tuple[float, float]] = {}
    for layer_index in sorted(rows):
        cursor = (content_width - row_widths[layer_index]) / 2
        top = layer_index * (NODE_HEIGHT + LAYER_GAP)
        for node_id in rows[layer_index]:
            position[node_id] = (cursor, top)
            cursor += widths[node_id] + NODE_GAP

    parts: list[str] = []
    bounds: list[tuple[float, float, float, float]] = []
    marker = f"dg-arrow-{next(_diagram_ids)}"

    for index, edge in enumerate(edges):
        source_x, source_y = position[edge["from"]]
        target_x, target_y = position[edge["to"]]
        source_cx = source_x + widths[edge["from"]] / 2
        target_cx = target_x + widths[edge["to"]] / 2
        if index in back_edges:
            start = (source_x, source_y + NODE_HEIGHT / 2)
            end = (target_x, target_y + NODE_HEIGHT / 2)
            control_x = min(start[0], end[0]) - bow
            path = (
                f"M {start[0]:.0f} {start[1]:.0f} "
                f"C {control_x:.0f} {start[1]:.0f} {control_x:.0f} {end[1]:.0f} "
                f"{end[0]:.0f} {end[1]:.0f}"
            )
            label_x = control_x + 6
            label_y = (start[1] + end[1]) / 2
            anchor = "end"
        elif layer[edge["to"]] - layer[edge["from"]] > 1:
            start = (source_x + widths[edge["from"]], source_y + NODE_HEIGHT / 2)
            end = (target_x + widths[edge["to"]], target_y + NODE_HEIGHT / 2)
            control_x = max(start[0], end[0]) + bow
            path = (
                f"M {start[0]:.0f} {start[1]:.0f} "
                f"C {control_x:.0f} {start[1]:.0f} {control_x:.0f} {end[1]:.0f} "
                f"{end[0]:.0f} {end[1]:.0f}"
            )
            label_x = control_x - 6
            label_y = (start[1] + end[1]) / 2
            anchor = "start"
        else:
            start = (source_cx, source_y + NODE_HEIGHT)
            end = (target_cx, target_y)
            control_x = start[0]
            path = f"M {start[0]:.0f} {start[1]:.0f} L {end[0]:.0f} {end[1]:.0f}"
            label_x = (start[0] + end[0]) / 2 + 6
            label_y = (start[1] + end[1]) / 2
            anchor = "start"
        parts.append(f'<path class="dg-edge" d="{path}" marker-end="url(#{marker})" />')
        bounds.append(
            (
                min(start[0], end[0], control_x),
                min(start[1], end[1]),
                max(start[0], end[0], control_x),
                max(start[1], end[1]),
            )
        )
        if edge.get("label"):
            parts.append(
                f'<text class="dg-edge-label" x="{label_x:.0f}" y="{label_y:.0f}" '
                f'text-anchor="{anchor}">{esc(edge["label"])}</text>'
            )
            bounds.append(text_bounds(label_x, label_y, edge["label"], anchor, 11))

    for node in nodes:
        node_x, node_y = position[node["id"]]
        parts.append(
            f'<rect class="dg-node" x="{node_x:.0f}" y="{node_y:.0f}" '
            f'width="{widths[node["id"]]:.0f}" height="{NODE_HEIGHT}" rx="6" />'
            f'<text class="dg-node-label" x="{node_x + widths[node["id"]] / 2:.0f}" '
            f'y="{node_y + NODE_HEIGHT / 2:.0f}" text-anchor="middle" '
            f'dominant-baseline="central">{esc(node["label"])}</text>'
        )
        bounds.append(
            (node_x, node_y, node_x + widths[node["id"]], node_y + NODE_HEIGHT)
        )

    return svg_open(flow["title"], bounds, marker) + "".join(parts) + "</svg>"


def render_sequence_diagram(flow: dict[str, Any]) -> str:
    actors = flow["actors"]
    messages = flow["messages"]
    widths = [
        max(NODE_MIN_WIDTH, text_width(actor["label"]) + 2 * NODE_PAD_X)
        for actor in actors
    ]
    centers: list[float] = []
    cursor = 0.0
    for width in widths:
        centers.append(cursor + width / 2)
        cursor += width + ACTOR_GAP
    top = ACTOR_HEIGHT + 20
    height = top + len(messages) * MESSAGE_ROW
    index_of = {actor["id"]: index for index, actor in enumerate(actors)}

    marker = f"dg-arrow-{next(_diagram_ids)}"
    parts: list[str] = []
    bounds: list[tuple[float, float, float, float]] = []

    for index, actor in enumerate(actors):
        actor_x = centers[index] - widths[index] / 2
        parts.append(
            f'<line class="dg-lifeline" x1="{centers[index]:.0f}" '
            f'y1="{ACTOR_HEIGHT}" x2="{centers[index]:.0f}" '
            f'y2="{height:.0f}" />'
            f'<rect class="dg-node" x="{actor_x:.0f}" y="0" '
            f'width="{widths[index]:.0f}" height="{ACTOR_HEIGHT}" rx="6" />'
            f'<text class="dg-node-label" x="{centers[index]:.0f}" '
            f'y="{ACTOR_HEIGHT / 2:.0f}" text-anchor="middle" '
            f'dominant-baseline="central">{esc(actor["label"])}</text>'
        )
        bounds.append((actor_x, 0.0, actor_x + widths[index], height))

    for index, message in enumerate(messages):
        row_y = top + index * MESSAGE_ROW
        source = centers[index_of[message["from"]]]
        target = centers[index_of[message["to"]]]
        style = "dg-edge dg-return" if message.get("kind") == "return" else "dg-edge"
        if message["from"] == message["to"]:
            loop = 26.0
            path = (
                f"M {source:.0f} {row_y:.0f} L {source + loop:.0f} {row_y:.0f} "
                f"L {source + loop:.0f} {row_y + 16:.0f} L {source + 2:.0f} {row_y + 16:.0f}"
            )
            parts.append(
                f'<path class="{style}" d="{path}" fill="none" '
                f'marker-end="url(#{marker})" />'
                f'<text class="dg-edge-label" x="{source + loop + 8:.0f}" '
                f'y="{row_y + 4:.0f}" text-anchor="start">{esc(message["label"])}</text>'
            )
            bounds.append(
                text_bounds(source + loop + 8, row_y + 4, message["label"], "start", 11)
            )
            continue
        parts.append(
            f'<line class="{style}" x1="{source:.0f}" y1="{row_y:.0f}" '
            f'x2="{target:.0f}" y2="{row_y:.0f}" marker-end="url(#{marker})" />'
            f'<text class="dg-edge-label" x="{(source + target) / 2:.0f}" '
            f'y="{row_y - 8:.0f}" text-anchor="middle">{esc(message["label"])}</text>'
        )
        bounds.append(
            text_bounds((source + target) / 2, row_y - 8, message["label"], "middle", 11)
        )
    return svg_open(flow["title"], bounds, marker) + "".join(parts) + "</svg>"


def render_flows(flows: list[dict[str, Any]]) -> str:
    if not flows:
        return ""
    blocks = []
    for flow in flows:
        if flow["kind"] == "flow":
            body = f'<div class="diagram-wrap">{render_flow_diagram(flow)}</div>'
        elif flow["kind"] == "sequence":
            body = f'<div class="diagram-wrap">{render_sequence_diagram(flow)}</div>'
        elif flow["kind"] == "steps":
            steps = []
            for step in flow["steps"]:
                detail = (
                    f'<span class="step-detail">{esc(step["detail"])}</span>'
                    if step.get("detail")
                    else ""
                )
                steps.append(
                    f'<li class="step"><code>{esc(step["label"])}</code>{detail}</li>'
                )
            body = f'<ol class="steps">{"".join(steps)}</ol>'
        else:
            head = "".join(f"<th>{esc(column)}</th>" for column in flow["columns"])
            rows = "".join(
                "<tr>" + "".join(f"<td>{esc(cell)}</td>" for cell in row) + "</tr>"
                for row in flow["rows"]
            )
            body = f'<table class="grid"><thead><tr>{head}</tr></thead><tbody>{rows}</tbody></table>'
        blocks.append(f"<h3>{esc(flow['title'])}</h3>{body}")
    return "<h2>処理の流れ</h2>" + "".join(blocks)


def render_walkthrough(
    detailed: list[dict[str, Any]], stats: dict[str, FileDiff]
) -> str:
    cards = []
    for entry in detailed:
        route = entry["path"]
        stat = stats[route]
        attention = entry["attention"]
        rename = (
            f'<span class="rename">← {esc(stat.old_path)}</span>' if stat.old_path else ""
        )
        excerpts = "".join(
            render_hunk(stat.hunks[index - 1]) for index in entry.get("excerpt", [])
        )
        if excerpts:
            shown = len(entry.get("excerpt", []))
            excerpts = (
                f'<div class="excerpt-head">コード抜粋（{shown}/{len(stat.hunks)} hunk）</div>'
                + excerpts
            )
        points = "".join(f"<li>{esc(point)}</li>" for point in entry.get("review_points", []))
        points_block = (
            f"<dt>レビュー注目点</dt><dd><ul>{points}</ul></dd>" if points else ""
        )
        cards.append(
            f'<section class="card" id="{slugify(route)}">'
            f'<details {"open" if attention == "high" else ""}>'
            f'<summary><span class="badge {attention}">{ATTENTION_LABELS[attention]}</span>'
            f"<code>{esc(route)}</code>{rename}"
            f'<span class="num"><span class="add">+{stat.additions}</span> '
            f'<span class="del">-{stat.deletions}</span></span>'
            f'<span class="tag">{CATEGORY_LABELS[entry["category"]]} / {esc(stat.status)}</span>'
            f"</summary>"
            f'<dl class="kv">'
            f"<dt>役割</dt><dd>{esc(entry['role'])}</dd>"
            f"<dt>変更前 → 変更後</dt><dd>{esc(entry['change'])}</dd>"
            f"</dl>{excerpts}"
            f'<dl class="kv"><dt>影響</dt><dd>{esc(entry["impact"])}</dd>{points_block}</dl>'
            f"</details></section>"
        )
    return "<h2>ファイル別 walkthrough</h2>" + "".join(cards)


def render_contracts(contracts: list[dict[str, Any]]) -> str:
    if not contracts:
        return ""
    rows = []
    for contract in contracts:
        note = esc(contract.get("note", ""))
        rows.append(
            f"<tr><td>{esc(contract['kind'])}</td><td><code>{esc(contract['name'])}</code></td>"
            f"<td>{esc(contract['before'])}</td><td>{esc(contract['after'])}</td>"
            f"<td>{note}</td></tr>"
        )
    return (
        "<h2>公開契約の変更</h2>"
        '<table class="grid"><thead><tr><th>種別</th><th>対象</th><th>変更前</th>'
        f"<th>変更後</th><th>補足</th></tr></thead><tbody>{''.join(rows)}</tbody></table>"
    )


def render_priorities(priorities: list[dict[str, Any]]) -> str:
    if not priorities:
        return ""
    items = []
    for priority in priorities:
        route = priority["path"]
        target = priority.get("target") or route
        items.append(
            f'<li><a href="#{slugify(route)}"><code>{esc(target)}</code></a>'
            f" — {esc(priority['reason'])}</li>"
        )
    return f'<h2>レビュー時に優先して見る箇所</h2><ol class="priorities">{"".join(items)}</ol>'


def render_limits(limits: list[str]) -> str:
    if not limits:
        return ""
    items = "".join(f"<li>{esc(limit)}</li>" for limit in limits)
    return f"<h2>取得上の制約</h2><ul>{items}</ul>"


STYLE = """
:root {
  color-scheme: light dark;
  --bg: #ffffff; --fg: #1f2328; --muted: #656d76; --line: #d0d7de;
  --panel: #f6f8fa; --accent: #0969da;
  --add-bg: #e6ffec; --del-bg: #ffebe9; --hunk-bg: #ddf4ff;
  --add-fg: #1a7f37; --del-fg: #cf222e;
  --high-bg: #ffebe9; --high-fg: #cf222e;
  --medium-bg: #fff8c5; --medium-fg: #9a6700;
  --low-bg: #eaeef2; --low-fg: #656d76;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #30363d;
    --panel: #161b22; --accent: #4493f8;
    --add-bg: #12261e; --del-bg: #25171c; --hunk-bg: #121d2f;
    --add-fg: #3fb950; --del-fg: #f85149;
    --high-bg: #25171c; --high-fg: #f85149;
    --medium-bg: #272115; --medium-fg: #d29922;
    --low-bg: #21262d; --low-fg: #9198a1;
  }
}
* { box-sizing: border-box; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Noto Sans JP", sans-serif;
  font-size: 14px; line-height: 1.7;
}
main { max-width: 1080px; margin: 0 auto; padding: 24px 20px 96px; }
code, .diff { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace; }
code { font-size: 0.92em; }
h1 { font-size: 20px; margin: 0 0 6px; }
h2 { font-size: 16px; margin: 32px 0 12px; padding-bottom: 6px; border-bottom: 1px solid var(--line); }
h3 { font-size: 14px; margin: 20px 0 8px; color: var(--muted); }
a { color: var(--accent); }
.meta-line { color: var(--muted); font-size: 13px; }
.meta-line span + span::before { content: "・"; margin: 0 6px; color: var(--line); }
table { border-collapse: collapse; width: 100%; }
.map, .grid { border: 1px solid var(--line); border-radius: 6px; overflow: hidden; }
.map th, .map td, .grid th, .grid td {
  border-bottom: 1px solid var(--line); padding: 7px 10px; text-align: left; vertical-align: top;
}
.map th, .grid th { background: var(--panel); font-size: 12px; color: var(--muted); }
.map td.num, .num { white-space: nowrap; font-size: 12px; }
.add { color: var(--add-fg); }
.del { color: var(--del-fg); }
.badge {
  display: inline-block; padding: 1px 8px; border-radius: 999px;
  font-size: 11px; font-weight: 600; white-space: nowrap;
}
.badge.high { background: var(--high-bg); color: var(--high-fg); }
.badge.medium { background: var(--medium-bg); color: var(--medium-fg); }
.badge.low { background: var(--low-bg); color: var(--low-fg); }
.tag { font-size: 11px; color: var(--muted); }
.card { border: 1px solid var(--line); border-radius: 6px; margin: 10px 0; overflow: hidden; }
.card > details > summary, .listed > summary {
  cursor: pointer; padding: 10px 12px; background: var(--panel);
  display: flex; gap: 10px; align-items: center; flex-wrap: wrap;
}
.card > details > div, .card > details > dl, .card > details > table { margin: 0; }
.card .kv { padding: 4px 14px 12px; }
.rename { font-size: 12px; color: var(--muted); }
.kv { display: grid; grid-template-columns: max-content 1fr; gap: 4px 16px; margin: 12px 0; }
.kv dt { color: var(--muted); font-size: 12px; padding-top: 2px; white-space: nowrap; }
.kv dd { margin: 0; }
.kv ul, .priorities { margin: 0; padding-left: 20px; }
.excerpt-head { padding: 8px 14px 0; font-size: 12px; color: var(--muted); }
.diff {
  font-size: 12.5px; line-height: 1.5; margin: 8px 14px 4px;
  width: calc(100% - 28px); border: 1px solid var(--line); border-radius: 6px;
}
.diff td { padding: 0 8px; vertical-align: top; }
.diff td.ln {
  width: 1%; text-align: right; color: var(--muted); user-select: none;
  border-right: 1px solid var(--line); white-space: nowrap;
}
.diff td.code { white-space: pre-wrap; word-break: break-word; }
.diff tr.add { background: var(--add-bg); }
.diff tr.del { background: var(--del-bg); }
.diff tr.hunk { background: var(--hunk-bg); color: var(--muted); }
.diff tr.meta { color: var(--muted); }
.diagram-wrap { overflow-x: auto; padding: 4px 0 8px; }
.diagram { max-width: 100%; height: auto; font-size: 12px; }
.diagram .dg-node { fill: var(--panel); stroke: var(--line); }
.diagram .dg-node-label {
  fill: var(--fg);
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, monospace;
}
.diagram .dg-edge { stroke: var(--muted); stroke-width: 1.4; fill: none; }
.diagram .dg-return { stroke-dasharray: 5 4; }
.diagram .dg-head { fill: var(--muted); stroke: none; }
.diagram .dg-lifeline { stroke: var(--line); stroke-dasharray: 4 4; }
.diagram .dg-edge-label {
  fill: var(--muted); font-size: 11px;
  stroke: var(--bg); stroke-width: 3px; paint-order: stroke;
}
.steps { list-style: none; margin: 0; padding: 0; }
.step { padding: 6px 0 6px 18px; border-left: 2px solid var(--line); margin-left: 6px; position: relative; }
.step::before { content: "→"; position: absolute; left: -9px; color: var(--muted); background: var(--bg); }
.step-detail { color: var(--muted); margin-left: 8px; }
.listed { border: 1px solid var(--line); border-radius: 6px; margin: 10px 0; }
.listed ul { margin: 10px 0; padding-left: 28px; }
footer { color: var(--muted); font-size: 12px; margin-top: 40px; }
"""


def render_html(
    briefing: dict[str, Any], pr_json: dict[str, Any], files: list[FileDiff]
) -> str:
    stats = {entry.path: entry for entry in files}
    entries = briefing["files"]
    detailed = [entry for entry in entries if entry["category"] in DETAILED_CATEGORIES]
    listed = [entry for entry in entries if entry["category"] in LISTED_CATEGORIES]

    title = f"PR #{pr_json.get('number')}: {pr_json.get('title', '')}"
    author = (pr_json.get("author") or {}).get("login", "")
    state = pr_json.get("state", "")
    draft = " (draft)" if pr_json.get("isDraft") else ""
    additions = sum(entry.additions for entry in files)
    deletions = sum(entry.deletions for entry in files)

    head = (
        f"<h1>{esc(title)}</h1>"
        f'<p class="meta-line">'
        f"<span>{esc(state)}{draft}</span>"
        f"<span><code>{esc(pr_json.get('baseRefName'))}</code> ← "
        f"<code>{esc(pr_json.get('headRefName'))}</code></span>"
        f"<span>{esc(author)}</span>"
        f"<span>{len(files)} files "
        f'<span class="add">+{additions}</span> <span class="del">-{deletions}</span></span>'
        f'<span><a href="{esc(pr_json.get("url"))}">GitHub</a></span>'
        f"</p>"
    )

    body = "".join(
        [
            head,
            render_purpose(briefing["purpose"]),
            render_map(detailed, listed, stats),
            render_flows(briefing.get("flows", [])),
            render_walkthrough(detailed, stats),
            render_contracts(briefing.get("contracts", [])),
            render_priorities(briefing.get("priorities", [])),
            render_limits(briefing.get("limits", [])),
            "<footer>コード抜粋は PR の差分から機械的に転記。"
            "テスト関連ファイルは存在のみ記載し、内容は説明していない。</footer>",
        ]
    )
    return (
        "<!DOCTYPE html>\n"
        '<html lang="ja"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{esc(title)}</title><style>{STYLE}</style></head>"
        f"<body><main>{body}</main></body></html>\n"
    )


def cmd_render(args: argparse.Namespace) -> int:
    artifact_dir = Path(args.dir)
    pr_json = load_json(artifact_dir / "pr.json")
    briefing = load_json(Path(args.briefing))
    files = parse_diff((artifact_dir / "pr.diff").read_text(encoding="utf-8"))
    if not isinstance(briefing, dict):
        raise BriefingError("briefing JSON must be an object")

    validate_briefing(briefing, pr_json, files)
    output = Path(args.out)
    output.write_text(render_html(briefing, pr_json, files), encoding="utf-8")
    print(f"briefing HTML: {output}")
    print(f"files: {len(files)}, bytes: {output.stat().st_size}")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    index_parser = subparsers.add_parser("index", help="parse the diff into files.json")
    index_parser.add_argument("--diff", required=True)
    index_parser.add_argument("--pr-json", required=True)
    index_parser.add_argument("--out", required=True)
    index_parser.set_defaults(func=cmd_index)

    render_parser = subparsers.add_parser("render", help="render the briefing HTML")
    render_parser.add_argument("--dir", required=True, help="artifact dir with pr.json/pr.diff")
    render_parser.add_argument("--briefing", required=True)
    render_parser.add_argument("--out", required=True)
    render_parser.set_defaults(func=cmd_render)

    args = parser.parse_args(argv)
    try:
        return args.func(args)
    except BriefingError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
