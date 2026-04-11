---
name: my-pr
description: >-
  Unified pull request workflow: parallel review (Claude + Codex), auto-fix, and
  create/update GitHub PRs. Default runs full flow (review → fix → create).
  Subcommands: `create` (skip review), `review` (review only).
  Use when creating PRs, self-reviewing changes, or requesting "PR作成", "レビュー".
  Do NOT use for responding to others' review comments or reviewing external repositories.
argument-hint: "[create|review]"
---

# PR — Pull Request Workflow

レビュー・自動修正・PR作成を統合したワークフロー。

## サブコマンド（最初に判定）

`$ARGUMENTS` を確認する:

| 引数 | 動作 |
|---|---|
| `$ARGUMENTS` が空（デフォルト） | 簡素化 → レビュー → 自動修正 → PR作成 |
| `$0` = `create` | 簡素化 → PR作成 |
| `$0` = `review` | 簡素化 → レビュー → 自動修正（PR作成・push しない） |

---

## Phase 1: ブランチ検証と準備（全サブコマンド共通）

### 1-1: 現在の状態を確認

```bash
CURRENT_BRANCH=$(git branch --show-current)
git status --short
```

保護ブランチ: `main`, `master`, `staging`, `production`

### 1-2: 未コミットの変更の整理

未コミットの変更（staged / unstaged / untracked）がある場合、これまでの会話で行った変更を特定する。

**コミットルール:**

1. **対象の判断**: 会話の中で作成・変更したファイルのみを対象とする。無関係な変更はコミットしない
2. **論理的なまとまりでコミット**: 1つの目的 = 1コミット。機能追加と設定変更など性質が異なる変更は別コミットにする
3. **Conventional Commits 形式**（英語）でコミットメッセージを書く
4. **コミット前に `git diff --cached` で内容を確認する**

### 1-3: ブランチ戦略

#### 保護ブランチにいる場合

保護ブランチに直接コミット・push してはならない。ワークツリーを使って別ブランチで作業する。

1. **ブランチ名を決める**: 変更内容に基づいた説明的な名前（例: `feat/improve-pr-skill`）
2. **関連する変更のパッチを作成する**:
   ```bash
   # tracked ファイルの変更をパッチ化（前回の残りがあると noclobber で失敗するため事前削除）
   PATCH_FILE="/tmp/pr-changes-$$-$RANDOM.patch"
   git diff -- <related_files...> > "$PATCH_FILE"
   git diff --cached -- <related_files...> >> "$PATCH_FILE"
   ```
   未追跡ファイル（新規作成）はパッチに含められないため、パスを控えておく
3. **保護ブランチの作業ツリーを元に戻す**:
   ```bash
   git checkout -- <modified_files...>      # unstaged 変更を戻す
   git reset HEAD -- <staged_files...>      # staged を解除
   ```
4. **ワークツリーを作成する**:
   ```bash
   git worktree add /tmp/pr-worktree-<branch> -b <branch> HEAD
   ```
5. **ワークツリーでパッチを適用する**:
   ```bash
   cd /tmp/pr-worktree-<branch>
   git apply "$PATCH_FILE"
   # 未追跡ファイルは元のリポジトリからコピー
   cp <original_repo>/<new_file> ./<new_file>
   ```
6. **コミットルールに従ってコミットする**
7. **以降の Phase はすべてワークツリー内で実行する**

#### 保護ブランチでない場合

その場でコミットルールに従ってコミットする。

上流ブランチが保護ブランチでないことも確認する:

```bash
UPSTREAM=$(git rev-parse --abbrev-ref @{upstream} 2>/dev/null || true)
if [ -n "$UPSTREAM" ]; then
  UPSTREAM_BRANCH="${UPSTREAM#origin/}"
  for b in $PROTECTED_BRANCHES; do
    if [ "$UPSTREAM_BRANCH" = "$b" ]; then
      echo "ERROR: 上流ブランチが $b に設定されています"
      exit 1
    fi
  done
fi
```

## Phase 2: 変更内容の把握（全サブコマンド共通）

```bash
# Detect base branch dynamically
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
git fetch origin "$BASE_BRANCH:$BASE_BRANCH" 2>/dev/null || true

git diff "$BASE_BRANCH"..HEAD --stat
git log "$BASE_BRANCH"..HEAD --oneline

# Check if PR already exists (used in Phase 6 to decide create vs update)
gh pr view --json number,title,state 2>/dev/null
```

以降のフェーズでは `$BASE_BRANCH` をベースブランチとして使用する。

---

## Phase 3: コード簡素化（全サブコマンド共通）

`/simplify` スキルを実行する。

- `/simplify` スキルを必ず実行する（スキップ不可）
- `/simplify` による指摘があり修正した場合は、別のコミットとしてコミットする（Conventional Commits 形式、英語）

---

## Phase 4: レビュー（`create` の場合はスキップ）

### 4-1: 並列レビューの実行

**レビュー対象は PR 全体の変更（`$BASE_BRANCH..HEAD`）である。Phase 3 の simplify による変更だけをレビューするのではない。**

**Claude Code と Codex の 2つの Agent を同時に起動する（必ず並列実行）。**

#### Agent 1: Claude Code レビュー（Agent ツール）

Agent ツールで以下のプロンプトを渡す:

```
以下のブランチの変更をレビューしてください。

ブランチ: <BRANCH>
ベース: <BASE_BRANCH>

変更ファイル:
<FILE_LIST from git diff --name-only $BASE_BRANCH..HEAD>

レビュー観点（コード品質・効率は /simplify で対応済みなので除外）:
1. ロジックの正しさ（バグ、エッジケース、データ漏れ）
2. セキュリティ（ハードコード秘密情報、インジェクション）
3. テスト（カバレッジ、エッジケース）

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

diff を一時ファイル経由で渡す（大きな diff でもシェル引数長制限に引っかからないようにする）。

```bash
# mktemp はファイルを事前作成するため noclobber 環境で > が失敗する。
# 代わりに未作成のユニークパスを使う。
DIFF_FILE="/tmp/pr-diff-$(git rev-parse --short HEAD)-$$-$RANDOM.patch"
git diff "$BASE_BRANCH"..HEAD > "$DIFF_FILE"
codex exec "Review the diff in the file $DIFF_FILE. Focus on bugs, logic errors, and security issues. Code quality and efficiency have already been reviewed separately, so skip those. For each issue, specify the file path and line number, severity (critical/warning), and a concrete fix suggestion. Output in markdown format."
rm -f "$DIFF_FILE"
```

### 4-2: レビュー結果の統合

両方の結果を受け取ったら:

1. **重複排除**: 同じ問題を指摘している場合はまとめる
2. **分類**:
   - 🔴 **修正必須**: バグ、セキュリティ問題、データ不整合
   - 🟡 **改善推奨**: パフォーマンス、可読性、設計の改善
   - ℹ️ **参考**: 好みの問題、将来的な検討事項
3. **フィルタリング**: 好みの問題や過剰な指摘は除外する

### 4-3: 統合結果の報告

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

## Phase 5: 自動修正（`create` の場合はスキップ）

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

## Phase 6: PR 作成 / 更新（`review` の場合はスキップ）

### PR 内容の生成

`git diff $BASE_BRANCH..HEAD` を分析し、以下のテンプレートで日本語記述する。

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

Phase 2 で PR が存在しなかった場合:

```bash
gh pr create --draft --title "タイトル" --body "内容" --assignee @me
```

### 既存 PR の更新

Phase 2 で PR が既に存在していた場合:

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
- 2つのレビューは **並列実行** する
- Codex レビューは必ず実行する（スキップ不可）。`codex` コマンドが見つからない場合は、mise が管理するパス（`~/.local/share/mise/installs/` 以下）を確認し、フルパスで実行を試みる。それでも見つからない場合はユーザーに報告して対処を求める
- 好みの問題（フォーマット、命名の趣味）は指摘しない
- テストが壊れる修正はしない
- ワークツリー使用時は、ワークツリー内で作業を続ける。PR 作成後も修正が必要になる場合があるため、ワークツリーは自動削除しない
