#!/usr/bin/env python3
"""Create a portable Agent Skill directory."""

import argparse
import re
import sys
from pathlib import Path

MAX_SKILL_NAME_LENGTH = 64
ALLOWED_RESOURCES = {"scripts", "references", "assets"}

SKILL_TEMPLATE = """---
name: {skill_name}
description: >-
  TODO: Describe what this skill does, when to use it, and when not to use it.
{manual_frontmatter}---

# {skill_title}

## Instructions

TODO: Add concise, imperative instructions with explicit inputs, outputs, and stop conditions.

## Resources

TODO: Reference only the bundled files this skill needs. Delete this section if none are needed.
"""

EXAMPLE_SCRIPT = '''#!/usr/bin/env python3
"""Example helper for {skill_name}. Replace or delete this file."""


def main():
    print("Replace this example with the real helper for {skill_name}.")


if __name__ == "__main__":
    main()
'''

EXAMPLE_REFERENCE = """# {skill_title} reference

Replace this placeholder with detailed information that is needed only for some requests.
"""

EXAMPLE_ASSET = """Replace this placeholder with an output template or other static asset.
"""


def normalize_skill_name(raw_name):
    """Normalize a user-provided name to the Agent Skills naming format."""
    normalized = re.sub(r"[^a-z0-9]+", "-", raw_name.strip().lower())
    normalized = re.sub(r"-{2,}", "-", normalized).strip("-")
    return normalized


def title_case_skill_name(skill_name):
    """Convert a hyphenated skill name to a display title."""
    return " ".join(part.capitalize() for part in skill_name.split("-"))


def parse_resources(raw_resources):
    if not raw_resources:
        return []
    resources = [item.strip() for item in raw_resources.split(",") if item.strip()]
    invalid = sorted(set(resources) - ALLOWED_RESOURCES)
    if invalid:
        allowed = ", ".join(sorted(ALLOWED_RESOURCES))
        raise ValueError(
            f"Unknown resource type(s): {', '.join(invalid)}. Allowed: {allowed}"
        )
    return list(dict.fromkeys(resources))


def create_openai_policy(skill_dir):
    agents_dir = skill_dir / "agents"
    agents_dir.mkdir()
    openai_yaml = agents_dir / "openai.yaml"
    openai_yaml.write_text(
        "policy:\n  allow_implicit_invocation: false\n",
        encoding="utf-8",
    )
    print("[OK] Created agents/openai.yaml")


def create_resources(skill_dir, skill_name, skill_title, resources, include_examples):
    for resource in resources:
        resource_dir = skill_dir / resource
        resource_dir.mkdir()
        if not include_examples:
            print(f"[OK] Created {resource}/")
            continue
        if resource == "scripts":
            example_path = resource_dir / "example.py"
            example_path.write_text(
                EXAMPLE_SCRIPT.format(skill_name=skill_name),
                encoding="utf-8",
            )
            example_path.chmod(0o755)
        elif resource == "references":
            example_path = resource_dir / "example.md"
            example_path.write_text(
                EXAMPLE_REFERENCE.format(skill_title=skill_title),
                encoding="utf-8",
            )
        else:
            example_path = resource_dir / "example.txt"
            example_path.write_text(EXAMPLE_ASSET, encoding="utf-8")
        print(f"[OK] Created {example_path.relative_to(skill_dir)}")


def init_skill(skill_name, output_dir, resources, include_examples, manual_only):
    """Create the skill directory and return its path."""
    skill_dir = Path(output_dir).resolve() / skill_name
    if skill_dir.exists():
        raise FileExistsError(f"Skill directory already exists: {skill_dir}")

    skill_dir.mkdir(parents=True)
    print(f"[OK] Created skill directory: {skill_dir}")

    manual_frontmatter = "disable-model-invocation: true\n" if manual_only else ""
    skill_content = SKILL_TEMPLATE.format(
        skill_name=skill_name,
        skill_title=title_case_skill_name(skill_name),
        manual_frontmatter=manual_frontmatter,
    )
    (skill_dir / "SKILL.md").write_text(skill_content, encoding="utf-8")
    print("[OK] Created SKILL.md")

    if manual_only:
        create_openai_policy(skill_dir)
    create_resources(
        skill_dir,
        skill_name,
        title_case_skill_name(skill_name),
        resources,
        include_examples,
    )
    return skill_dir


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("skill_name", help="Skill name in lowercase hyphen-case")
    parser.add_argument(
        "--path", required=True, help="Directory that will contain the skill"
    )
    parser.add_argument(
        "--resources",
        default="",
        help="Comma-separated optional directories: scripts,references,assets",
    )
    parser.add_argument(
        "--examples",
        action="store_true",
        help="Add placeholders to the selected resource directories",
    )
    parser.add_argument(
        "--manual-only",
        action="store_true",
        help="Disable automatic invocation in Claude Code, Cursor, and Codex",
    )
    args = parser.parse_args()

    skill_name = args.skill_name
    if len(skill_name) > MAX_SKILL_NAME_LENGTH:
        parser.error(
            f"skill_name is {len(skill_name)} characters; "
            f"maximum is {MAX_SKILL_NAME_LENGTH}"
        )
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", skill_name):
        suggestion = normalize_skill_name(skill_name)
        suffix = f" Suggested name: {suggestion!r}." if suggestion else ""
        parser.error(
            "skill_name must use lowercase letters, digits, and single hyphens."
            f"{suffix}"
        )

    try:
        resources = parse_resources(args.resources)
    except ValueError as exc:
        parser.error(str(exc))
    if args.examples and not resources:
        parser.error("--examples requires --resources")

    try:
        skill_dir = init_skill(
            skill_name,
            args.path,
            resources,
            args.examples,
            args.manual_only,
        )
    except (FileExistsError, OSError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 1

    print(f"[OK] Initialized {skill_dir}")
    print(
        "Next: finish SKILL.md, remove unused placeholders, then run quick_validate.py."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
