---
name: my-repeated
description: |
  Repeatedly execute a task until a completion condition is met (iterative refinement loop).
  Use when user asks to "繰り返す", "問題なくなるまで", "until fixed", "keep fixing",
  "loop until done", "エラーがなくなるまで", "passするまで", or describes a check→fix cycle.
  Do NOT use for simple one-shot tasks or scheduled/cron-based repetition.
argument-hint: "[task description]"
---

# Iterative Refinement Loop

Execute a task repeatedly until a completion condition is satisfied.

## Phase 0: Parse and Confirm

1. Extract from user input:
   - **Task**: What to do each iteration (e.g., "run lint and fix errors", "review code and address issues")
   - **Completion condition**: When to stop (e.g., "no lint errors", "all tests pass", "no review comments")
   - **Max iterations**: Default to 10 if not specified

2. If the completion condition is ambiguous or missing, ask the user before proceeding:
   ```
   What condition should signal completion?
   Examples: "exit code 0", "no errors in output", "no issues found", "all tests pass"
   ```

3. Confirm the plan with the user:
   ```
   Loop plan:
   - Task: <task>
   - Done when: <condition>
   - Max iterations: <N>
   Proceed? (y/n)
   ```

## Phase 1: Execute Loop

For each iteration (1 to max):

### Step 1 — Execute the task
Run the task as described. This may involve:
- Running a command (lint, test, build)
- Performing a review (code review, self-review)
- Any combination of checks

### Step 2 — Evaluate completion condition
Check if the completion condition is met.
- For command-based tasks: check exit code and output
- For review-based tasks: check if there are remaining issues
- For ambiguous results: use best judgment, erring on the side of "not done"

### Step 3 — Report iteration result
Print a brief status:
```
[Iteration N/M] <status emoji> <one-line summary>
  Issues remaining: <count or description>
```

Use these status indicators:
- `PASS` — Completion condition met → go to Phase 2
- `FIXING` — Issues found, attempting fix → continue loop
- `STUCK` — Same issues persist after 2 consecutive attempts → go to Phase 2 with warning

### Step 4 — Fix issues
If not done, fix the identified issues, then return to Step 1.

**Stuck detection**: If the same issue appears in 3 consecutive iterations, stop the loop and report to the user rather than continuing indefinitely.

## Phase 2: Report

Summarize the loop execution:

```
## Loop Complete

- **Iterations**: <N>/<max>
- **Result**: <PASS | STUCK | MAX_ITERATIONS_REACHED>
- **Summary**: <what was done>

### Issues resolved
- <list of fixed issues>

### Remaining issues (if any)
- <list of unresolved issues>
```

## Rules

- NEVER skip the confirmation in Phase 0.
- NEVER exceed the max iteration count.
- If an iteration causes a regression (new issues that didn't exist before), revert the change and try a different approach.
- Between iterations, briefly note what changed to avoid repeating the same failed fix.
- If the task requires user input mid-loop (e.g., design decisions), pause and ask rather than guessing.
