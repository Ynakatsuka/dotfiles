---
name: my-release-note
description: >-
  Generate release notes from merged PR history and commits.
  Categorizes changes by type and creates GitHub releases with semantic versioning.
  Use when the user asks to create a release or generate release notes
  (e.g., "リリースノート", "release note", "リリース作成").
  Do NOT use for changelogs, commit summaries, or PR descriptions.
argument-hint: "[version]"
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
- **デフォルトは PATCH**。迷ったら PATCH を選ぶ。
- セマンティックバージョニングに基づき、以下の基準で判定:
  - **MAJOR**: 破壊的変更あり（互換性を壊す API/設定/挙動の変更、削除）
  - **MINOR**: 利用者が認識できる**まとまった新機能**の追加。次のいずれかを満たす場合に限る:
    - 新しいコマンド・サブコマンド・スキル・公開 API の追加
    - 既存機能に対するユーザー向けの大きな拡張（オプション追加程度では不十分）
    - 複数の新機能 PR がまとまって含まれる
  - **PATCH**: 上記以外すべて。バグ修正、軽微な機能改善、既存機能の小さな拡張（フラグ追加・デフォルト値変更など）、ドキュメント、リファクタ、依存更新、内部変更
- 判断に迷う場合の指針:
  - 「新機能っぽいが小さい」→ PATCH
  - 「既存機能の挙動が少し変わる（互換性は保たれる）」→ PATCH
  - ユーザーから明示的に MINOR/MAJOR の指示があればそれに従う

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
