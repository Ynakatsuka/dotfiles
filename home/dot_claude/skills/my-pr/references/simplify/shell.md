# Shell Simplification Guide

Prefer predictable failure, quoting, and small linear scripts.

## Good simplification targets

- Quote variable expansions unless intentional word splitting is required and documented.
- Replace repeated command sequences with a function only when the function name captures intent.
- Remove temporary files safely by keeping creation and cleanup in the same script scope.
- Replace nested conditionals with clear guard clauses.
- Remove unused variables and duplicated command invocations.

## Avoid

- `|| true` unless the command is explicitly allowed to fail and the failure is inspected immediately.
- Swallowing stderr without reporting the failure path.
- Guessing alternate paths or commands when the intended command is missing.
- Unbounded retries or sleeps.
- Broad glob deletion.

## Verification hints

Use documented project commands. If shellcheck is configured, run it on changed shell files. Do not add shellcheck as a new dependency during simplification.
