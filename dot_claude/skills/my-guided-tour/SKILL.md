---
name: my-guided-tour
description: >-
  Explain code, architecture, product behavior, or a technical concept from a
  higher-level perspective, then create an HTML visual explanation and optional
  quiz matched to the user's understanding goal and role. Use when the user asks
  to zoom out, wants broader context, is unfamiliar with an area, wants a diagram,
  or asks how something fits into the bigger picture. Do NOT use for direct
  implementation, refactoring, bug fixing, or scaffolding exercises.
license: MIT
---

> Adapted from mattpocock/skills (https://github.com/mattpocock/skills), commit aaf2453.

# Guided Tour Explanation

Guide the user through the target at the right altitude before any implementation work.

## Start by asking

Ask the user concise questions before explaining when their goal, audience, or expected depth is unclear:

1. **Understanding goal**
   - Conceptual understanding only
   - Enough understanding to use it while implementing another feature
   - Enough understanding to recreate or reimplement it
2. **User role**
   - Engineer
   - Product/business stakeholder
   - Mixed or unknown audience
3. **Output preference**
   - HTML visual explanation
   - Text-first explanation plus HTML
   - Quiz included or skipped

If the user already supplied these answers, do not ask again.

## Investigation

Before explaining code or architecture:

1. Read the target file/module and the most relevant adjacent files, callers, tests, configs, or docs.
2. Identify the domain vocabulary used by the project.
3. Map how the target fits into the surrounding system: inputs, outputs, dependencies, callers, side effects, and invariants.
4. State what was verified and what could not be verified.

Do not invent missing behavior. If evidence is insufficient, say what evidence is missing.

## Explanation levels

Adjust depth to the user's goal:

- **Conceptual understanding**: focus on purpose, mental model, domain terms, and why the structure exists. Avoid implementation detail unless needed for orientation.
- **Use while implementing**: include boundaries, extension points, common pitfalls, relevant files, and examples of safe changes.
- **Recreate/reimplement**: include data flow, control flow, invariants, edge cases, minimal algorithm, and test strategy.

Adjust language to the user's role:

- **Engineer**: include interfaces, dependencies, invariants, failure modes, and test seams.
- **Product/business**: explain user-visible behavior, business rules, trade-offs, and operational impact. Avoid unnecessary code detail.
- **Mixed audience**: lead with business meaning, then add a technical appendix.

## HTML visual explanation

Create an HTML file when useful or requested. Include diagrams directly in the HTML using semantic HTML/CSS and, when helpful, inline SVG. Prefer static, dependency-free HTML unless the user requests otherwise.

The HTML should include:

1. Title and short summary
2. Scope and assumptions
3. High-level map or flow diagram
4. Key concepts and glossary
5. How the pieces interact
6. Role- and goal-appropriate detail
7. Verified sources within the repository, such as files, tests, or docs read

If creating the HTML in a project, choose a clear local artifact path and show it to the user with the available preview mechanism when possible.

## Quiz

After the explanation, create a short quiz when possible unless the user asked to skip it.

Match the quiz to the user's understanding goal:

- **Conceptual understanding**: vocabulary, purpose, and diagram-reading questions.
- **Use while implementing**: scenario questions about where to make a change, which dependency matters, or what invariant must be preserved.
- **Recreate/reimplement**: step-by-step reconstruction, edge cases, and test-design questions.

Match the quiz to the user's role:

- **Engineer**: include code-path, API, invariant, and test questions.
- **Product/business**: include behavior, trade-off, workflow, and impact questions.

Use 3-7 questions. Prefer a mix of multiple-choice and short-answer questions. Include an answer key after the user has had a chance to answer, or include it immediately if the user asks for self-study material.

## Boundaries

Do not implement, refactor, debug, or scaffold exercises as part of this skill. If the explanation reveals implementation work, stop after explaining the recommended next step unless the user explicitly asks to proceed with a separate implementation task.
