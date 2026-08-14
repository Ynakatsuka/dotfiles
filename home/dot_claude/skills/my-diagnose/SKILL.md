---
name: my-diagnose
description: >-
  Disciplined diagnosis workflow for hard, intermittent, or multi-component bugs and
  performance regressions: inspect logs and existing evidence, build a feedback loop,
  test falsifiable hypotheses, instrument gaps, and verify the outcome. Use when the
  root cause is unclear, reproduction is unreliable, several causes or components are
  plausible, or performance has regressed. Do NOT use for obvious single-cause errors,
  straightforward configuration or syntax fixes, planned feature work, or broad
  architecture review. Diagnosis-only requests stop after reporting the root cause and
  evidence; apply a fix only when the user requested one.
license: MIT
---

> Adapted from mattpocock/skills (https://github.com/mattpocock/skills), commit aaf2453.

# Diagnose

A discipline for hard bugs. Skip phases only when explicitly justified.

Before starting, distinguish a diagnosis-only request from a request to diagnose and fix.
A diagnosis request does not authorize product-code changes.

When exploring the codebase, use the project's domain glossary to get a clear mental model of the relevant modules, and check ADRs in the area you're touching.

## Phase 0 — Inspect existing evidence

**Do not skip available logs.** Read existing evidence before building hypotheses or adding instrumentation.

1. Capture the exact symptom and relevant time window. Record the command, request ID, trace ID, environment, input, expected result, and actual result when available.
2. Locate likely log sources from project configuration, runbooks, and execution commands when the user did not provide a path. Inspect the relevant evidence with bounded queries: user-provided output, test or CLI stdout/stderr, application logs, service or container logs, system logs, CI logs, and browser console or network traces as applicable.
3. Correlate events across sources by timestamp or identifier. Preserve exact error text before summarising it.
4. State which log sources and time ranges were checked. A search miss is not evidence that no logs exist.
5. If a relevant log is inaccessible, name the exact source, artifact, or access needed. Do not claim that logs are absent without checking.

Do not add temporary production instrumentation without explicit permission.

## Phase 1 — Build a feedback loop

Build a fast, deterministic, agent-runnable pass/fail signal before testing causes. Bisection, hypothesis testing, and instrumentation all depend on this signal.

### Ways to construct one — try them in roughly this order

1. **Failing test** at whatever seam reaches the bug — unit, integration, e2e.
2. **Curl / HTTP script** against a running dev server.
3. **CLI invocation** with a fixture input, diffing stdout against a known-good snapshot.
4. **Headless browser script** (Playwright / Puppeteer) — drives the UI, asserts on DOM/console/network.
5. **Replay a captured trace.** Save a real network request / payload / event log to disk; replay it through the code path in isolation.
6. **Throwaway harness.** Spin up a minimal subset of the system (one service, mocked deps) that exercises the bug code path with a single function call.
7. **Property / fuzz loop.** If the bug is "sometimes wrong output", run 1000 random inputs and look for the failure mode.
8. **Bisection harness.** If the bug appeared between two known states (commit, dataset, version), automate "boot at state X, check, repeat" so you can `git bisect run` it.
9. **Differential loop.** Run the same input through old-version vs new-version (or two configs) and diff outputs.
10. **HITL bash script.** Last resort. If a human must click, drive _them_ with `scripts/hitl-loop.template.sh` so the loop is still structured. Captured output feeds back to you.

### Iterate on the loop itself

Improve the loop before investigating:

- Can I make it faster? (Cache setup, skip unrelated init, narrow the test scope.)
- Can I make the signal sharper? (Assert on the specific symptom, not "didn't crash".)
- Can I make it more deterministic? (Pin time, seed RNG, isolate filesystem, freeze network.)

### Non-deterministic bugs

The goal is not a clean repro but a **higher reproduction rate**. Loop the trigger 100×, parallelise, add stress, narrow timing windows, inject sleeps. A 50%-flake bug is debuggable; 1% is not — keep raising the rate until it's debuggable.

### When you genuinely cannot build a loop

Do not proceed to code changes. List what you tried and ask the user for: (a) access to the reproducing environment, (b) a captured artifact such as a HAR file, log dump, core dump, or timestamped screen recording, or (c) permission to add temporary production instrumentation.

Diagnosis may continue from logs, traces, and source evidence only when they support a falsifiable hypothesis. Mark conclusions that were not reproduced and state the remaining uncertainty.

## Phase 2 — Reproduce

When a loop exists, run it and watch the bug appear.

Confirm:

- [ ] The loop produces the failure mode the **user** described — not a different failure that happens to be nearby. Wrong bug = wrong fix.
- [ ] The failure is reproducible across multiple runs (or, for non-deterministic bugs, reproducible at a high enough rate to debug against).
- [ ] You have captured the exact symptom (error message, wrong output, slow timing) so later phases can verify the fix actually addresses it.

Do not proceed to a fix until you reproduce the bug. If reproduction is unavailable, continue only with the evidence-based diagnosis allowed in Phase 1 and stop after reporting its uncertainty.

## Phase 3 — Hypothesise

When several plausible causes remain, generate the smallest useful ranked set of hypotheses before testing them. If the existing evidence points to one cause, state its prediction and test it directly instead of inventing alternatives.

Each hypothesis must be **falsifiable**: state the prediction it makes.

> Format: "If <X> is the cause, then <changing Y> will make the bug disappear / <changing Z> will make it worse."

If you cannot state the prediction, the hypothesis is a vibe — discard or sharpen it.

Show the ranked list to the user before testing only when their domain knowledge could materially change the order. Do not block progress while waiting for optional re-ranking.

## Phase 4 — Instrument

Each probe must map to a specific prediction from Phase 3. **Change one variable at a time.**

Use the logs inspected in Phase 0 before adding probes. Instrument only the evidence gaps that distinguish the remaining hypotheses.

Tool preference:

1. **Debugger / REPL inspection** if the env supports it. One breakpoint beats ten logs.
2. **Targeted logs** at the boundaries that distinguish hypotheses.
3. Never "log everything and grep".

**Tag every debug log** with a unique prefix, e.g. `[DEBUG-a4f2]`. Cleanup at the end becomes a single grep. Untagged logs survive; tagged logs die.

**Perf branch.** After inspecting existing logs in Phase 0, use measurements rather than adding more logs: establish a baseline with a timing harness, profiler, or query plan, then bisect. Measure first, fix second.

## Phase 5 — Report or fix

For a diagnosis-only request, report the root cause in one sentence, the supporting logs or other evidence, reproduction status, material alternatives ruled out, remaining uncertainty, and the recommended fix. Then stop without modifying product code or adding persistent tests.

Continue with this phase only when the user requested a fix.

Write the regression test **before the fix** — but only if there is a **correct seam** for it.

A correct seam is one where the test exercises the **real bug pattern** as it occurs at the call site. If the only available seam is too shallow (single-caller test when the bug needs multiple callers, unit test that can't replicate the chain that triggered the bug), a regression test there gives false confidence.

**If no correct seam exists, that itself is the finding.** Note it. The codebase architecture is preventing the bug from being locked down. Flag this for the next phase.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 feedback loop against the original (un-minimised) scenario.

## Phase 6 — Cleanup + post-mortem

Required before declaring any diagnosis done:

- [ ] All `[DEBUG-...]` instrumentation removed (`grep` the prefix)
- [ ] Throwaway prototypes deleted (or moved to a clearly-marked debug location)

Also required before declaring a fix done:

- [ ] Original repro no longer reproduces (re-run the Phase 1 loop)
- [ ] Regression test passes (or absence of seam is documented)
- [ ] Relevant logs were checked again for the original error and any replacement failure
- [ ] If a commit or PR is part of the task, its message states the root cause

**Then ask: what would have prevented this bug?** If the answer involves architectural change such as no good test seam, tangled callers, or hidden coupling, recommend a focused refactor after the fix. Do not expand the current task without user approval.
