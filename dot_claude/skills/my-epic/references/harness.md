# Verification Harness Design

A PR leaf is not ready for implementation until its harness explains how success will be measured.

## Gate categories

### Test gate

Use the narrowest automated tests that prove the leaf goal.

- Unit tests for pure logic
- Integration tests for boundary behavior
- Contract tests for public API / event / schema compatibility
- E2E tests only when cross-component behavior is the leaf goal

Every test gate needs:

- Exact command
- Expected pass condition
- Existing test files or new test file path
- Known flakes or environment requirements

### Data gate

Required when the leaf touches persistence, migrations, backfills, analytics, permissions, or generated data.

Specify one or more:

- Migration dry-run command
- Row-count or invariant query
- Before/after sample check
- Idempotency check
- Backfill checkpoint / resume check
- Data deletion or retention check

For BigQuery or expensive queries, show current project/account and run dry-run first.

### Smoke gate

Use the smallest realistic scenario that exercises the new path after local or staging startup.

Good smoke gates:

- One CLI command with expected stdout
- One HTTP request with expected status and response shape
- One UI route with exact interaction and expected visible result
- One worker/job invocation with expected log line and side effect

Avoid smoke gates that say only "check manually". If manual observation is unavoidable, define the exact screen, input, and expected result.

### Observability gate

Required when the change introduces production risk.

Specify:

- New or existing metric name
- Log event and fields
- Trace span or audit record
- Alert or dashboard to inspect

### Rollout / rollback gate

Required when rollout is not all-at-once.

Specify:

- Feature flag or config name
- Default value
- Enablement sequence
- Rollback command or revert plan
- Cleanup PR trigger

## Harness-first rule

Create a separate Harness PR before implementation when:

- The required tests do not exist and will be reused by multiple leaves
- Contract behavior is unclear
- Data validation requires reusable scripts or fixtures
- Smoke testing needs new local/staging tooling

Do not hide an absent harness by weakening the acceptance criteria.

## Ready checklist

Before implementation, each leaf must answer:

- What exact command proves the code path?
- What exact data invariant must hold?
- What exact smoke scenario proves the feature path?
- What exact files may be created, modified, tested, or must not be touched?
- What review checks prove spec compliance before code quality cleanup?
- What failure would block PR creation?
- What evidence will be pasted into the PR body?
