---
name: my-release-note
description: >-
  Generate release notes from merged PR history and commits.
  Categorizes changes and creates GitHub releases.
  Triggers on "/release-note", "リリースノート", "release note", "リリース作成".
---

# Release Note — Release Note Generator

マージ済み PR とコミット履歴からリリースノートを生成する。

## 手順1: 情報収集

```bash
# Get last release tag
LAST_TAG=$(gh release list --limit 1 --json tagName -q '.[0].tagName')

# Get merged PRs since last release
gh pr list --state merged --limit 50 --json number,title,body,mergedAt,author,labels,url

# Get commit history since last release
git log ${LAST_TAG}..HEAD --oneline --pretty=format:"%h %s (%an, %ad)" --date=short

# Get PR-commit associations
gh pr list --state merged --limit 50 --json number,title,mergeCommit
```

## 手順2: バージョン番号の決定

- 前回リリース: `$LAST_TAG`
- セマンティックバージョニングに基づいて決定:
  - **MAJOR**: 破壊的変更あり
  - **MINOR**: 新機能追加
  - **PATCH**: バグ修正のみ

## 手順3: 変更の分類

PR タイトル・説明・コミットメッセージを分析し、以下のカテゴリに分類:

| カテゴリ | 対象 |
|---|---|
| ✨ New Features | 新機能・機能拡張 |
| 🐛 Bug Fixes | バグ修正 |
| 📝 Documentation | ドキュメント更新 |
| ♻️ Refactoring | 動作変更なしの構造改善 |
| ⚡ Performance | パフォーマンス改善 |
| 🔧 Maintenance | 依存関係更新、ツール変更 |
| 🚨 Breaking Changes | 互換性に影響する変更 |

**分析の優先順位**: PR タイトル・説明 > PR ラベル > コミットメッセージ

## 手順4: リリースノートの生成

```markdown
## vX.X.X - YYYY-MM-DD

### 🚨 Breaking Changes
- [変更内容] ([PR #N](URL))

### ✨ New Features
- [機能説明] ([PR #N](URL))
  - 補足詳細
  - 関連コミット: ([hash](URL))

### 🐛 Bug Fixes
- [修正内容] ([PR #N](URL))

### 📝 Documentation
- [更新内容] ([PR #N](URL))

### ♻️ Refactoring
- [リファクタ内容] ([PR #N](URL))

### 🔧 Maintenance
- [メンテ内容] ([PR #N](URL))

**Full Changelog**: https://github.com/owner/repo/compare/vOLD...vNEW
```

該当なしのカテゴリは省略する。

## 手順5: GitHub Release の作成

```bash
gh release create vX.X.X --title "vX.X.X" --notes "リリースノート内容"
```

## 注意事項

- 日本語で記述（技術用語は英語）
- PR と コミット両方のリンクを含める
- Breaking Changes は最上部に配置
- 空のカテゴリは省略
- 関連する PR はテーマごとにグループ化
