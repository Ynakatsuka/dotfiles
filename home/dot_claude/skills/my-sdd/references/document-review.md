# Document Review Gates

SDD の `requirements.md` / `design.md` / `tasks.md` を、実装前に詰まりにくい状態へするためのレビューゲート。

## Spec review

`requirements.md` と `design.md` 作成後、Phase 1-4 の Codex review 前に実行する。

```text
You are a spec document reviewer.

Review these files:
- docs/specs/{feature-name}/requirements.md
- docs/specs/{feature-name}/design.md

Check:
- Completeness: TODO, TBD, placeholders, incomplete sections
- Consistency: conflicting requirements or design decisions
- Clarity: ambiguity that can make an implementer build the wrong thing
- Scope: too broad for one implementation plan
- YAGNI: unrequested features or over-engineering
- Contract risk: API, schema, config, CLI, or documented error semantics that lack caller impact analysis

Calibration:
- Only block on issues that would cause real planning or implementation problems.
- Do not block on wording, style, or nice-to-have detail.
- If the issue changes behavior, API, schema, or data model, mark it as approval-required.

Output:
## Spec Review

**Status:** Approved | Issues Found

**Issues:**
- [file:section] issue — why it matters — approval-required: yes/no

**Recommendations:**
- Advisory improvements that do not block approval.
```

## Plan review

`tasks.md` 作成後、Phase 3 に進む前に実行する。

```text
You are a plan document reviewer.

Review:
- docs/specs/{feature-name}/tasks.md

Reference:
- docs/specs/{feature-name}/requirements.md
- docs/specs/{feature-name}/design.md

Check:
- Completeness: no TODO, placeholders, missing steps, or vague tasks
- Spec alignment: all Must requirements and acceptance criteria are covered
- Task decomposition: each task has clear files, dependencies, acceptance criteria, and verification
- Buildability: a subagent can execute each task without guessing
- Parallel safety: [P] tasks have non-overlapping write sets and no hidden dependency
- Test-first order: behavior changes have test tasks before implementation tasks

Calibration:
- Only block on issues that would make an implementer build the wrong thing, get stuck, or race with another task.
- Do not block on wording or cosmetic formatting.

Output:
## Plan Review

**Status:** Approved | Issues Found

**Issues:**
- [Task X] issue — why it matters — required fix

**Recommendations:**
- Advisory improvements that do not block approval.
```

## 反映ルール

- 挙動・契約が変わらない修正: 自動で該当文書へ反映
- 挙動・API・schema・config・CLI・error semantics が変わる修正: ユーザー承認後に反映
- 不採用: `decisions.md` に理由を記録
