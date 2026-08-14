---
name: my-skill-creator
description: >-
  Interactive guide for creating and improving portable Agent Skills (SKILL.md files)
  shared by Claude Code, Codex, and Cursor. Use when the user asks to create, update,
  validate, or fix a skill definition or says a skill does not trigger. Do NOT use for
  general coding tasks or requests that merely contain the word "create".
license: Complete terms in LICENSE.txt
---

# Portable Skill Creator

Create one skill directory that Claude Code, Codex, and Cursor can load. Keep shared behavior in
`SKILL.md`; add product-specific adapter files only where the clients have no common field.

## References

Read only the references needed for the task:

- **Client compatibility**: Read `references/compatibility.md` before choosing frontmatter,
  discovery paths, invocation controls, or product-specific features.
- **Workflow patterns**: Read `references/workflows.md` for sequential and conditional workflows.
- **Output patterns**: Read `references/output-patterns.md` for templates and examples.
- **Evaluation**: Read `references/evaluating-skills.md` for eval cases, grading, and iteration.

## Core principles

1. Keep the skill portable by default. Use client-specific behavior only when the requested
   workflow cannot be expressed through the shared skill body.
2. Keep instructions concise. Add only knowledge or procedure that a capable coding agent would
   not infer reliably.
3. Match instruction strictness to risk. Use exact scripts for fragile operations and judgment-based
   guidance where several approaches are valid.
4. Load detail progressively: `name` and `description`, then the `SKILL.md` body, then referenced
   files and scripts as needed.

## Directory structure

```text
skill-name/
├── SKILL.md              # Required: shared metadata and instructions
├── agents/
│   └── openai.yaml       # Optional: Codex UI, dependencies, and invocation policy
├── scripts/              # Optional: executable helpers
├── references/           # Optional: documentation loaded on demand
└── assets/               # Optional: templates and output resources
```

Do not add README.md, CHANGELOG.md, installation guides, or empty resource directories.

## Frontmatter

Start with the open Agent Skills fields:

```yaml
---
name: kebab-case-name
description: >-
  What the skill does. Use when the user asks for specific tasks or mentions relevant files.
  Do NOT use for adjacent tasks outside its scope.
---
```

### Open standard fields

| Field | Requirement |
|---|---|
| `name` | Required. 1-64 lowercase letters, digits, and hyphens. Match the directory name. |
| `description` | Required. 1-1024 characters. State what the skill does and when to use it. |
| `license` | Optional. License name or bundled license file. |
| `compatibility` | Optional. 1-500 characters describing actual environment requirements. |
| `metadata` | Optional. String-to-string metadata for external tooling. |
| `allowed-tools` | Optional and experimental. Do not assume every client enforces it. |

### Shared Claude Code and Cursor extensions

These fields are not part of the open specification, but both Claude Code and Cursor document them:

| Field | Behavior and portability requirement |
|---|---|
| `disable-model-invocation` | `true` makes the skill explicit-only in Claude Code and Cursor. Add the matching Codex policy shown below. |
| `paths` | Limits automatic discovery to matching file globs in Claude Code and Cursor. Codex has no documented equivalent. |

For a manual-only skill, keep both declarations in the same directory:

```yaml
# SKILL.md
disable-model-invocation: true
```

```yaml
# agents/openai.yaml
policy:
  allow_implicit_invocation: false
```

Treat `paths` as a deliberate two-client enhancement. Put essential scope in `description` as well,
because Codex ignores the field.

### Claude Code extensions

Do not use these by default in a shared skill:

`when_to_use`, `argument-hint`, `arguments`, `user-invocable`, `disallowed-tools`, `model`,
`effort`, `context`, `agent`, `background`, `hooks`, and `shell`.

When the user explicitly accepts a Claude Code dependency, document it in `compatibility` and read
the current Claude Code documentation before using an extension. Do not place Claude Code-only keys
in `metadata` to disguise them as portable fields.

## Portable body content

- Write instructions against capabilities, inputs, and outcomes rather than a client's tool names.
- Refer to bundled files with paths relative to the skill root.
- Read arguments from the user's current request. Do not rely on client-specific argument variables.
- Do not use Claude Code dynamic command injection or `CLAUDE_*` environment substitutions by default.
- Keep client invocation syntax out of workflow instructions. Claude Code and Cursor use `/name`;
  Codex uses `$name`.
- State required executables, network access, and platform assumptions in `compatibility` or the body.
- Separate network operations from local writes so a failed dependency stops with a clear error.

## Creation process

### 1. Understand the use cases

Identify concrete requests that should and should not use the skill. Ask only when materially
different interpretations remain after inspecting the repository and nearby skills.

### 2. Plan reusable contents

For each use case, determine whether repeated work belongs in:

- `scripts/` for deterministic operations;
- `references/` for detailed knowledge loaded only when needed;
- `assets/` for templates or files copied into outputs.

Avoid duplicating the same instruction in `SKILL.md` and a reference.

### 3. Choose the source directory

Follow the repository's existing convention first. Do not create a second copy of a skill.

- In this dotfiles repository, create under `home/dot_claude/skills/`; the existing deployment
  links the same directory into Codex, and Cursor reads Claude skill directories directly.
- In a repository without an established convention, prefer `.agents/skills/` as the canonical
  directory for Codex and Cursor, then symlink the same skill directory under `.claude/skills/`
  for Claude Code.
- For global skills, apply the same arrangement under the user's home directory.

Verify the source-to-target mapping before creating or linking anything.

### 4. Initialize and edit

For a new skill, run:

```bash
uv run <skill-root>/scripts/init_skill.py <skill-name> --path <output-directory>
```

Replace `<skill-root>` with the absolute path of this skill directory.

Add only the resource directories that are needed:

```bash
uv run <skill-root>/scripts/init_skill.py <skill-name> --path <output-directory> \
  --resources scripts,references
```

For a manual-only skill, generate both clients' invocation controls together:

```bash
uv run <skill-root>/scripts/init_skill.py <skill-name> --path <output-directory> --manual-only
```

When editing an existing skill, skip initialization. Preserve useful resources and repository
conventions.

### 5. Validate

Run the portable profile by default:

```bash
uv run <skill-root>/scripts/quick_validate.py <skill-directory>
```

It accepts the open fields plus the two shared Claude Code and Cursor extensions. It also checks
that a manual-only skill has the matching Codex policy. Use `--profile standard` for the strict open
specification or `--profile claude` only for an intentionally Claude Code-specific skill.

Do not create a `.skill` archive for repository-managed skills. The shared directory is the
deployable unit.

### 6. Test and iterate

Test at least:

- an obvious triggering request;
- a paraphrased triggering request;
- an unrelated request that should not trigger;
- the workflow's main success path and material failure path.

For manual-only skills, verify explicit invocation in each installed client. For automatic skills,
test description matching separately in Claude Code, Codex, and Cursor because routing behavior is
client-specific.

For complex skills, compare representative tasks with and without the skill. Read
`references/evaluating-skills.md` before building an evaluation set.

## Writing guidelines

- Use imperative instructions and explicit inputs, outputs, and stop conditions.
- Put all trigger information in `description`; the body loads only after selection.
- Prefer a short example over an abstract explanation.
- Keep `SKILL.md` under 500 lines and move conditional detail to one-level-deep references.
- Test every added script by running it.
- Delete initializer placeholders that the finished skill does not need.

## Troubleshooting

| Symptom | Likely cause | Change |
|---|---|---|
| Skill does not appear | Wrong discovery directory or invalid frontmatter | Check the client path, symlink, and validator output. |
| Skill does not trigger | Vague or truncated description | Put the main use case and trigger words first. |
| Skill triggers too often | Scope is broad | Add concrete negative triggers or make it manual-only. |
| Manual-only behavior differs in Codex | Missing or stale sidecar policy | Set `policy.allow_implicit_invocation: false`. |
| Behavior differs across clients | Product-specific field or body syntax | Remove it or document the dependency and add an adapter. |
| Instructions are ignored | Critical steps are buried | Move them earlier and remove nonessential prose. |
