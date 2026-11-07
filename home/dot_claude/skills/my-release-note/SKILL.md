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

マージ済み PR とコミット履歴からリリースノートを生成し、承認後に GitHub Release を作成する。

## 手順1: 情報収集

最後の公開リリースタグを `LAST_TAG` として取得する。失敗した場合（gh 未認証、リポジトリ外など）はエラーを報告して停止する。

```bash
gh release list --exclude-drafts --exclude-pre-releases --limit 1 --json tagName -q '.[0].tagName'
```

`LAST_TAG` が空（公開済みリリースがない）なら停止し、初回リリースの対象範囲（開始 commit / tag、または全履歴）をユーザーに確認する。空のまま `git log ${LAST_TAG}..HEAD` を実行すると空 range になり、変更ゼロと誤認する。

前回リリース以降のマージ済み PR とコミットを集める。PR はタグのコミット日時以降のマージ日で絞る:

```bash
gh pr list --state merged --search "merged:>$(git log -1 --format=%cI "$LAST_TAG")" --limit 200 \
  --json number,title,body,mergedAt,author,labels,url,mergeCommit
git log "${LAST_TAG}..HEAD" --pretty=format:"%h %s (%an, %ad)" --date=short
```

取得件数が `--limit` と同数なら打ち切りの可能性があるため、limit を上げて全件取得を確認する。

## 手順2: バージョン番号の決定

| 引数 | 挙動 |
|---|---|
| `patch` / `minor` / `major` | 自動判定せず、`LAST_TAG` の該当コンポーネントを上げ、下位を 0 にする |
| `vX.Y.Z` | そのまま採用 |
| なし | 下記の基準で自動判定 |

自動判定はセマンティックバージョニングに従い、迷ったら PATCH にする。

- **MAJOR**: 互換性を壊す API・設定・挙動の変更や削除
- **MINOR**: 利用者が認識できるまとまった新機能に限る。新しいコマンド・サブコマンド・スキル・公開 API、既存機能の大きな拡張（オプション追加程度では不十分）、または複数の新機能 PR
- **PATCH**: それ以外すべて。小さな新機能、互換性を保った挙動変更、フラグ追加やデフォルト値変更も含む

## 手順3: 分類と生成

PR タイトル・説明 > PR ラベル > コミットメッセージの優先順で分類し、関連 PR はテーマごとにまとめる。日本語で書き（技術用語は英語）、PR とコミットの両方にリンクする。各カテゴリの項目は上と同じ形式で書き、該当なしのカテゴリは省略する。

```markdown
## vX.X.X - YYYY-MM-DD

### 🚨 Breaking Changes
- [変更内容] ([PR #N](URL))

### ✨ New Features
- [機能説明] ([PR #N](URL))
  - 補足詳細
  - 関連コミット: ([hash](URL))

### 🐛 Bug Fixes
### 📝 Documentation
### ♻️ Refactoring
### ⚡ Performance
### 🔧 Maintenance

**Full Changelog**: https://github.com/owner/repo/compare/vOLD...vNEW
```

## 手順4: 承認と作成

リリースノート全文と新しいタグ名を提示し、明示的な承認を待つ。承認前に `gh release create` を実行しない。修正指示があれば反映して再提示する。

承認後、承認済みのノートを一時ファイルに書き出して作成する:

```bash
gh release create vX.X.X --title "vX.X.X" --notes-file <notes-file>
```
