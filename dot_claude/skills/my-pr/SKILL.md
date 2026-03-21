---
name: my-pr
description: >-
  Pull request workflow: review, auto-fix, and create/update PRs.
  Default (no args): review → auto-fix → create PR.
  Subcommands: `create` (skip review), `review` (review only, no PR).
  Triggers on "/pr", "PR作成", "プルリク", "create PR", "pull request",
  "/review", "レビュー", "PRレビュー", "self-review", "セルフレビュー".
---

# PR — Pull Request Workflow

レビュー・自動修正・PR作成を統合したワークフロー。

## サブコマンド（最初に判定）

$ARGUMENTS を確認する:

| 引数 | 動作 |
|---|---|
| **なし（デフォルト）** | レビュー → 自動修正 → PR作成 |
| **`create`** | レビューなしでPR作成のみ |
| **`review`** | レビュー + 自動修正のみ（PR作成しない） |

---

## Phase 1: ブランチ検証（全サブコマンド共通）

```bash
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "staging" ]; then
  echo "ERROR: main/staging ブランチでは実行できません"
  exit 1
fi

git status --short
git fetch origin main:main 2>/dev/null || true
```

未コミットの変更がある場合はユーザーに確認する。

## Phase 2: 変更内容の把握

```bash
git diff main..HEAD --stat
git log main..HEAD --oneline

# Check if PR already exists
gh pr view --json number,title,state 2>/dev/null
```

---

## Phase 3: レビュー（`create` の場合はスキップ）

### 3-1: 並列レビューの実行

**Claude Code と Codex の 2つの Agent を同時に起動する（必ず並列実行）。**

#### Agent 1: Claude Code レビュー（Agent ツール）

Agent ツールで以下のプロンプトを渡す:

```
以下のブランチの変更をレビューしてください。

ブランチ: <BRANCH>
ベース: main

変更ファイル:
<FILE_LIST from git diff --name-only main..HEAD>

レビュー観点:
1. ロジックの正しさ（バグ、エッジケース、データ漏れ）
2. 設計（責務分離、抽象化レベル、DRY）
3. パフォーマンス（不要なループ、N+1、メモリ使用）
4. セキュリティ（ハードコード秘密情報、インジェクション）
5. テスト（カバレッジ、エッジケース）

各ファイルの変更差分を読み、問題を以下の形式で報告してください:

## 問題一覧

### 🔴 修正必須
- **ファイル:行番号** — 問題の説明と修正案

### 🟡 改善推奨
- **ファイル:行番号** — 改善の説明

### ✅ 良い点
- 良い実装のポイント
```

#### Agent 2: Codex レビュー（Bash ツール）

```bash
codex exec "Review the diff below. Focus on bugs, logic errors, security issues, and performance problems. For each issue, specify the file path and line number, severity (critical/warning), and a concrete fix suggestion. Output in markdown format.

$(git diff main..HEAD)"
```

### 3-2: レビュー結果の統合

両方の結果を受け取ったら:

1. **重複排除**: 同じ問題を指摘している場合はまとめる
2. **分類**:
   - 🔴 **修正必須**: バグ、セキュリティ問題、データ不整合
   - 🟡 **改善推奨**: パフォーマンス、可読性、設計の改善
   - ℹ️ **参考**: 好みの問題、将来的な検討事項
3. **フィルタリング**: 好みの問題や過剰な指摘は除外する

### 3-3: 統合結果の報告

```markdown
# レビュー結果: <BRANCH>

## 🔴 修正必須 (N件)
1. **file:line** — 問題と修正案
   - 出典: Claude / Codex / 両方

## 🟡 改善推奨 (N件)
1. **file:line** — 改善案

## ✅ 良い点
- ...
```

---

## Phase 4: 自動修正（`create` の場合はスキップ）

レビューで見つかった問題を修正する。

### 自動修正の判断基準

| 変更の性質 | 対応 |
|---|---|
| タイポ、明らかなバグ、未使用 import、フォーマット | **そのまま修正** |
| ロジック修正（振る舞いは変わらない） | **そのまま修正** |
| 振る舞いが変わる修正 | **ユーザーに確認してから修正** |
| アーキテクチャ・設計の変更 | **ユーザーに確認してから修正** |
| 🟡 改善推奨 | **修正しない**（ユーザーが求めた場合のみ） |

### 修正フロー

1. 🔴 の問題を上記基準で分類する
2. 「そのまま修正」対象をまとめて修正する
3. 「確認が必要」な修正はユーザーに提示し、承認を得てから修正する
4. 修正後、関連テストがあれば実行して確認する
5. 修正をコミットする（Conventional Commits 形式、英語）

---

## Phase 5: PR 作成 / 更新（`review` の場合はスキップ）

### PR 内容の生成

`git diff main..HEAD` を分析し、以下のテンプレートで日本語記述する。

```markdown
## 概要
<!-- このPRで実施した変更の概要 -->

## 変更内容
<!-- 変更した内容を箇条書き -->
-
-

## 変更理由
<!-- なぜこの変更が必要なのか -->

## 影響範囲
<!-- この変更により影響を受ける範囲 -->

## テスト内容
<!-- 実施したテストの内容 -->
- [ ]

## レビュー観点
<!-- レビュアーに特に確認してほしい点 -->

## 関連情報
<!-- 関連するチケット、ドキュメント、他のPR -->
```

不要なセクション（該当しない項目）は省略する。

### 新規作成

```bash
gh pr create --draft --title "タイトル" --body "内容" --assignee @me
```

### 既存 PR の更新

```bash
gh pr edit --body "更新内容"
```

---

## 注意事項

- PR 内容は日本語で書く
- デフォルトで `--draft` を付ける
- `--assignee @me` を常に付ける
- タイトルは簡潔に（70文字以内）
- コミットメッセージは Conventional Commits 形式（英語）
- 2つのレビューは **必ず並列実行** する
- Codex が利用できない場合は Claude Code のみでレビューを完了する
- 好みの問題（フォーマット、命名の趣味）は指摘しない
- テストが壊れる修正はしない
