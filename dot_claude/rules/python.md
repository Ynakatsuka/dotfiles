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

### Using pyright-lsp

- If **pyright-lsp** is installed, use it for static code analysis.
- If **pyright-lsp** is not installed, prompt the user to install it.

### Development Environment

- The GitHub CLI is installed. For GitHub operations, use `make pr`, `make issue`, or the `gh` command.
- Pre-commit hooks plus strict guardrails such as **mypy**, **ruff**, and **pytest** are configured. Run checks and formatting frequently to guarantee code quality.
- The **Frequently Used Commands** section lists helpful `make` targets tailored for this environment—use them proactively.

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

- **Minimize `try-except` block usage:**
  - **Strictly avoid using `try-except` for flow control.** Expected alternative execution paths should be handled by conditional statements (e.g., `if/else`).
  - **Reserve `try-except` blocks for truly exceptional situations** that cannot be reliably predicted or handled by proactive conditional checks (e.g., I/O operations, third-party library errors).
  - **Always catch specific exception types.** Avoid broad `except:`, `except Exception:`, or `except BaseException:`.
  - **Consider returning error indicators** (e.g., `None`, a `Result` type) for recoverable errors instead of raising exceptions.
  - **Example of discouraged `try-except` usage (flow control):**

    ```python
    # BAD: Using try-except for checking attribute existence or type
    try:
        value = obj.attribute
        result = int(value)
    except (AttributeError, ValueError):
        result = 0
    ```

  - **Example of preferred conditional checks:**

    ```python
    # GOOD: Proactive checks
    result = 0
    if hasattr(obj, 'attribute'):
        value_str = obj.attribute
        if isinstance(value_str, str) and value_str.isdigit():
            result = int(value_str)
        elif isinstance(value_str, int):
            result = value_str
    ```

  - Actively refactor `try-except` blocks that can be replaced by conditional logic.

### Dict/Collection Access Safety

- **Always use direct key access (`dict[key]`)** to access dictionary values. Let `KeyError` be raised if the key is missing.
- **DO NOT use `.get()` with default values** to silently handle missing keys. Missing keys indicate bugs that should fail loudly.
- **Forbidden patterns:**

  ```python
  # BAD: Silently returns None or default, masking bugs
  value = data.get("key")
  value = data.get("key", "default")
  value = data.get("key", 0)
  value = data.get("key", [])

  # BAD: Using setdefault to mask missing keys
  value = data.setdefault("key", default_value)
  ```

- **Preferred patterns:**

  ```python
  # GOOD: Raises KeyError if key is missing - fails fast
  value = data["key"]

  # GOOD: Explicit check when key may legitimately be absent
  if "key" in data:
      value = data["key"]
      # process value
  else:
      # handle absence explicitly (raise error, log warning, etc.)
      raise ValueError("Required key 'key' not found in data")

  # GOOD: Using TypedDict for type safety
  class MyData(TypedDict):
      key: str
      count: int

  def process(data: MyData) -> str:
      return data["key"]  # Type checker ensures key exists
  ```

- **Exception:** `.get()` is acceptable **only** when the key is genuinely optional and the absence has a well-defined semantic meaning documented in the code.

### Quality Assurance

- **Always** use Ruff for linting and formatting code. Ensure code passes Ruff checks before considering it complete.
- Refer to the **Coding Guidelines** section for best practices.
- After coding, always run the appropriate `make` commands, e.g.
  - `uv run ruff format` – code formatting
  - `uv run ruff check` – lint check
  - `uv run mypy --strict` – strict type check
  - `uv run pytest` – run tests
- **Always write tests** after writing code to verify intended behavior.
- **Implement tests** for every new feature or bug fix.
- **Log appropriately** to aid debugging and observability.
- **Measure performance**
  - For functions that contain heavy computation, add profiling to expose potential bottlenecks.

### Implementation Approach

- **Adopt a staged implementation approach**
  1. **Interface design** – define interfaces first with `Protocol` or `ABC`.
  2. **Test first** – write tests before implementation.
  3. **Incremental implementation** – minimal implementation → refactor → optimise.
