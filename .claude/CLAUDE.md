## General Guidelines

- Refer to `README.md` for execution instructions.
- Provide accurate, factual, and thoughtful answers with step-by-step reasoning.
- Maintain concise detail and use examples to clarify concepts.
- Ensure neutrality and balanced perspectives.
- Clearly communicate any limitations in responses.
- Simplify complex concepts using analogies.
- Never delete files or folders that are not tracked by Git.
- **Responses MUST be in Japanese.**
- **However, code comments, docstrings, commit messages, and README.md MUST be written in English.** This is a strict requirement.

## Coding

- Think hard when planning or writing code.
- **Core Principles:**
    - **DRY (Don't Repeat Yourself):** Avoid code duplication by abstracting common functionality into reusable components.
    - **KISS (Keep It Simple, Stupid):** Prioritize simplicity over complexity. Write code that is easy to understand and maintain.
    - **SSOT (Single Source of Truth):** Ensure that every piece of knowledge has a single, authoritative representation within the system.
    - **SRP (Single Responsibility Principle):** Each class or function should have only one reason to change and should handle only one responsibility.
- **Documentation Guidelines:**
    - **Code:** Write *how* - focus on the implementation details and technical mechanisms.
    - **Test code:** Write *what* - clearly define the expected behavior and outcomes.
    - **Commit logs:** Write *why* - explain the reasoning and motivation behind the changes.
    - **Code comments:** Write *why not* - explain alternative approaches that were considered but not chosen, or limitations of the current implementation.
- Follow existing coding style:
    - When implementing a new feature, always check whether there is an existing feature in the codebase with a similar mechanism, and use it as a reference to implement the new feature in a similar manner.
- Functional Programming:
    - Prefer Pure Functions: Always write functions that, given the same inputs, return the same outputs and do not modify external state.
    - Use Immutable Data Structures: Represent state with immutable types (e.g., tuples, `frozen=True` dataclasses) and return new instances rather than mutating.
    - Isolate Side Effects: Separate I/O, logging, database access, and other side effects into dedicated modules or functions. Business logic functions must remain pure.
    - Ensure Type Safety: Include explicit type annotations for all function signatures, using typing primitives (`List`, `Dict`, `TypedDict`, `Generic`, etc.). Tools like mypy should report no errors.
- **Strictly follow Test-Driven Development (TDD):**
    1. Write tests **first**. These tests define the expected behavior.
    2. Clearly define behavior and edge cases within the tests.
    3. Implement the feature to make the tests pass.
    4. Refactor the code, ensuring **all tests continue to pass**. Maintain complete test coverage.
- Apply Domain-Driven Design (DDD) principles where applicable:
    - Differentiate Value Objects from Entities.
    - Maintain consistency within Aggregates.
    - Abstract data access via Repositories.
    - Respect Bounded Contexts.
- Finalize process before actual output:
    - Remove all descriptive comments from the generated code.

## Agent Mode

- Iteratively explore and modify the codebase. **Always** start by identifying necessary changes and tracing dependencies **before** writing any code.
- For new features, **you MUST** use a bullet-point task list to track progress. Update the progress marker (`[ ]` to `[✅]`) as each task is completed.
    ```
    Task Progress: 1/3
    [✅] Task 1
    [ ] Task 2
    [ ] Task 3
    ```
- The `z/` directory is a sandbox that the Agent can use freely. For complex implementations, you must first create an implementation plan in `plan.md` and manage its progress.
- For routine implementation tasks, create a playbook upon completion and request a review.
- **Always apply the Python section guidelines** (environment usage, code-quality tools, testing, logging, performance benchmarking) to all code you touch during agent operations.
- **Staged implementation workflow**
    1. **Interface design** with Protocols or ABCs.  
    2. **Write tests first** to express the desired behaviour.  
    3. **Iterative delivery** – minimal viable code, followed by refactor and optimisation, ensuring tests remain green at each step.  

## BigQuery

- Interact with BigQuery **exclusively** via the `bq` command-line tool.
- **Always** explicitly display the current settings (`project_id`, `account address`) **before** executing any query.
- **Mandatory:** Perform a dry run (`--dry_run`) and seek user confirmation **if** a query is estimated to scan over 50GB of data.
- For exploratory analyses, **strongly prefer** using `TABLESAMPLE SYSTEM (1 PERCENT)` to limit costs and query time, unless full data scanning is explicitly required and approved.

### SQL Writing Principles

- **Use Common Table Expressions (CTEs):**
    - Do not use subqueries. Structure your query with CTEs.
- **Name Initial CTEs `import_{dataset_name}_{table_name}`:**
    - The first CTEs that select from a source table should be named using this convention.
    - **Constraints:**
        - (Must) Each `import_` CTE must reference only a single source table.
        - (Should) Avoid including complex logic in these CTEs. They are for importing raw data.
- **Name Transformation CTEs `logic_{purpose}`:**
    - CTEs that perform `JOIN`s, aggregations, or other transformations should be named with a `logic_` prefix.
    - These CTEs must only reference `import_` CTEs or other `logic_` CTEs.
- **Name the Final CTE `final`:**
    - The last CTE in the query, representing the final dataset, must be named `final`.
    - The final statement of the query must be `SELECT * FROM final;`.
- **Use Japanese for SQL Comments:**
    - Add comments within the SQL query to explain the "why" behind specific logic or transformations. Note: This is a specific exception to the general rule that all code comments must be in English. SQL comments MUST be in Japanese.
- **Casing Convention:**
    - Use `UPPERCASE` for SQL reserved keywords (e.g., `SELECT`, `FROM`, `WITH`).
    - Use `lowercase` for table names, column names, and CTE names.

## Python

- Execute Python scripts **only** using `uv run python` or `rye run python`.
- Manage dependencies **strictly** using `uv add` or by directly editing `pyproject.toml`. **NEVER use `uv pip install` or `pip install` directly.**
- Adhere to modern Python standards (Python 3.10+):
    - **Use modern type annotations:** `|` for Union types, `list[str]`, `dict[str, int]`, etc.
    - **DO NOT USE legacy typing:** `typing.List[]`, `typing.Dict[]`, `typing.Union[]`, etc. are **forbidden**.
    - Use Google Style docstrings. **Docstrings MUST be in English.**
    - Use Pytest for writing and running tests.
    - Use `argparse` and `dataclasses` for command-line entrypoints.
- **All** docstrings, code comments, `print()` statements, and logging messages **MUST be written in English.** No exceptions.
- **Strongly prefer** using `polars` (v1.0.0+) over `pandas`. Minimize the use of `map_elements` in Polars; favor built-in expressions for performance.
- **Always** use Ruff for linting and formatting code. Ensure code passes Ruff checks before considering it complete.
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
- **Verify and leverage the development environment**
  - The project is managed with **uv**. Prefix every Python command with `uv run`, and add new dependencies with `uv add`.
  - The GitHub CLI is installed. For GitHub operations, use `make pr`, `make issue`, or the `gh` command.
  - Pre-commit hooks plus strict guardrails such as **mypy**, **ruff**, and **pytest** are configured. Run checks and formatting frequently to guarantee code quality.
  - The **Frequently Used Commands** section lists helpful `make` targets tailored for this environment—use them proactively.
- **Guarantee code quality**
  - Refer to the **Coding Guidelines** section for best practices.
  - After coding, always run the appropriate `make` commands, e.g.  
    - `uv run ruff format` – code formatting  
    - `uv run ruff check` – lint check  
    - `uv run mypy --strict` – strict type check  
    - `uv run pytest` – run tests  
- **Implement tests** for every new feature or bug fix.
- **Log appropriately** to aid debugging and observability.
- **Measure performance**
  - For functions that contain heavy computation, add profiling to expose potential bottlenecks.
- **Adopt a staged implementation approach**
  1. **Interface design** – define interfaces first with `Protocol` or `ABC`.  
  2. **Test first** – write tests before implementation.  
  3. **Incremental implementation** – minimal implementation → refactor → optimise. 

## GitHub

- Use the `gh` command-line tool for **all** GitHub operations: cloning, branching, committing, creating pull requests, etc.
- Follow standard conventional commit message guidelines (see Git Workflow section). Branch names should be descriptive (e.g., `feat/add-user-auth`, `fix/resolve-login-bug`).
- Keep local and remote repositories synchronized frequently.

## Git Workflow

### Committing Changes

1.  **Inspect changes thoroughly before committing:**
    ```bash
    git status
    git diff # Review unstaged changes
    git diff --staged # Review staged changes
    git log --oneline --graph # Review recent history
    ```
2.  **Analyze changes:**
    - Identify modified or added files.
    - Understand the nature of the change (feature, bug fix, refactor, etc.).
    - Evaluate the impact on the project.
    - **Crucially:** Check for any accidentally included sensitive information or credentials.
3.  **Write clear, concise, and informative commit messages in English.**
    - **The commit message title MUST follow the Conventional Commits format.**
    - Examples:
        ```markdown
        - feat: Introduce Result type for robust error handling
        - update: Improve caching performance by using Redis
        - fix: Correct handling of expired authentication tokens
        - refactor: Abstract external API dependencies using Adapter pattern
        - test: Add comprehensive unit tests for Result type error cases
        - docs: Update README with error handling best practices
        ```

### Creating Pull Requests

1.  **Before creating a PR, check the status of your branch:**
    ```bash
    git status
    git log main..HEAD # See commits unique to your branch
    git diff main...HEAD # See cumulative changes compared to main
    ```
2.  **Analyze the commits** and their overall impact. Ensure commits are logical and atomic.
3.  **Create the pull request** using the `gh pr create` command.

### Important Reminders (Strict Rules)

- Commit **only** relevant files related to the change. Avoid committing unrelated files, IDE configuration, or empty commits.
- Use `git commit -am` (stage and commit in one step) **only** when you are certain **all** modified files should be included in the commit. Be cautious.
- **Always** use the `-u` flag when pushing a new branch (`git push -u origin <branch-name>`).
- **Do not** use interactive rebase (`git rebase -i`) or force push (`git push --force`) unless explicitly instructed and fully understanding the consequences.
- **Do not** alter global or local Git configuration files (`.gitconfig`, `.git/config`) unless specifically required for a setup task.

### Pull Request Template (Use this Japanese template for the PR description)

```markdown
## 概要
ここにPRの目的を簡潔に記述してください。(例: TypeScriptのエラー処理を型安全にするため、Result型を導入)

## 変更内容
- 具体的な変更点をリストアップしてください。
- (例: `neverthrow` ライブラリを導入)
- (例: 既存のAPIクライアントの実装をResult型を使用するように修正)
- (例: エラーケースに対応する型定義を追加)
- (例: 関連するユニットテストケースを追加・修正)

## 技術的な詳細 (任意)
- 実装に関する技術的な判断や設計について説明が必要な場合に記述してください。
- (例: 全てのエラーパスで例外を投げずにResult型で返すように統一)
- (例: エラーの種類を判別するための共通エラー型を定義)
- (例: テストのモックを改善し、より現実に近い振る舞いをシミュレート)

## レビューのポイント
- レビュワーに特に見てほしい点や懸念点を記述してください。
- (例: Result型の使用方法が適切か)
- (例: エラーハンドリングのパターンが他の箇所と一貫しているか)
- (例: テストケースがエッジケースをカバーできているか)

## 関連Issue (あれば)
- (例: #123)

## その他 (あれば)
- スクリーンショットや補足情報など。
```
