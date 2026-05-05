# PR Body

Use this reference when creating or updating a PR.

## Title

- Keep it under 70 characters.
- Use a concise user-facing summary.
- Do not include ticket IDs unless the branch or task context already uses one.

## Body template

Write the PR body in Japanese.

```markdown
## 概要

## 変更内容
-

## 変更理由

## 影響範囲

## テスト内容
- [ ]

## レビュー観点

## 関連情報
```

Omit sections that do not apply.

## Test content

List commands actually run and their results. If verification was not possible, state the exact reason.

Examples:

```markdown
## テスト内容
- [x] `pnpm test` — pass
- [x] `pnpm lint` — pass
```

```markdown
## テスト内容
- [ ] 未検証: このリポジトリに変更範囲向けの検証コマンドが明記されていませんでした
```

## Review focus

Mention risks that reviewers should prioritize:

- behavior changes
- compatibility
- security-sensitive paths
- migration or config impact
- intentionally skipped recommendations

## Create/update commands

Create a draft PR when none exists.

```bash
gh pr create --draft --title "TITLE" --body-file /tmp/pr-body.md --assignee @me
```

Update an existing PR body.

```bash
gh pr edit --body-file /tmp/pr-body.md
```
