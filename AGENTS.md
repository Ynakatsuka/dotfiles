# Rules

See `~/.claude/rules/` for detailed rules:

- `~/.claude/rules/bigquery.md` - BigQuery and SQL guidelines
- `~/.claude/rules/python.md` - Python development standards
- `~/.claude/rules/gpu.md` - GPU usage for Python scripts
- `~/.claude/rules/git.md` - Git and GitHub workflow

## General Guidelines

- **Responses MUST be in Japanese.**
- Refer to `README.md` for execution instructions.
- Provide accurate, factual, and thoughtful answers with step-by-step reasoning.
- Maintain concise detail and use examples to clarify concepts.
- Ensure neutrality and balanced perspectives.
- Clearly communicate any limitations in responses.
- Simplify complex concepts using analogies.
- Never delete files or folders that are not tracked by Git.
- **However, code comments, docstrings, commit messages, and README.md MUST be written in English.** This is a strict requirement.
- **Never make commits automatically without explicit user approval.**

## User Interaction Guidelines

### When to Use AskUserQuestion

Use the `AskUserQuestion` tool proactively in the following situations:

1. **Ambiguous Instructions**: When the user's intent or requirements are unclear
   - Vague task descriptions without specific details
   - Instructions that could be interpreted in multiple ways
   - Missing context that is essential for correct implementation

2. **Multiple Valid Approaches**: When there are several reasonable ways to accomplish a task
   - Different architectural patterns or design choices
   - Trade-offs between performance, maintainability, and simplicity
   - Technology or library selection decisions

### Consolidate Questions

**Always batch related questions together** to minimize back-and-forth:

- At the **start of a task**, gather all necessary information upfront
- Use a **single AskUserQuestion call with multiple questions** (up to 4) instead of asking one at a time
- Group questions by topic or decision area

### When NOT to Use AskUserQuestion

- When the user has given explicit, detailed instructions
- When there is only one reasonable approach
- When the decision is trivial or easily reversible
- When you can make a sensible default choice and note it in your response

## Error Handling Principles

- **Never implement automatic fallbacks without explicit user approval.**
- **Always seek user confirmation before proceeding with alternative approaches** when encountering errors or unexpected situations.
- **Clearly communicate the nature of errors** and provide specific details about what went wrong.
- **Present available options to the user** rather than making assumptions about the desired course of action.
- **Fail safely and predictably** - when in doubt, stop and ask for guidance rather than guessing the user's intent.
- **Document all error scenarios** and their corresponding user confirmation requirements.

## Coding

- Think hard when planning or writing code.

### Core Principles

- **DRY (Don't Repeat Yourself):** Avoid code duplication by abstracting common functionality into reusable components.
- **KISS (Keep It Simple, Stupid):** Prioritize simplicity over complexity. Write code that is easy to understand and maintain.
- **SSOT (Single Source of Truth):** Ensure that every piece of knowledge has a single, authoritative representation within the system.
- **SRP (Single Responsibility Principle):** Each class or function should have only one reason to change and should handle only one responsibility.

### Documentation Guidelines

- **Code:** Write *how* - focus on the implementation details and technical mechanisms.
- **Test code:** Write *what* - clearly define the expected behavior and outcomes.
- **Commit logs:** Write *why* - explain the reasoning and motivation behind the changes.
- **Code comments:** Write *why not* - explain alternative approaches that were considered but not chosen, or limitations of the current implementation.

### Coding Style & Practices

- Follow existing coding style:
  - When implementing a new feature, always check whether there is an existing feature in the codebase with a similar mechanism, and use it as a reference to implement the new feature in a similar manner.
- Functional Programming:
  - Prefer Pure Functions: Always write functions that, given the same inputs, return the same outputs and do not modify external state.
  - Use Immutable Data Structures: Represent state with immutable types (e.g., tuples, `frozen=True` dataclasses) and return new instances rather than mutating.
  - Isolate Side Effects: Separate I/O, logging, database access, and other side effects into dedicated modules or functions. Business logic functions must remain pure.
  - Ensure Type Safety: Include explicit type annotations for all function signatures, using typing primitives (`List`, `Dict`, `TypedDict`, `Generic`, etc.). Tools like mypy should report no errors.

### Development Methodologies

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

### Implementation Guidelines

- Finalize process before actual output:
  - Remove all descriptive comments from the generated code.
- If an edited file differs from the last loaded version, it means the user has manually edited it. Unless there are explicit instructions from the user, always treat the manually edited file as the correct version and do not roll it back.

## Parallel Task Execution

Use subagents (Task tool) to execute independent tasks in parallel for maximum efficiency.

### When to Parallelize

- **Independent file operations**: Different files with no dependencies
- **Implementation + Tests**: Write implementation while subagent creates test skeleton
- **Multiple components**: Separate modules or features that don't share state
- **Verification tasks**: Linting, type checking, and test runs in background

### Parallel Patterns

**Pattern 1: Implementation + Test (TDD Hybrid)**
```
Main Agent     → Implement feature in src/feature.py
Subagent 1     → Create test file structure in tests/test_feature.py
```

**Pattern 2: Multi-Component Development**
```
Main Agent     → Component A (e.g., API handler)
Subagent 1     → Component B (e.g., Data model)
Subagent 2     → Component C (e.g., CLI interface)
```

**Pattern 3: Background Verification**
```
Main Agent     → Continue with next task
Subagent (bg)  → Run test suite
Subagent (bg)  → Run linter and type checker
```

**Pattern 4: Research + Implementation**
```
Main Agent     → Implement based on current understanding
Subagent 1     → Research edge cases or best practices
```

### Subagent Launch Guidelines

1. **Use `run_in_background: true`** for long-running tasks (tests, builds)
2. **Provide clear, self-contained instructions** - subagents don't share context
3. **Specify expected outputs** - what files to create/modify, what to report
4. **Set constraints** - files NOT to modify, patterns to follow

### Example: Parallel Feature Implementation

```
Task: Implement user authentication feature

1. Launch in parallel:
   - Main: Implement auth service in src/auth/service.py
   - Subagent 1: Create test file tests/test_auth_service.py with test cases
   - Subagent 2: Create auth types in src/auth/types.py

2. After parallel completion:
   - Main: Integrate components and run tests
   - Subagent (bg): Run full test suite

3. Continue to next task while tests run in background
```

### Anti-Patterns (Avoid)

- **Parallel edits to the same file** - causes conflicts
- **Dependent tasks in parallel** - one needs output from another
- **Too many subagents** - overhead exceeds benefit (max 3-4 concurrent)
- **Vague subagent instructions** - leads to incorrect implementations
