---
name: refactor-task
description: Safe code refactoring with mandatory regression testing. Use when restructuring, reorganizing, or improving code quality without changing external behavior. Triggers on requests like "refactor this code", "extract this function", "split this class", "reorganize this module", or general code improvement tasks. Ensures behavioral equivalence through comprehensive test execution before and after changes.
---

# Refactor Task

Execute code refactoring while guaranteeing behavioral equivalence through regression testing.

## Core Principle

**Refactoring must not change external behavior.** Every refactoring session follows this invariant:

```
Tests PASS (before) → Refactor → Tests PASS (after)
```

If tests fail after refactoring, the refactoring introduced a bug—revert or fix immediately.

## Workflow

### 0. Create Worktree Branch (MANDATORY)

**Always create a new branch using git worktree before starting any refactoring.**

```bash
# Create worktree with new branch
git worktree add ../repo-refactor-feature refactor/feature-name

# Move to worktree directory
cd ../repo-refactor-feature
```

Benefits:
- Isolate refactoring changes from main working directory
- Easy to discard if refactoring goes wrong
- Can compare original and refactored code side by side
- Main branch remains untouched until PR is merged

### 1. Pre-flight Check

Before any code changes:

1. **Identify test scope**: Find tests covering the code to be refactored
2. **Run baseline tests**: Execute relevant tests and confirm they pass
3. **Record baseline**: Note test count and execution time for comparison

```bash
# Example: Run tests for specific module
uv run pytest path/to/tests/ -v

# Example: Run tests matching pattern
uv run pytest -k "test_module_name" -v
```

**STOP if baseline tests fail.** Fix failing tests first before refactoring.

### 2. Scope Analysis

Understand the refactoring scope:

1. **Identify dependencies**: What code depends on the target?
2. **Identify dependents**: What does the target depend on?
3. **Map public interface**: What is the external contract that must be preserved?

Key questions:
- Which functions/methods are called externally?
- Which return types must remain unchanged?
- Which side effects are expected behavior?

### 3. Incremental Refactoring

Apply changes in small, testable increments:

1. **Make one logical change** (extract function, rename variable, etc.)
2. **Run tests immediately**
3. **Commit if tests pass** (or note the successful state)
4. **Repeat**

**Never batch multiple unrelated changes.** If tests fail, you must know exactly which change caused it.

### 4. Post-refactoring Verification

After completing all changes:

1. **Run full test suite** for affected modules
2. **Compare with baseline**: Same test count, all passing
3. **Run linter and type checker**: Ensure no new issues

```bash
# Full verification sequence
uv run pytest path/to/tests/ -v
uv run ruff check path/to/code/
uv run mypy path/to/code/
```

### 5. Cleanup Worktree

After PR is merged or refactoring is abandoned:

```bash
# Return to main working directory
cd ../repo

# Remove worktree
git worktree remove ../repo-refactor-feature

# If branch was not merged and should be deleted
git branch -D refactor/feature-name
```

## Common Refactoring Patterns

### Extract Function/Method

**When**: Code block is reused or too long

```python
# Before
def process_data(data):
    # validation logic (10+ lines)
    if not data:
        raise ValueError("Empty data")
    if not isinstance(data, list):
        raise TypeError("Expected list")
    # ... more validation

    # processing logic
    result = transform(data)
    return result

# After
def _validate_data(data):
    """Validate input data format."""
    if not data:
        raise ValueError("Empty data")
    if not isinstance(data, list):
        raise TypeError("Expected list")
    # ... more validation

def process_data(data):
    _validate_data(data)
    result = transform(data)
    return result
```

### Extract Class

**When**: A class has multiple responsibilities

1. Identify cohesive groups of methods and attributes
2. Create new class with extracted members
3. Delegate from original class to new class
4. Update tests to cover both classes

### Inline Function

**When**: Function body is as clear as its name

Only inline if:
- Function is called from few places
- Function name adds no clarity
- Tests still cover the inlined code path

### Replace Conditional with Polymorphism

**When**: Switch/if-else on type drives behavior

1. Create base class/protocol
2. Create subclass for each branch
3. Move branch logic to subclass method
4. Replace conditional with method call

## Test Coverage Strategies

### When Tests Are Missing

If the code lacks tests:

1. **Write characterization tests first**: Capture current behavior
2. **Test public interface**: Focus on inputs/outputs
3. **Test edge cases**: Boundaries, empty inputs, errors
4. **Then refactor**: With safety net in place

```python
# Characterization test example
def test_legacy_function_current_behavior():
    """Capture current behavior before refactoring."""
    # Document what the function currently does
    assert legacy_function([1, 2, 3]) == [2, 4, 6]
    assert legacy_function([]) == []
    assert legacy_function(None) is None  # Even if this seems wrong
```

### Test Granularity

- **Unit tests**: For individual functions/methods
- **Integration tests**: For module interactions
- **Run both**: Unit tests for fast feedback, integration for confidence

## Red Flags

Stop and reconsider if:

- **Tests start failing**: Revert last change, investigate
- **Changing test assertions**: You might be changing behavior, not refactoring
- **Adding new public methods**: Ensure they're necessary
- **Removing test coverage**: Never reduce coverage during refactoring
- **Refactoring and adding features simultaneously**: Do one at a time

## Checklist

Before starting:
- [ ] Worktree branch created
- [ ] Baseline tests pass
- [ ] Test coverage is adequate (add tests if needed)
- [ ] Scope is clearly defined

During refactoring:
- [ ] Making incremental changes
- [ ] Running tests after each change
- [ ] Not changing external behavior

After completing:
- [ ] All tests pass
- [ ] Linter passes
- [ ] Type checker passes
- [ ] Test count unchanged or increased
- [ ] Worktree cleaned up after merge
