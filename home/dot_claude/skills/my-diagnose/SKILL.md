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

Run the phases in order; skip one only with a stated reason. First decide whether the request is diagnosis-only or diagnose-and-fix. A diagnosis request does not authorize product-code changes.

## Phase 0 — Inspect existing evidence

Read available logs and output before forming hypotheses or adding instrumentation. Record the exact symptom, time window, and identifiers (command, request or trace ID, environment, input, expected and actual result), and quote error text exactly before summarising it.

- State which log sources and time ranges you checked. A search miss is not evidence that no logs exist.
- If a relevant log is inaccessible, name the exact source or access needed instead of claiming it is absent.
- Do not add temporary production instrumentation without explicit permission.

## Phase 1 — Build a feedback loop

Build a fast, deterministic, agent-runnable pass/fail signal before testing causes; bisection, hypothesis tests, and instrumentation all depend on it. Assert on the reported symptom, not "didn't crash". Use a human-in-the-loop only as a last resort, and then drive the human with `scripts/hitl-loop.template.sh` so the loop stays structured and its output feeds back to you.

For non-deterministic bugs, aim for a higher reproduction rate rather than a clean repro: loop the trigger, parallelise, add stress, or narrow timing windows until the rate is debuggable.

If you cannot build a loop, make no code changes. List what you tried and ask for access to the reproducing environment, a captured artifact (HAR, log dump, core dump, timestamped recording), or permission for temporary production instrumentation. You may continue from logs, traces, and source only while they support a falsifiable hypothesis; mark such conclusions as unreproduced and state the uncertainty.

## Phase 2 — Reproduce

Confirm that the loop produces the failure the user described, not a nearby one, and that it recurs across runs (or at a debuggable rate). Capture the exact symptom so later phases can verify against it. Do not fix anything until the bug reproduces; without reproduction, stop after the evidence-based diagnosis allowed in Phase 1.

## Phase 3 — Hypothesise

When several causes remain plausible, write the smallest useful ranked set. When evidence points to one cause, test it directly. Each hypothesis states its prediction: "If X is the cause, changing Y will make the bug disappear (or changing Z will make it worse)." Discard or sharpen any hypothesis without a prediction.

Show the ranked list before testing only when the user's domain knowledge could change the order, and do not block on that input.

## Phase 4 — Instrument

Map each probe to a Phase 3 prediction and change one variable at a time. Instrument only the gaps the Phase 0 evidence leaves open; prefer a debugger or REPL over logs, and never log everything and grep.

Tag every debug log with a unique prefix such as `[DEBUG-a4f2]` so cleanup is one grep.

For performance regressions, measure instead of logging: establish a baseline with a timing harness, profiler, or query plan, then bisect.

## Phase 5 — Report or fix

For a diagnosis-only request, report the root cause in one sentence, the supporting evidence, reproduction status, material alternatives ruled out, remaining uncertainty, and the recommended fix. Then stop without modifying product code or adding persistent tests.

When a fix was requested, write the regression test before the fix, but only at a correct seam: one where the test exercises the real bug pattern as it occurs at the call site. A shallower seam gives false confidence. If no correct seam exists, report that as a finding. Otherwise turn the minimised repro into a failing test, watch it fail, apply the fix, watch it pass, then re-run the Phase 1 loop against the original scenario.

## Phase 6 — Cleanup and post-mortem

Before declaring any diagnosis done, remove all `[DEBUG-...]` instrumentation and delete throwaway prototypes or move them to a clearly marked debug location.

Before declaring a fix done, also confirm:

- the original repro no longer reproduces;
- the regression test passes, or the missing seam is documented;
- the relevant logs show neither the original error nor a replacement failure;
- any commit or PR message in scope states the root cause.

Then ask what would have prevented the bug. If the answer is architectural (no good test seam, tangled callers, hidden coupling), recommend a focused refactor without expanding the current task.
