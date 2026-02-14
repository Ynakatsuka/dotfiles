---
name: my-skill-creator
description: Interactive guide for creating and improving skills. Use when users want to create a new skill, update an existing skill, or improve skill quality. Triggers on requests like "create a skill", "new skill", "build a skill", "improve this skill", "update skill", "skill doesn't trigger", or "fix my skill".
license: Complete terms in LICENSE.txt
---

# Skill Creator

Interactive guide for creating effective skills that extend Claude's capabilities.

## Reference Materials

Consult these based on your needs:

- **Complete official guide**: See `references/complete-guide.md` for Anthropic's full skill-building guide (fundamentals, planning, testing, distribution, 5 design patterns, troubleshooting)
- **Workflow patterns**: See `references/workflows.md` for sequential and conditional workflow design
- **Output patterns**: See `references/output-patterns.md` for template and example patterns

## Core Principles

1. **Concise is key**: Claude is already smart. Only add context Claude doesn't already have. Prefer concise examples over verbose explanations. Challenge each piece of information: "Does this justify its token cost?"
2. **Progressive disclosure**: Metadata always loaded (~100 words) → SKILL.md body on trigger (<5k words, <500 lines) → Bundled resources as needed.
3. **Appropriate degrees of freedom**: High freedom for flexible tasks (text-based instructions), medium for preferred patterns (pseudocode/scripts with parameters), low for fragile/error-prone operations (specific scripts, few parameters).

## Skill Structure

```
skill-name/
├── SKILL.md (required, case-sensitive)
│   ├── YAML frontmatter (name + description, required)
│   └── Markdown body (instructions)
├── scripts/          - Executable code (deterministic, token-efficient)
├── references/       - Documentation loaded into context as needed
└── assets/           - Files used in output (templates, icons, fonts)
```

**Do NOT include**: README.md, CHANGELOG.md, INSTALLATION_GUIDE.md, or other auxiliary files.

### Frontmatter

```yaml
---
name: kebab-case-name       # Must match folder name, no spaces/capitals
description: |               # Under 1024 chars, no XML tags (< >)
  What it does. Use when user asks to [specific phrases].
  Triggers on [task types, file types, keywords].
---
```

**Description is the primary triggering mechanism.** Structure: `[What it does] + [When to use it] + [Key capabilities/trigger phrases]`

Good descriptions:
```yaml
# Specific and actionable with trigger phrases
description: Analyzes Figma design files and generates developer handoff documentation. Use when user uploads .fig files, asks for "design specs", "component documentation", or "design-to-code handoff".

# Clear value proposition with scope
description: End-to-end customer onboarding workflow for PayFlow. Handles account creation, payment setup, and subscription management. Use when user says "onboard new customer", "set up subscription", or "create PayFlow account".
```

Bad descriptions:
```yaml
description: Helps with projects.  # Too vague, no triggers
description: Creates sophisticated multi-page documentation systems.  # Missing triggers
description: Implements the Project entity model with hierarchical relationships.  # Too technical
```

Negative triggers (prevent misfires):
```yaml
# Good - includes negative triggers to prevent misfires
description: |
  Deploys applications to AWS ECS. Use when user says "deploy to ECS", "update service".
  Do NOT use for Lambda deployments or local Docker builds.

# Good - clear boundary setting
description: |
  Generates unit tests for Python code. Triggers on "write tests", "add test coverage".
  Do NOT use for integration tests, E2E tests, or test infrastructure setup.
```

Optional fields: `license`, `compatibility` (1-500 chars, environment requirements), `allowed-tools`, `metadata` (author, version, mcp-server).

### Resource Guidelines

| Type | When to Include | Key Points |
|---|---|---|
| `scripts/` | Same code rewritten repeatedly; deterministic reliability needed | Test by running; token-efficient; may execute without loading into context |
| `references/` | Detailed docs that Claude should reference while working | Keeps SKILL.md lean; for files >10k words, include grep patterns in SKILL.md |
| `assets/` | Files used in output, not loaded into context | Templates, images, fonts, boilerplate code |

**Avoid duplication**: Information should live in either SKILL.md or references, not both.

### Progressive Disclosure Patterns

Split into reference files when SKILL.md approaches 500 lines. Reference all split files from SKILL.md with clear descriptions of when to read them.

- **Pattern 1 — High-level guide**: Core instructions in SKILL.md, detailed docs in references
- **Pattern 2 — Domain-specific**: One reference file per domain/variant (e.g., `references/aws.md`, `references/gcp.md`)
- **Pattern 3 — Conditional**: Basic content in SKILL.md, advanced/specialized content in references

Keep references one level deep from SKILL.md. For reference files >100 lines, include a table of contents.

## Skill Creation Process

1. Understand the skill with concrete examples
2. Plan reusable skill contents (scripts, references, assets)
3. Initialize the skill (run `init_skill.py`)
4. Edit the skill (implement resources and write SKILL.md)
5. Test and iterate based on real usage

### Step 1: Understand with Concrete Examples

Skip only when usage patterns are already clearly understood.

Ask focused questions to understand the skill's scope:
- "What functionality should the skill support?"
- "Can you give examples of how this skill would be used?"
- "What would a user say that should trigger this skill?"

Avoid overwhelming users — start with the most important questions, follow up as needed. Conclude when there is a clear sense of the functionality the skill should support.

### Step 2: Plan Reusable Contents

For each concrete example, analyze:
1. How to execute from scratch
2. What scripts, references, and assets would be helpful for repeated execution

Examples:
- PDF rotation → `scripts/rotate_pdf.py` (same code rewritten each time)
- Frontend webapp → `assets/hello-world/` template (same boilerplate each time)
- BigQuery queries → `references/schema.md` (table schemas rediscovered each time)

### Step 3: Initialize the Skill

For new skills, run:

```bash
scripts/init_skill.py <skill-name> --path <output-directory>
```

The script creates the directory, generates SKILL.md with TODO placeholders, and creates example resource directories. Delete unneeded example files after initialization.

Skip if iterating on an existing skill.

### Step 4: Edit the Skill

The skill is for another Claude instance to use. Include information that is beneficial and non-obvious.

#### Writing Guidelines

- Use imperative/infinitive form
- **All "when to use" information goes in the description**, not the body. The body is only loaded after triggering.
- Be specific and actionable: provide exact commands with parameters, not vague instructions
- Include error handling for common failure modes
- Scope permissions minimally: use `allowed-tools` in frontmatter to restrict tool access to only what the skill needs
- Separate network-dependent operations: isolate steps that require network access (API calls, package installs) from steps that perform local file operations, so failures in one do not cascade
- Reference bundled resources clearly with paths and context for when to read them

#### Design Pattern References

- **Multi-step processes**: See `references/workflows.md`
- **Output formats/quality standards**: See `references/output-patterns.md`
- **5 advanced patterns** (sequential workflow orchestration, multi-MCP coordination, iterative refinement, context-aware tool selection, domain-specific intelligence): See `references/complete-guide.md` Chapter 5

#### Reusable Contents

Start with the resources identified in Step 2. This step may require user input (e.g., brand assets, API documentation).

- Test all added scripts by running them
- Delete unneeded example files from initialization

### Step 5: Test and Iterate

#### Testing Checklist

1. **Triggering tests**: Does the skill trigger on obvious tasks? On paraphrased requests? Does it NOT trigger on unrelated topics? (Target: 90% trigger rate on relevant queries)
2. **Functional tests**: Are outputs correct? Do scripts work? Are edge cases handled?
3. **Performance comparison**: Measure concrete metrics with vs. without the skill:
   - Token consumption (target: 30-50% reduction)
   - API/tool call failure rate (target: 0 failures)
   - End-to-end task completion rate
   - Number of user interventions required

Debugging trigger issues: Ask Claude "When would you use the [skill name] skill?" — Claude will quote the description back. Adjust based on what's missing.

#### Iteration Signals

| Signal | Problem | Solution |
|---|---|---|
| Skill doesn't load when it should | Undertriggering | Add more detail, keywords, and trigger phrases to description |
| Skill loads for unrelated queries | Overtriggering | Add negative triggers, be more specific, clarify scope |
| Inconsistent results | Instruction quality | Be more specific, add validation steps, use scripts for determinism |
| Instructions not followed | Buried or verbose | Put critical instructions at top, use bullet points, move details to references |
| Slow or degraded responses | Context overload | Move docs to references/, keep SKILL.md under 5,000 words, reduce enabled skills |

#### Production Tip: Explicit Invocation

For critical or production workflows where routing accuracy matters, instruct users to invoke skills explicitly rather than relying on fuzzy description matching:

```
Use the <skill-name> skill to [do X].
```

This bypasses the description-based routing and guarantees the correct skill is loaded. Recommended for CI/CD pipelines, automated workflows, or when multiple similar skills are enabled.

For detailed troubleshooting, see `references/complete-guide.md` (Chapter 5: Patterns and Troubleshooting).
