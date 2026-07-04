---
name: my-guided-tour
description: >-
  Explain code, architecture, product behavior, or a technical concept from a
  higher-level perspective, then create an HTML visual explanation and optional
  quiz matched to the user's understanding goal and role. Use when the user asks
  to zoom out, wants broader context, is unfamiliar with an area, wants a diagram,
  asks how something fits into the bigger picture, or wants enough context to
  implement safely. Include implementation locations and code/entity anchors when
  depth requires it. Do NOT use for direct implementation, refactoring, bug fixing,
  or scaffolding exercises.
license: MIT
---

> Adapted from mattpocock/skills (https://github.com/mattpocock/skills), commit aaf2453.

# Guided Tour Explanation

Guide the user through the target at the right altitude before any implementation work.

## Core rules

- Keep user-facing prose in the user's language. Preserve code identifiers, paths, type names, API fields, and domain terms that are written in the code.
- Ground the tour in current repository evidence: read the target module plus adjacent callers, types, tests, configs, or docs before explaining behavior.
- Do not invent missing behavior. If code diverges from design docs, say which part is code-backed and which part is design context.
- For implementation-level or complete-understanding goals, include concise real code snippets for important DTOs, public types, entity definitions, schemas, config objects, or interfaces.
- In the overall explanation, explicitly map each conceptual part to where it is implemented, what kind of part it is, its main inputs/outputs, and key types/entities.
- Include concrete examples from the investigated repository. Prefer examples that name a real file, symbol, endpoint, config key, entity field, test case, or observed value; avoid abstract examples such as "module A calls module B".

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
4. **Focus area for broad topics**
   - Architecture and module relationships
   - User or product behavior
   - Data flow and state changes
   - API or interface contracts
   - Failure modes and edge cases
   - Implementation roadmap or extension points

If the user already supplied these answers, do not ask again.

For broad topics, ask which area to emphasize before producing the explanation. If the user does not choose, lead with the highest-level map first, then identify 2-3 likely focus areas and ask before going deeper.

## Investigation

Before explaining code or architecture:

1. Read the target file/module and the most relevant adjacent files, callers, tests, configs, or docs.
2. Identify the domain vocabulary used by the project.
3. Map how the target fits into the surrounding system: inputs, outputs, dependencies, callers, side effects, and invariants.
4. Search for callers and downstream consumers before explaining public contracts such as exported functions, public types, config keys, schemas, API responses, or CLI flags.
5. State what was verified and what could not be verified.

Do not invent missing behavior. If evidence is insufficient, say what evidence is missing.

## Concrete examples

Use examples to make the explanation actionable. Concrete examples should be code-backed and specific enough for the user to jump into the repository.

Good examples:

- "`handler/recommender/v2/validator/parser.go` sets `req.ClientID = c.Param(\"clientId\")`, so the path parameter is the source of truth."
- "`entity.Shelf` in `go/pkg/entity/shelf.go` is the final response shape; `Items []Item` is populated after Bigtable metadata hydration."
- "`shelforder/defaults.go` is where a new default `ShelfExecutionPlan` starts; `shelforder/map.go` then applies client/order/shelf overrides."

Avoid examples:

- "The parser normalizes input."
- "A service calls another service."
- "The data model has an entity."

## Explanation levels

Adjust depth to the user's goal:

- **Conceptual understanding**: focus on purpose, mental model, domain terms, and why the structure exists. Avoid implementation detail unless needed for orientation.
- **Use while implementing**: include boundaries, extension points, common pitfalls, relevant files, examples of safe changes, and real types/entities that define the contract.
- **Recreate/reimplement**: include data flow, control flow, invariants, edge cases, minimal algorithm, test strategy, and concise code/entity excerpts.

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
4. A concrete examples section or inline examples that show actual files, symbols, values, and behavior from the repository
5. Key concepts and glossary
6. How the pieces interact, preferably with implementation file references for each step
7. Implementation anchors with concise real code snippets when the user's goal is implementation-level or complete understanding
8. Where-to-change guidance for likely implementation tasks
9. Failure modes and edge cases when relevant
10. A parts-and-implementation section mapping diagram boxes to files/modules, responsibilities, inputs/outputs, and key types/entities; this can be near the end as an implementation appendix if placing it earlier would interrupt the explanation flow
11. Verified sources within the repository, such as files, tests, or docs read

If creating the HTML in a project, choose a clear local artifact path and show it to the user with the available preview mechanism when possible.

## Quiz

After the explanation, create a short quiz when possible unless the user asked to skip it.

Match the quiz to the user's understanding goal:

- **Conceptual understanding**: vocabulary, purpose, and diagram-reading questions.
- **Use while implementing**: concrete scenario questions about where to make a change, which dependency matters, or what invariant must be preserved.
- **Recreate/reimplement**: step-by-step reconstruction, edge cases, and test-design questions grounded in actual code paths, types, or entity fields.

Match the quiz to the user's role:

- **Engineer**: include code-path, API, invariant, and test questions.
- **Product/business**: include behavior, trade-off, workflow, and impact questions.

For HTML output:

- Use multiple-choice questions only.
- Use at most 10 questions.
- Use 2-5 options per question; do not force exactly 3 options.
- Add a difficulty label to every question as `Level 1` through `Level 5`.
- Show correctness and explanation immediately when the user selects an option; do not require a submit button.
- Include explanations for both correct and incorrect selections.
- A reset button and score summary are useful, but secondary to immediate feedback.

For text-only output, multiple-choice is still preferred. Short-answer questions are acceptable only when there is no interactive HTML quiz.

## Boundaries

Do not implement, refactor, debug, or scaffold exercises as part of this skill. If the explanation reveals implementation work, stop after explaining the recommended next step unless the user explicitly asks to proceed with a separate implementation task.
