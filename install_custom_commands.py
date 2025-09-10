#!/usr/bin/env python3
"""Install custom commands from dot_codex/prompts to Claude or Cursor directories.

This script copies command files from the dotfiles repository to the appropriate
directories for Claude (.claude/commands) or Cursor (.cursor/commands).
"""

import argparse
import shutil
import sys
from pathlib import Path
from typing import Literal


def get_dotfiles_path() -> Path:
    """Get the path to the dotfiles directory."""
    script_path = Path(__file__).resolve()
    return script_path.parent


def get_source_commands_path() -> Path:
    """Get the path to the source commands directory."""
    return get_dotfiles_path() / "dot_codex" / "prompts"


def get_target_commands_path(
    base_path: Path, tool: Literal["claude", "cursor"]
) -> Path:
    """Get the target commands directory for the specified tool.

    Args:
        base_path: Base directory where to install commands
        tool: Tool type ('claude' or 'cursor')

    Returns:
        Path to the commands directory
    """
    if tool == "claude":
        return base_path / ".claude" / "commands"
    else:  # cursor
        return base_path / ".cursor" / "commands"


def confirm_overwrite(file_path: Path) -> bool:
    """Ask user confirmation for overwriting an existing file.

    Args:
        file_path: Path to the file that would be overwritten

    Returns:
        True if user confirms overwrite, False otherwise
    """
    response = input(f"File '{file_path.name}' already exists. Overwrite? [y/N]: ")
    return response.lower() in ["y", "yes"]


def install_commands(
    target_dir: Path,
    tool: Literal["claude", "cursor"],
    overwrite: bool = False,
) -> None:
    """Install custom commands to the target directory.

    Args:
        target_dir: Target directory where to install commands
        tool: Tool type ('claude' or 'cursor')
        overwrite: Whether to overwrite existing files without asking
    """
    source_path = get_source_commands_path()
    target_path = get_target_commands_path(target_dir, tool)

    # Create target directory if it doesn't exist
    target_path.mkdir(parents=True, exist_ok=True)

    # Get all .md files from source directory
    command_files = list(source_path.glob("*.md"))

    if not command_files:
        print(f"No command files found in {source_path}")
        return

    print(f"Installing {len(command_files)} commands to {target_path}")
    print()

    installed = 0
    skipped = 0

    for source_file in command_files:
        target_file = target_path / source_file.name

        if target_file.exists():
            if overwrite:
                action = "Overwriting"
                do_copy = True
            else:
                if confirm_overwrite(target_file):
                    action = "Overwriting"
                    do_copy = True
                else:
                    action = "Skipping"
                    do_copy = False
                    skipped += 1
        else:
            action = "Installing"
            do_copy = True

        if do_copy:
            shutil.copy2(source_file, target_file)
            installed += 1
            print(f"{action}: {source_file.name}")

    print()
    print(f"Installation complete: {installed} installed, {skipped} skipped")


def main() -> int:
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Install custom commands from dotfiles to Claude or Cursor"
    )
    parser.add_argument(
        "directory",
        type=Path,
        help="Target directory where to install commands",
    )
    parser.add_argument(
        "tool",
        choices=["claude", "cursor"],
        help="Tool to install commands for",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Overwrite existing files without asking (default: ask for each file)",
    )

    args = parser.parse_args()

    # Validate target directory
    target_dir = args.directory.resolve()
    if not target_dir.exists():
        print(f"Error: Target directory '{target_dir}' does not exist")
        return 1

    if not target_dir.is_dir():
        print(f"Error: '{target_dir}' is not a directory")
        return 1

    # Validate source directory
    source_path = get_source_commands_path()
    if not source_path.exists():
        print(f"Error: Source commands directory '{source_path}' does not exist")
        return 1

    try:
        install_commands(target_dir, args.tool, args.overwrite)
        return 0
    except Exception as e:
        print(f"Error during installation: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
