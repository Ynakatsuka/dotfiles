---
name: my-better
description: >-
  Push a task to a deeper version of itself, not a bigger one: name what a top practitioner
  would add, the raw material to start from, the methods and tools to use, and an independent
  check of the result, then rewrite the brief and do the work to it. Use when the user explicitly
  invokes my-better, says a result is shallow or not good enough (「浅い」「もっと深く」
  「物足りない」), or before starting a hard task: open-ended research, analysis, design, or
  writing whose quality depends on expertise, primary evidence, or verification the request does
  not mention. Do NOT use for routine edits, single obvious fixes, quick lookups, fully specified
  tasks with clear acceptance checks, or work covered by a more specific skill such as my-diagnose,
  my-epic, or my-pr.
---

> Adapted from joshp123's `/better` skill
> (https://gist.github.com/joshp123/a1443d30fa1b7c577e74882895cea61b).

# Better

Ask for a deeper version of the task, not a bigger one.

## Choose the mode

- **Prompt rewrite**: The user explicitly invoked this skill with a prompt or task that has not
  started. Answer the questions, give the rewritten prompt, and stop. Do not carry it out.
- **Redo**: The user explicitly invoked this skill alone or with feedback on work already done in
  this conversation. The task is that work, and the feedback is part of it.
- **Automatic**: The skill was selected without explicit invocation because the task is hard.
  Keep the answers and the brief to a few lines so the user can redirect early.

## Answer the questions

Answer each for this specific task, in a few lines:

1. **Practice**: What would a top practitioner in this field do here that the request does not ask
   for?
2. **Raw material**: What raw source would they start from instead of material already digested
   for the user, such as code, logs, data, primary documents, or the running system?
3. **Methods**: Which specific methods and tools would they use?
4. **Independent check**: What, other than the agent's or the user's judgment, would show the
   result is right, such as a test, measurement, reproduction, or primary source?

Then write the deepened brief: the original request and any feedback, sharpened by these answers.

## Decide whether to pause

In Redo and Automatic modes, show the brief and wait for the user's go-ahead when it changes the
goal, adds deliverables or affected systems, or needs a decision, money, or access only the user
can give. Better sources, methods, and checks for the same deliverable do not need approval;
continue without asking.

## Do the work

Start from the raw material in answer 2 and use the methods in answer 3. Before reporting, run the
check in answer 4 and state what it showed. If the check cannot be run, name what blocked it and
what would run it; do not report the result as verified.
