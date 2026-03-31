---
name: my-disk-cleanup
description: |
  Clean up disk space by removing caches and unnecessary files on macOS and Ubuntu.
  Targets: Docker (images, build cache, volumes), package managers (Homebrew, apt, pip, npm, yarn),
  and temporary files (__pycache__, .mypy_cache, Xcode DerivedData).
  Reports disk usage before/after with freed space summary.
  Use when the user asks to free disk space, clean caches, or mentions "ディスク整理", "キャッシュ削除",
  "disk cleanup", "free space", "clean docker", "clean caches".
  Do NOT use for file organization, deduplication, or finding large files.
---

# Disk Cleanup

Cross-platform disk cleanup for macOS and Ubuntu. Cleans caches category-by-category with user confirmation, showing disk usage before and after.

## Workflow

### 1. Survey disk usage (dry run)

Run the cleanup script in dry-run mode to show current cache sizes without deleting anything:

```bash
bash $SKILL_DIR/scripts/cleanup.sh --dry-run
```

Present the results to the user organized by category. Highlight the largest categories.

### 2. Confirm categories with user

Ask which categories to clean. Available categories:
- `docker` — Docker images, build cache, volumes, dangling containers
- `brew` — Homebrew download cache (macOS)
- `apt` — APT package cache (Ubuntu)
- `pip` — pip download cache
- `npm` — npm cache
- `yarn` — yarn cache
- `tmp` — Temporary files: `__pycache__`, `.mypy_cache`, Xcode DerivedData (macOS)

Default: all detected categories. User can select a subset.

### 3. Execute cleanup

Run the script for selected categories:

```bash
# All categories
bash $SKILL_DIR/scripts/cleanup.sh

# Specific categories (comma-separated)
bash $SKILL_DIR/scripts/cleanup.sh --category docker,brew,pip
```

### 4. Report results

The script outputs a before/after comparison. Summarize:
- Disk available before and after
- Total space freed
- Per-category breakdown of what was cleaned

## Notes

- Docker cleanup uses `docker system prune -af --volumes` and `docker builder prune -af` — this removes ALL unused images, containers, volumes, and build cache. Warn the user before running.
- `sudo` is required for `apt-get clean` on Ubuntu.
- The `tmp` category runs `find` with `-maxdepth 4` from `$HOME` to avoid excessive traversal.
- ~/Library/Caches (macOS) is reported but NOT deleted automatically — only specific subdirectories (Xcode DerivedData, __pycache__, .mypy_cache) are removed.
