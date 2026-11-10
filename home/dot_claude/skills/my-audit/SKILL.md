---
name: my-audit
description: >-
  Read the whole project, find what is broken, inconsistent, inefficient, or no longer needed
  with evidence for each finding, fix only what is certain, and list the rest for review.
  Use for "全体監査", "棚卸し", "プロジェクト全体を見直して", "audit the project", "新モデルが出たので見直し",
  or when run unattended after a new model release. Do NOT use for reviewing a PR or diff
  (my-pr / code-review), investigating one specific bug (my-diagnose), or updating model IDs
  (my-update-models).
---

# Audit

Inventory the current repository, fix only what is certain, and list everything else for review. Never ask questions: when a point needs a decision, put it in the review list. Run to the end even when unattended.

## 1. Prepare

- Read `AGENTS.md`, `CLAUDE.md`, and `README*`; run `git ls-files` to learn the layout and stack.
- Run `git status --short`. Existing uncommitted changes belong to the user: do not edit, stage, or revert them. Edit only files that no pre-existing change touches.
- Work in the current branch's working tree. Create no branch; commit or push only if the user asked.
- Find the project's verification commands (tests, lint, types, build, repo-specific checks) and run them first to record the baseline. A failing baseline is a finding.

## 2. Find

Report a finding only with a location and evidence: command output or the result of a reference search (`rg` for callers, imports, or mentions). Drop guesses.

- **Broken**: failing tests, lint, type checks, or builds; dead links; missing references or imports; invalid config; scripts that cannot run; CI definition errors.
- **Inconsistent**: conflicting names, conventions, versions, or config values; docs that disagree with the implementation; one thing written several ways; duplicated settings.
- **Inefficient**: duplicated logic; slow or redundant processing or tests; unused dependencies; repeated manual steps.
- **Unneeded**: unreferenced files, functions, dependencies, or settings; workarounds whose reason has ended; old model IDs or version-pinned workaround code; expired TODOs.

For a large repository, split by area across read-only subagents and have each return findings with evidence. The main agent merges them, removes duplicates, and re-checks the evidence of any suspicious finding before use.

## 3. Fix

Fix a finding only if all of these hold:

- The evidence is confirmed.
- The impact is local and reversible.
- No public contract changes (API, CLI, config key, or a name used elsewhere).
- The relevant checks pass after the fix.

When in doubt, list it instead. Always list rather than fix: production dependency changes, irreversible deletions, external writes, and changes to existing fallbacks.

Apply fixes one at a time, serially, and run the relevant check after each. If a check fails because of your change, revert that change and list the finding.

## 4. Report

Answer in Japanese. Put a count summary first when the report is long. Create no report file in the repository.

1. **修正した項目**: location, what changed, and the check command with its result.
2. **レビュー用リスト**: a table with ID, 観点 (壊れている / 一貫性 / 非効率 / 不要), 場所, 証拠, 提案する修正, リスク.
3. **確認できなかった範囲と制限**: areas not read, checks not run, and the baseline state.

Report the list and the covered scope even when nothing was fixed.
