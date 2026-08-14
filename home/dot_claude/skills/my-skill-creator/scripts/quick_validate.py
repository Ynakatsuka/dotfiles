#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.9"
# dependencies = ["pyyaml"]
# ///
"""Validate standard, portable, or Claude Code Agent Skills."""

import argparse
import re
import sys
from pathlib import Path

import yaml

STANDARD_PROPERTIES = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}
SHARED_EXTENSIONS = {"disable-model-invocation", "paths"}
CLAUDE_EXTENSIONS = {
    "when_to_use",
    "argument-hint",
    "arguments",
    "user-invocable",
    "disallowed-tools",
    "model",
    "effort",
    "context",
    "agent",
    "background",
    "hooks",
    "shell",
}
PROFILE_PROPERTIES = {
    "standard": STANDARD_PROPERTIES,
    "portable": STANDARD_PROPERTIES | SHARED_EXTENSIONS,
    "claude": STANDARD_PROPERTIES | SHARED_EXTENSIONS | CLAUDE_EXTENSIONS,
}


def load_yaml_mapping(file_path, label):
    try:
        value = yaml.safe_load(file_path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ValueError(f"Invalid YAML in {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise TypeError(f"{label} must contain a YAML mapping")
    return value


def parse_frontmatter(skill_md):
    content = skill_md.read_text(encoding="utf-8")
    match = re.match(r"^---\r?\n(.*?)\r?\n---(?:\r?\n|$)", content, re.DOTALL)
    if not match:
        raise ValueError("SKILL.md must start with YAML frontmatter between --- lines")
    try:
        frontmatter = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        raise ValueError(f"Invalid YAML in SKILL.md frontmatter: {exc}") from exc
    if not isinstance(frontmatter, dict):
        raise TypeError("SKILL.md frontmatter must contain a YAML mapping")
    return frontmatter


def validate_string(frontmatter, key, *, required=False, max_length=None):
    if key not in frontmatter:
        if required:
            raise ValueError(f"Missing '{key}' in frontmatter")
        return None
    value = frontmatter[key]
    if not isinstance(value, str):
        raise TypeError(f"'{key}' must be a string")
    value = value.strip()
    if not value:
        raise ValueError(f"'{key}' must not be empty")
    if max_length is not None and len(value) > max_length:
        raise ValueError(f"'{key}' is {len(value)} characters; maximum is {max_length}")
    return value


def validate_frontmatter(skill_path, frontmatter, profile):
    allowed = PROFILE_PROPERTIES[profile]
    unexpected = sorted(set(frontmatter) - allowed)
    if unexpected:
        raise ValueError(
            f"Unexpected frontmatter key(s) for profile '{profile}': {', '.join(unexpected)}. "
            f"Allowed: {', '.join(sorted(allowed))}"
        )

    name = validate_string(frontmatter, "name", required=True, max_length=64)
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", name):
        raise ValueError(
            f"'name' must use lowercase letters, digits, and single hyphens: {name!r}"
        )
    if skill_path.name != name:
        raise ValueError(
            f"'name' must match the parent directory: {name!r} != {skill_path.name!r}"
        )

    validate_string(frontmatter, "description", required=True, max_length=1024)
    validate_string(frontmatter, "license")
    validate_string(frontmatter, "compatibility", max_length=500)

    if "metadata" in frontmatter:
        metadata = frontmatter["metadata"]
        if not isinstance(metadata, dict):
            raise ValueError("'metadata' must be a mapping")
        invalid_metadata = [
            key
            for key, value in metadata.items()
            if not isinstance(key, str) or not isinstance(value, str)
        ]
        if invalid_metadata:
            raise ValueError("'metadata' keys and values must all be strings")

    if "allowed-tools" in frontmatter and not isinstance(
        frontmatter["allowed-tools"], str
    ):
        raise ValueError("'allowed-tools' must be a space-separated string")

    if "disable-model-invocation" in frontmatter and not isinstance(
        frontmatter["disable-model-invocation"], bool
    ):
        raise ValueError("'disable-model-invocation' must be true or false")

    if "paths" in frontmatter:
        paths = frontmatter["paths"]
        valid_string = isinstance(paths, str) and bool(paths.strip())
        valid_list = (
            isinstance(paths, list)
            and bool(paths)
            and all(isinstance(item, str) and item.strip() for item in paths)
        )
        if not (valid_string or valid_list):
            raise ValueError(
                "'paths' must be a non-empty string or list of non-empty strings"
            )


def validate_openai_policy(skill_path, frontmatter, profile):
    openai_yaml = skill_path / "agents" / "openai.yaml"
    allow_implicit = None
    if openai_yaml.exists():
        config = load_yaml_mapping(openai_yaml, "agents/openai.yaml")
        policy = config.get("policy")
        if policy is not None:
            if not isinstance(policy, dict):
                raise ValueError("'policy' in agents/openai.yaml must be a mapping")
            if "allow_implicit_invocation" in policy:
                allow_implicit = policy["allow_implicit_invocation"]
                if not isinstance(allow_implicit, bool):
                    raise ValueError(
                        "'policy.allow_implicit_invocation' in agents/openai.yaml "
                        "must be true or false"
                    )

    if profile != "portable":
        return

    manual_only = frontmatter.get("disable-model-invocation", False)
    if manual_only and allow_implicit is not False:
        raise ValueError(
            "Portable manual-only skills require agents/openai.yaml with "
            "policy.allow_implicit_invocation: false"
        )
    if not manual_only and allow_implicit is False:
        raise ValueError(
            "Invocation policies differ: Codex is manual-only but Claude Code and Cursor are not"
        )


def validate_skill(skill_path, profile="portable"):
    """Return a validation status and human-readable message."""
    skill_path = Path(skill_path)
    skill_md = skill_path / "SKILL.md"
    if not skill_md.is_file():
        return False, "SKILL.md not found"

    try:
        frontmatter = parse_frontmatter(skill_md)
        validate_frontmatter(skill_path, frontmatter, profile)
        validate_openai_policy(skill_path, frontmatter, profile)
    except (OSError, TypeError, ValueError) as exc:
        return False, str(exc)

    warnings = []
    if profile == "portable" and "allowed-tools" in frontmatter:
        warnings.append(
            "allowed-tools is experimental and is not enforced consistently by all clients"
        )
    if profile == "portable" and "paths" in frontmatter:
        warnings.append(
            "paths is used by Claude Code and Cursor but has no documented Codex equivalent"
        )

    message = f"Skill is valid for profile '{profile}'."
    if warnings:
        message += "\nWarnings:\n- " + "\n- ".join(warnings)
    return True, message


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("skill_directory")
    parser.add_argument(
        "--profile",
        choices=sorted(PROFILE_PROPERTIES),
        default="portable",
        help="Validation target; default: portable",
    )
    args = parser.parse_args()

    valid, message = validate_skill(args.skill_directory, args.profile)
    print(message)
    return 0 if valid else 1


if __name__ == "__main__":
    sys.exit(main())
