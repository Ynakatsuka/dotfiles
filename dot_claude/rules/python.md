---
paths: **/*.py
---

When applying this rule, prefix your response with the 🐍 emoji.

## Python

### Using uv

- **Always use uv** for Python projects unless otherwise specified.
- Execute Python scripts **only** using `uv run python`.
- Manage dependencies **strictly** using `uv add` or by directly editing `pyproject.toml`. **NEVER use `uv pip install` or `pip install` directly.**
- Prefix every Python command with `uv run`, and add new dependencies with `uv add`.

### Exploratory Debugging

- Run temporary code snippets with `uv run python -c "..."`.
- To temporarily install and test a library not in the project dependencies, use `uv run --with <library> python -c "..."`.

### Standards & Libraries

- Adhere to modern Python standards (Python 3.10+):
  - **Use modern type annotations:** `|` for Union types, `list[str]`, `dict[str, int]`, etc.
  - **DO NOT USE legacy typing:** `typing.List[]`, `typing.Dict[]`, `typing.Union[]`, etc. are **forbidden**.
  - Use Google Style docstrings. **Docstrings MUST be in English.**
  - Use Pytest for writing and running tests.
  - Use `argparse` and `dataclasses` for command-line entrypoints.
- **All** docstrings, code comments, `print()` statements, and logging messages **MUST be written in English.** No exceptions.
- **Strongly prefer** using `polars` (v1.0.0+) over `pandas`. Minimize the use of `map_elements` in Polars; favor built-in expressions for performance.

### Exception Handling

- **Never use `try-except` for flow control.** Use conditional checks (`if/else`) for expected alternative paths.
- **Reserve `try-except` for truly exceptional situations** (I/O, third-party library errors).
- **Always catch specific exception types.** Never use bare `except:`, `except Exception:`, or `except BaseException:`.
- **Consider returning `None` or a `Result` type** for recoverable errors instead of raising exceptions.

### Dict/Collection Access Safety

- **Always use direct key access (`dict[key]`).** Let `KeyError` be raised if the key is missing — missing keys are bugs that should fail loudly.
- **Do NOT use `.get()` with default values** to silently swallow missing keys. `.get()` is only acceptable when the key is genuinely optional with documented semantic meaning.
- **Prefer `TypedDict`** for structured data — the type checker enforces key existence at compile time.

### Quality Assurance

- **Always** use Ruff for linting and formatting. Run checks before considering code complete:
  - `uv run ruff format` / `uv run ruff check` / `uv run mypy --strict` / `uv run pytest`
- Implement tests for every new feature or bug fix.

### Implementation Approach

- **Strictly follow TDD (Test-Driven Development):**
  1. **Interface design** – define interfaces first with `Protocol` or `ABC`.
  2. **Write tests first** – tests define the expected behavior and edge cases.
  3. **Implement** – minimal code to make tests pass.
  4. **Refactor** – improve code while ensuring all tests continue to pass.
