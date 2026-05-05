# Python Simplification Guide

Prefer clear data flow, explicit errors, and typed boundaries.

## Good simplification targets

- Remove duplicated parsing, validation, or conversion by reusing an existing helper.
- Replace broad dictionaries with dataclasses, TypedDict, or existing domain types when the project already uses them.
- Collapse unnecessary wrapper functions that only pass through arguments.
- Replace nested conditionals with early returns when it clarifies the happy path.
- Remove unused imports, variables, fixtures, and dead branches.

## Avoid

- `except Exception: pass`, `except: pass`, or returning `None` on unexpected failure.
- `value or default` when falsy values are valid.
- Adding optional types instead of fixing the caller/callee contract.
- Hiding import or dependency failures behind fallback implementations.
- Weakening tests to match current behavior.

## Verification hints

Use the project's documented commands. Common commands are `uv run pytest`, `uv run ruff check`, `uv run mypy`, and `uv run pyright`, but do not invent them if the project does not define them.
