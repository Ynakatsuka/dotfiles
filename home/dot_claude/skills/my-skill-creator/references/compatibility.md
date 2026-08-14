# Client compatibility

Use this reference when a skill must work from one directory in Claude Code, Codex, and Cursor.
The product specifications change independently. Recheck the official pages before adding a field
or feature not listed here.

Verified: 2026-08-15

## Sources

- Agent Skills specification: https://agentskills.io/specification
- Claude Code skills: https://code.claude.com/docs/en/skills
- Codex skills: https://developers.openai.com/codex/skills
- Cursor skills: https://cursor.com/docs/skills

## Frontmatter matrix

The table records documented behavior, not whether a client merely ignores an unknown key.

| Field | Open specification | Claude Code | Codex | Cursor |
|---|---|---|---|---|
| `name` | Required | Supported | Used for discovery | Required |
| `description` | Required | Used for routing | Used for routing | Used for routing |
| `license` | Optional | Accepted | No documented behavior | No documented behavior |
| `compatibility` | Optional | Accepted | No documented behavior | No documented behavior |
| `metadata` | Optional | Accepted | No documented behavior | Supported |
| `allowed-tools` | Experimental | Grants tools for the invoking turn | No documented behavior | No documented behavior |
| `disable-model-invocation` | No | Explicit-only | Use `agents/openai.yaml` | Explicit-only |
| `paths` | No | File-glob routing | No equivalent | File-glob routing |

`allowed-tools` is part of the open specification, but support is explicitly experimental. Do not
use it to establish a security boundary in a shared skill.

## Manual-only mapping

Claude Code and Cursor share this frontmatter field:

```yaml
disable-model-invocation: true
```

Codex expresses the same policy in a sidecar file:

```yaml
# agents/openai.yaml
policy:
  allow_implicit_invocation: false
```

Keep both files in the same skill directory. Other clients can ignore `agents/openai.yaml`.

## File scoping

Claude Code and Cursor support `paths` as a string or list of glob patterns. Codex does not
document a matching field. When using `paths`:

1. Put the essential scope in `description` so Codex can route by meaning.
2. Treat the glob as a Claude Code and Cursor optimization.
3. Test Codex separately for over-triggering.

Nested discovery directories can also scope skills, but client behavior differs. Cursor discovers
nested skill roots throughout a repository. Claude Code loads nested roots when it works in that
subdirectory. Codex scans `.agents/skills` from the current directory upward to the repository root.

## Discovery directories

| Client | Project | User |
|---|---|---|
| Claude Code | `.claude/skills/` | `~/.claude/skills/` |
| Codex | `.agents/skills/` from the working directory through the repository root | `~/.agents/skills/` |
| Cursor | `.agents/skills/`, `.cursor/skills/`, plus Claude and Codex compatibility paths | `~/.agents/skills/`, `~/.cursor/skills/`, plus compatibility paths |

There is no one physical discovery root documented by all three clients. Use one canonical skill
directory and symlink it into the missing discovery roots. Do not copy the directory.

For a new generic repository, this layout minimizes adapters:

```text
.agents/skills/example/          # Canonical directory for Codex and Cursor
.claude/skills/example           # Symlink to ../../.agents/skills/example for Claude Code
```

In a repository with an established deployment convention, keep that convention and expose the
same directory through symlinks.

## Invocation syntax

| Client | Explicit invocation |
|---|---|
| Claude Code | `/skill-name` |
| Codex | `$skill-name` |
| Cursor | `/skill-name` |

Do not make the body depend on the spelling of the invocation. The host supplies the current user
request when it activates the skill.

## Features to avoid in a portable skill

Claude Code documents additional frontmatter fields and body preprocessing that Codex and Cursor
do not share:

- `when_to_use`, `argument-hint`, and named `arguments`;
- `user-invocable`, `disallowed-tools`, `model`, and `effort`;
- `context`, `agent`, `background`, and `hooks`;
- `shell`, dynamic command injection, and `CLAUDE_*` substitutions.

Use them only when the user accepts a Claude Code dependency. Record the requirement in
`compatibility`, and validate with the `claude` profile.
