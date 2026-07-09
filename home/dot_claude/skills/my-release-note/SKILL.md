---
name: my-release-note
description: >-
  Generate release notes from merged PR history and commits.
  Categorizes changes by type and creates GitHub releases with semantic versioning.
  Use when the user asks to create a release or generate release notes
  (e.g., "リリースノート", "release note", "リリース作成").
  Do NOT use for changelogs, commit summaries, or PR descriptions.
argument-hint: "[patch|minor|major|<version>]"
---

# Release Note — Release Note Generator

マージ済み PR とコミット履歴からリリースノートを生成する。

## リリース状態(呼び出し時点のスナップショット)

- 最後の公開リリースタグ: !`gh release list --exclude-drafts --exclude-pre-releases --limit 1 --json tagName -q '.[0].tagName'`
- 直近のタグ: !`git tag --sort=-creatordate | head -n 5`

## 手順1: 情報収集

上記スナップショットの「最後の公開リリースタグ」を `LAST_TAG` として使う。注入値がエラー出力(gh 未認証、リポジトリ外など)の場合は、そのエラーを報告して停止する。

```bash
LAST_TAG=vX.Y.Z  # Set to the injected tag value above
```

`LAST_TAG` が空（公開済みリリースが存在しない）の場合は**ここで停止し、初回リリースの対象範囲（開始 commit / tag、または「全履歴」）をユーザーに確認する**。空の `LAST_TAG` のまま `git log ${LAST_TAG}..HEAD` を実行してはならない（`..HEAD` が空 range に化けて変更ゼロと誤認する）。

`LAST_TAG` が確定したら、前回リリース以降に絞って収集する:

```bash
# Cutoff = commit date of the last release tag
LAST_TAG_DATE=$(git log -1 --format=%cI "$LAST_TAG")

# Get merged PRs since last release (filtered by merge date)
gh pr list --state merged --search "merged:>$LAST_TAG_DATE" --limit 200 \
  --json number,title,body,mergedAt,author,labels,url

# Get commit history since last release
git log ${LAST_TAG}..HEAD --oneline --pretty=format:"%h %s (%an, %ad)" --date=short

# Get PR-commit associations
gh pr list --state merged --search "merged:>$LAST_TAG_DATE" --limit 200 \
  --json number,title,mergeCommit
```

取得件数がちょうど `--limit` と同数の場合は打ち切りの可能性があるため、limit を上げて再実行し、全件取得できたことを確認する。

## 手順2: バージョン番号の決定

引数 (`$1`) によって挙動が変わる:

| 引数 | 挙動 |
|---|---|
| `patch` / `minor` / `major` | 自動判定をスキップし、`$LAST_TAG` の対応コンポーネントを 1 つ上げる |
| `vX.Y.Z` 形式の明示バージョン | そのまま採用 |
| 引数なし | 下記の自動判定ロジックを使用 |

`patch`/`minor`/`major` を計算する例 (`$LAST_TAG=v1.2.3`):

```bash
# patch → v1.2.4 / minor → v1.3.0 / major → v2.0.0
IFS='.' read -r MAJ MIN PAT <<< "${LAST_TAG#v}"
case "$1" in
  patch) NEW_TAG="v${MAJ}.${MIN}.$((PAT + 1))" ;;
  minor) NEW_TAG="v${MAJ}.$((MIN + 1)).0" ;;
  major) NEW_TAG="v$((MAJ + 1)).0.0" ;;
esac
```

### 自動判定 (引数なしの場合)

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

## 手順5: ユーザー承認

生成したリリースノート全文と新バージョン（タグ名）をユーザーに提示し、**明示的な承認を待つ**。承認前に `gh release create` を実行しない。修正指示があれば反映して再提示する。

## 手順6: GitHub Release の作成

承認後、承認済みのノートをファイルに書き出し、`--notes-file` で作成する:

```bash
NOTES_FILE=$(mktemp -t release-notes.XXXXXX.md)
# Write the approved release notes into "$NOTES_FILE" first
gh release create vX.X.X --title "vX.X.X" --notes-file "$NOTES_FILE"
```

## 注意事項

- 日本語で記述（技術用語は英語）
- PR と コミット両方のリンクを含める
- Breaking Changes は最上部に配置
- 空のカテゴリは省略
- 関連する PR はテーマごとにグループ化
