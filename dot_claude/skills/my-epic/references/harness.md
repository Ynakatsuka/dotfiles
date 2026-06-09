# Verification Harness Design

A PR leaf is not ready for implementation until its harness explains how success will be measured. An operation node is not ready for execution until its runbook explains what will be run, where it will run, what evidence proves success, and how to abort or roll back.

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

### Operational execution gate

Required for migration, backfill, initial script execution, feature flag changes, external console work, cleanup, and other operation nodes.

Specify:

- Exact command or manual action
- Target environment, account, project, region, tenant, or service
- Executor / owner
- Required credentials or permissions
- Preconditions and dependency nodes
- Dry-run, preview, backup, or snapshot step when relevant
- Expected evidence: output, log line, row count, dashboard, metric, trace, or audit record
- Abort condition
- Rollback command or manual recovery action
- Irreversible effects

Do not replace an operation gate with "run manually". If manual execution is necessary, define the exact screen, field, value, action, and expected evidence.

## Harness-first rule

Create a separate Harness PR before implementation when:

- The required tests do not exist and will be reused by multiple leaves
- Contract behavior is unclear
- Data validation requires reusable scripts or fixtures
- Smoke testing needs new local/staging tooling

Do not hide an absent harness by weakening the acceptance criteria.

## PR leaf ready checklist

Before implementation, each leaf must answer:

- What exact command proves the code path?
- What exact data invariant must hold?
- What exact smoke scenario proves the feature path?
- What exact files may be created, modified, tested, or must not be touched?
- What review checks prove spec compliance before code quality cleanup?
- What failure would block PR creation?
- What evidence will be pasted into the PR body?

## Operation node ready checklist

Before execution, each operation node must answer:

- What exact command or manual action will run?
- Which environment, account, project, region, tenant, or service will it touch?
- Who owns execution and approval?
- Which dependency PR leaves or operation nodes must be complete?
- What dry-run, preview, backup, or snapshot proves readiness?
- What output, data invariant, log, metric, trace, dashboard, or audit record proves success?
- What condition triggers abort or rollback?
- What rollback or recovery action is available?
- What evidence will be recorded in the operation file?
