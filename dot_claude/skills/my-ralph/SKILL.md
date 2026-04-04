---
name: my-ralph
description: >-
  Generate Ralph Loop files (ralph-prd.json + ralph-prompt.md) for autonomous
  multi-task execution with context reset. Optionally converts SDD tasks.md.
  Use when user asks to set up Ralph Loop, create prd.json, run tasks autonomously,
  or mentions "ralph", "ラルフ", "自律実行", "寝てる間に実装".
  Do NOT use for single-task execution or iterative refinement (use my-repeated instead).
argument-hint: "[feature-name | docs/specs/path]"
---

# Ralph Loop Setup

Generate the two files needed for Ralph Loop execution: `ralph-prd.json` (task list) and `ralph-prompt.md` (agent instructions).

## Argument Routing

Route based on `$ARGUMENTS`:

1. **SDD spec path** (contains `docs/specs/`): Convert that spec's `tasks.md` → `ralph-prd.json`
2. **Feature name** (kebab-case): Look for `docs/specs/{name}/tasks.md` and convert
3. **No argument**: Scan for SDD specs or ask user for task list

## Step 1: Generate ralph-prd.json

### From SDD tasks.md

Read the SDD `tasks.md` and convert each task to a PRD story:

```json
{
  "project": "<feature-name>",
  "stories": [
    {
      "id": 1,
      "title": "Task title from tasks.md",
      "description": "Task details including file paths and specifics",
      "acceptance_criteria": ["AC from tasks.md or derived from details"],
      "priority": "high",
      "status": "pending",
      "depends_on": []
    }
  ]
}
```

Mapping rules:
- SDD `[x]` tasks → `"status": "done"` (skip these)
- SDD `[ ]` tasks → `"status": "pending"`
- SDD `[P]` parallel markers → note in description but keep `depends_on` empty
- SDD dependency info → populate `depends_on` with story IDs
- Test tasks come before their implementation tasks (preserve SDD ordering)

### From scratch (no SDD)

Ask the user what they want to build, then generate stories following the same schema. Each story must have:
- Clear, verb-first title
- Specific description with file paths where possible
- Objectively verifiable acceptance criteria
- Realistic dependency ordering

### PRD Quality Rules

- **Atomic tasks**: One clear deliverable per story
- **Verifiable criteria**: Each acceptance criterion must be checkable by running a command (test, lint, type-check) or reading a file
- **No ambiguity**: Include file paths, function names, expected behavior
- **Test-first ordering**: Test stories before implementation stories

## Step 2: Generate ralph-prompt.md

Generate a prompt file tailored to the current project. Use this template, filling in project-specific sections:

```markdown
# Ralph Loop Agent Instructions

You are an autonomous agent executing one task per session. Your context is fresh each time.

## Workflow

1. Read `ralph-prd.json` and `ralph-progress.md`
2. Pick the first story with `"status": "pending"` whose dependencies are all `"done"`
3. Update its status to `"in_progress"` in `ralph-prd.json`
4. Implement the task:
   - Read relevant existing code first
   - Write code following existing patterns
   - Run validation (tests, lint, type-check)
5. On success:
   - Update story status to `"done"` in `ralph-prd.json`
   - Append a brief entry to `ralph-progress.md` (what was done, key decisions)
   - Commit changes: `git add -A && git commit -m "<conventional commit message>"`
6. On failure:
   - Record the blocker in `ralph-progress.md`
   - Update story status to `"blocked"` with a `"blocker"` field in `ralph-prd.json`
   - Skip to next available task if possible
7. If ALL stories are `"done"`, output exactly: RALPH_COMPLETE

## Project Context

<PROJECT_CONTEXT>

## Validation Commands

<VALIDATION_COMMANDS>

## Rules

- Do exactly ONE task per session, then exit
- Never modify completed tasks' code unless fixing a regression
- If a test you wrote passes trivially (no real assertions), rewrite it
- If stuck for more than 3 attempts on the same error, mark as blocked and move on
- Keep commits atomic: one commit per task
- Write all code comments in English
```

Fill in `<PROJECT_CONTEXT>` by reading:
- The project's `CLAUDE.md` or `AGENTS.md` (summarize key conventions)
- Package manager and language (from `package.json`, `Cargo.toml`, `pyproject.toml`, etc.)
- Test framework and how to run tests
- Lint/format commands

Fill in `<VALIDATION_COMMANDS>` with the project's actual commands (e.g., `npm test`, `pytest`, `cargo test`, `ruff check`).

## Step 3: Report

After generating both files, display:

```
ralph-prd.json: <N> tasks (<M> pending, <K> done)
ralph-prompt.md: generated

Run the loop:
  ~/.claude/skills/my-ralph/scripts/ralph.sh [MAX_ITERATIONS]

Useful options:
  ralph.sh 10          # Limit to 10 iterations
  ralph.sh 20 claude   # Use claude CLI (default)
```

## Safety Notes

Warn the user about these before they run:
- Review `ralph-prd.json` tasks and acceptance criteria before starting
- Review `ralph-prompt.md` to ensure validation commands are correct
- Run in a feature branch, not main
- Monitor the first 2-3 iterations before leaving unattended
- `ralph-progress.md` contamination: if wrong learnings get recorded, later iterations inherit them
