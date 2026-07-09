# Evaluating Skill Output Quality

Eval-driven iteration: run realistic prompts with and without the skill, grade the outputs against assertions, and improve the skill based on evidence instead of impressions. Format follows the Agent Skills standard (https://agentskills.io/skill-creation/evaluating-skills).

## Contents

- Test case format (evals/evals.json)
- Workspace layout
- Running evals
- Assertions
- Grading (grading.json)
- Aggregating (benchmark.json)
- Analyzing patterns
- Human review
- Iteration loop

## Test case format (evals/evals.json)

Store test cases in `evals/evals.json` inside the skill directory. Each case has a realistic prompt, a human-readable expected output, and optional input files:

```json
{
  "skill_name": "csv-analyzer",
  "evals": [
    {
      "id": 1,
      "prompt": "I have a CSV of monthly sales data in data/sales_2025.csv. Can you find the top 3 months by revenue and make a bar chart?",
      "expected_output": "A bar chart image showing the top 3 months by revenue, with labeled axes and values.",
      "files": ["evals/files/sales_2025.csv"],
      "assertions": [
        "The output includes a bar chart image file",
        "The chart shows exactly 3 months",
        "Both axes are labeled"
      ]
    }
  ]
}
```

Prompt-writing rules:

- Start with 2-3 cases; expand after the first round of results.
- Vary phrasing: casual and precise, terse and detailed.
- Cover at least one edge case (malformed input, ambiguous request).
- Use realistic context (file paths, column names), not "process this data".
- Leave `assertions` empty on the first pass; add them after seeing real outputs.

## Workspace layout

Keep results in a workspace directory next to the skill. One `iteration-N/` per full pass; one eval directory per test case with `with_skill/` and `without_skill/` runs:

```
csv-analyzer/
├── SKILL.md
└── evals/
    └── evals.json
csv-analyzer-workspace/
└── iteration-1/
    ├── eval-top-months-chart/
    │   ├── with_skill/    (outputs/, timing.json, grading.json)
    │   └── without_skill/ (outputs/, timing.json, grading.json)
    └── benchmark.json
```

`evals.json` is authored by hand; the other JSON files are produced during the run.

## Running evals

Run each test case twice: once with the skill, once without (the baseline). When improving an existing skill, snapshot the current version (`cp -r <skill> <workspace>/skill-snapshot/`) and use the snapshot as the baseline instead.

Each run must start with a clean context — spawn a fresh subagent per run so the agent follows only what SKILL.md says, not leftover authoring context. Give each run: the skill path (or none for baseline), the prompt, input files, and the output directory.

Record tokens and duration per run in `timing.json` (in Claude Code, the subagent completion notification includes `total_tokens` and `duration_ms` — save them immediately, they are not persisted elsewhere):

```json
{ "total_tokens": 84852, "duration_ms": 23332 }
```

## Assertions

Assertions are verifiable statements about the output, added after the first round of outputs.

- Good: "The output file is valid JSON", "The report includes at least 3 recommendations" — observable, countable.
- Weak: "The output is good" (unverifiable), "uses exactly the phrase 'Total Revenue: $X'" (brittle).
- Not everything needs an assertion: style and visual polish belong to human review.

## Grading (grading.json)

Evaluate each assertion against actual outputs and record PASS/FAIL with concrete evidence (quote or reference the output). Use scripts for mechanical checks (valid JSON, file exists, row count); an LLM judge for the rest.

```json
{
  "assertion_results": [
    { "text": "Both axes are labeled", "passed": false,
      "evidence": "Y-axis is labeled 'Revenue ($)' but X-axis has no label" }
  ],
  "summary": { "passed": 3, "failed": 1, "total": 4, "pass_rate": 0.75 }
}
```

Grading principles:

- Require concrete evidence for a PASS; a section titled "Summary" with one vague sentence FAILS an "includes a summary" assertion.
- Review the assertions themselves: fix ones that always pass, always fail, or cannot be verified from the output.
- When comparing two skill versions, add a blind comparison: an LLM judge scores both outputs without knowing which version produced which.

## Aggregating (benchmark.json)

After grading every run, compute per-configuration statistics and the delta:

```json
{
  "run_summary": {
    "with_skill":    { "pass_rate": { "mean": 0.83 }, "tokens": { "mean": 3800 } },
    "without_skill": { "pass_rate": { "mean": 0.33 }, "tokens": { "mean": 2100 } },
    "delta": { "pass_rate": 0.50, "tokens": 1700 }
  }
}
```

The delta is the decision input: what the skill buys (pass rate) vs what it costs (tokens, time). Stddev is only meaningful with multiple runs per eval; early on, use raw pass counts.

## Analyzing patterns

- Assertions that pass in BOTH configurations: remove or replace — the model handles them without the skill.
- Assertions that fail in BOTH: the assertion or test case is broken; fix before the next iteration.
- Pass with skill, fail without: this is where the skill adds value — understand which instruction made the difference.
- Inconsistent results across runs: the instructions are ambiguous; add examples or more specific guidance.
- Time/token outliers: read the run transcript to find the bottleneck.

## Human review

Review actual outputs alongside grades and record specific feedback per test case (e.g., `feedback.json` in the workspace). "The chart is missing axis labels" is actionable; "looks bad" is not. Empty feedback = passed review.

## Iteration loop

1. Give the current SKILL.md plus all three signals — failed assertions, human feedback, run transcripts — to an LLM and ask for proposed changes.
2. Review and apply. Guidelines for the proposal: generalize from feedback (no narrow patches for specific test cases), keep the skill lean (remove instructions that caused wasted work), explain the why in instructions, bundle repeatedly-written helper code into `scripts/`.
3. Rerun all test cases in a new `iteration-<N+1>/` directory.
4. Grade, aggregate, review. Repeat.

Stop when feedback is consistently empty or improvement between iterations stalls.
