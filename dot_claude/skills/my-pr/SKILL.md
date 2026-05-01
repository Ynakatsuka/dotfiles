---
name: my-pr
description: >-
  Unified pull request workflow: parallel review (Claude + Codex), auto-fix, and
  create/update GitHub PRs, then keep fixing CI and automated review findings
  until the PR is ready to merge. Default runs full flow (review → fix → create → verify).
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
| `$ARGUMENTS` が空（デフォルト） | 簡素化 → レビュー → 自動修正 → PR作成 → PR後検証 → Ready化 |
| `$0` = `create` | 簡素化 → PR作成 → PR後検証 → Ready化 |
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

**無関係な変更の分離:**

今回の作業と無関係な変更が混ざっていないか確認する。各ファイルの変更内容を見て、今回の目的に関連するかどうかを判断する。無関係な変更は対象ファイルリストから除外する。

**コミットルール:**

1. **対象の判断**: 会話の中で作成・変更したファイルのみを対象とする。無関係な変更はコミットしない
2. **論理的なまとまりでコミット**: 1つの目的 = 1コミット。機能追加と設定変更など性質が異なる変更は別コミットにする
3. **Conventional Commits 形式**（英語）でコミットメッセージを書く
4. **コミット前に `git diff --cached` で内容を確認する**

### 1-3: ブランチ戦略

#### 保護ブランチにいる場合

保護ブランチに直接コミット・push してはならない。ワークツリーを使って別ブランチで作業する。

**順序厳守**: 「ワークツリー作成 → コピー → 元ブランチを戻す → 確認」の順で実行する。先に元ブランチを戻すとコピー元が消える。戻す処理を忘れると元ブランチに差分が残る。

1. **ブランチ名を決める**: 変更内容に基づいた説明的な名前（例: `feat/improve-pr-skill`）
2. **変更ファイルを特定する**（元ブランチを触らない）:
   ```bash
   ORIG_REPO=$(pwd)
   CHANGED_FILES=$(git diff --name-only -- <related_files...>)          # unstaged 変更
   STAGED_FILES=$(git diff --cached --name-only -- <related_files...>)  # staged 変更
   # 未追跡ファイル（新規作成）のパスも別途控えておく: UNTRACKED_FILES
   ```
3. **ワークツリーを作成する**:

   パス規約は `<repo_root>-worktree/<sanitized_branch>` に揃える（既存 `gw` 関数および CCV の親プロジェクト紐付けと整合させるため）。ブランチ名のスラッシュはハイフンに置換する。

   ```bash
   SANITIZED_BRANCH="${BRANCH//\//-}"
   WORKTREE_DIR="${ORIG_REPO}-worktree/${SANITIZED_BRANCH}"
   git worktree add "$WORKTREE_DIR" -b "$BRANCH" HEAD
   ```
4. **変更ファイルをワークツリーにコピーする**（元ブランチは未変更のまま）:
   ```bash
   cd "$WORKTREE_DIR"
   for f in $CHANGED_FILES $STAGED_FILES $UNTRACKED_FILES; do
     mkdir -p "$(dirname "$f")"
     cp "$ORIG_REPO/$f" "./$f"
   done
   git diff --stat  # コピー結果を確認
   ```
   注意: パッチ（`git diff > file && git apply`）は差分形式の不一致や空パッチで壊れやすいため使わない
5. **元ブランチの作業ツリーを戻す**（コピー完了後に必ず実行）:
   ```bash
   git -C "$ORIG_REPO" reset HEAD -- $STAGED_FILES                       # staged 解除
   git -C "$ORIG_REPO" checkout -- $CHANGED_FILES $STAGED_FILES          # 変更を戻す
   for f in $UNTRACKED_FILES; do rm -f "$ORIG_REPO/$f"; done             # 未追跡は rm で削除
   ```
6. **元ブランチに差分が残っていないことを確認する**（必須・スキップ不可）:
   ```bash
   git -C "$ORIG_REPO" status --short
   ```
   出力が空でない場合は原因を調査して手動で処理する。空になるまで次に進まない。
7. **コミットルールに従ってワークツリー内でコミットする**
8. **以降の Phase はすべてワークツリー内で実行する**

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
# 一時ファイル名は単一の Bash 呼び出し内で作成から削除まで完結させる。
# $$ や $RANDOM は Bash ツールの呼び出しごとに変わるため、複数コマンドをまたいで参照してはならない。
DIFF_FILE="/tmp/pr-diff-$(git rev-parse --short HEAD).patch"
rm -f "$DIFF_FILE"
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

## Phase 7: PR 後検証・自動修正・Ready 化（`review` の場合はスキップ）

PR 作成または更新後、GitHub Actions と自動レビューが走る場合がある。PR は **draft のまま** にして、すべて成功・解消してから `ready to merge` に変更する。

### 7-1: PR 番号とブランチを確定

```bash
PR_NUMBER=$(gh pr view --json number -q .number)
HEAD_BRANCH=$(gh pr view --json headRefName -q .headRefName)
```

### 7-2: 完了条件

以下をすべて満たすまで loop する:

1. GitHub Actions が存在する場合、対象 PR の checks がすべて `pass` / `skipping` である
2. GitHub Actions の失敗・キャンセル・タイムアウトがない
3. Claude Code / Codex / Copilot などの自動 review が実行済みの場合、全 review thread を確認済みで対応対象の未解決指摘がない
4. 対応した修正が commit 済みで、remote branch に push 済みである
5. `gh pr ready "$PR_NUMBER"` が成功している

### 7-3: 監視 loop

最大 10 回まで実行する。各 iteration の冒頭で 60 秒待ち、GitHub 側の checks / reviews 反映を待つ。失敗や対応対象の review 指摘があれば 7-4 / 7-5 で修正して push し、次の iteration に戻る。all clear なら 7-6 に進む。

`gh pr checks --watch` は長時間 pending で外側の上限が効かなくなるため使わない。`--json` の `bucket` を polling して判定する。

```bash
CHECKS_CLEAR=0
CHECKS_NEED_FIX=0

for i in $(seq 1 10); do
  echo "Waiting for GitHub checks and automated reviews: iteration $i/10"
  sleep 60

  CHECKS_JSON=$(gh pr checks "$PR_NUMBER" --json name,bucket,state,workflow,link 2>/tmp/pr-checks.err)
  CHECK_STATUS=$?

  gh pr view "$PR_NUMBER" --json reviews,reviewDecision,comments,latestReviews
  printf '%s\n' "$CHECKS_JSON"

  if [ -n "$CHECKS_JSON" ] && printf '%s\n' "$CHECKS_JSON" | jq -e 'any(.[]; .bucket == "fail" or .bucket == "cancel")' >/dev/null; then
    echo "Checks failed or were cancelled. Continue to 7-4, fix root causes, push, then rerun this loop."
    CHECKS_NEED_FIX=1
    break
  elif [ -n "$CHECKS_JSON" ] && printf '%s\n' "$CHECKS_JSON" | jq -e 'any(.[]; .bucket == "pending")' >/dev/null; then
    echo "Checks are still pending. Continue waiting."
    continue
  elif [ -n "$CHECKS_JSON" ]; then
    echo "Checks are clear. Inspect all automated review threads before continuing to 7-6."
    CHECKS_CLEAR=1
    break
  elif [ "$CHECK_STATUS" -ne 0 ] && rg -qi "no checks|checks have not been created|not found" /tmp/pr-checks.err; then
    echo "No checks are configured for this PR. Continue to automated review inspection."
    CHECKS_CLEAR=1
    break
  elif [ "$CHECK_STATUS" -ne 0 ]; then
    cat /tmp/pr-checks.err
    echo "Could not inspect checks. Surface the error and stop."
    exit 1
  fi
done

if [ "$CHECKS_NEED_FIX" -eq 1 ]; then
  echo "Do not continue to 7-6. Execute 7-4, commit and push the fix, then rerun 7-3."
elif [ "$CHECKS_CLEAR" -ne 1 ]; then
  echo "Checks did not finish within the wait limit. Report pending check names and URLs, then stop."
  printf '%s\n' "$CHECKS_JSON" | jq -r '.[] | select(.bucket == "pending") | "\(.name) \(.link)"'
  exit 1
fi
```

`gh pr checks` が「checks が存在しない」ことを示す場合は GitHub Actions 未設定として扱い、レビュー確認に進む。存在する checks が `pending` の場合は待つ。`fail` / `cancel` の場合は 7-4 で修正する。10 回待っても `pending` が残る場合は、長時間実行中の check 名と run URL を報告して停止する。

### 7-4: GitHub Actions 失敗の修正

checks が失敗した場合:

1. 失敗した check 名を特定する
2. 失敗した workflow run の log を取得する
3. root cause を修正する
4. 関連テストをローカルで実行する
5. 修正を commit する（Conventional Commits 形式、英語）
6. `git push` する
7. 7-3 に戻る

```bash
gh pr checks "$PR_NUMBER"
gh run list --branch "$HEAD_BRANCH" --limit 10
gh run view <RUN_ID> --log-failed
```

失敗原因が flake や外部障害に見える場合も、まず log から再現性と影響範囲を確認する。retry は idempotent で、bounded で、最終失敗が表面化する場合だけ実行する。

### 7-5: 自動 review 指摘の修正

Claude Code / Codex / Copilot などの review がある場合、未解決コメントを確認する。

```bash
REVIEWS_CLEAR=0

gh pr view "$PR_NUMBER" --json reviews,comments,latestReviews,reviewDecision
REVIEW_COMMENTS_JSON=$(gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments")
REVIEW_THREADS_JSON=$(gh api graphql -f owner="$(gh repo view --json owner -q .owner.login)" -f repo="$(gh repo view --json name -q .name)" -F number="$PR_NUMBER" -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviews(first: 100) {
        nodes {
          author { login }
          body
          state
          url
        }
      }
      comments(first: 100) {
        nodes {
          author { login }
          body
          url
        }
      }
      reviewThreads(first: 100) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          isResolved
          comments(first: 20) {
            nodes {
              author { login }
              body
              path
              line
              url
            }
          }
        }
      }
    }
  }
}')

printf '%s\n' "$REVIEW_COMMENTS_JSON"
printf '%s\n' "$REVIEW_THREADS_JSON"

# Set this after classifying review threads, review bodies, and top-level comments.
: "${ACTIONABLE_REVIEW_FINDINGS:?Set actionable automated review finding count before continuing}"

case "$ACTIONABLE_REVIEW_FINDINGS" in
  ''|*[!0-9]*)
    echo "ACTIONABLE_REVIEW_FINDINGS must be a non-negative integer."
    exit 1
    ;;
esac

if [ "$ACTIONABLE_REVIEW_FINDINGS" -gt 0 ]; then
  echo "Actionable automated review findings remain. Fix them, push, then rerun 7-3."
else
  REVIEWS_CLEAR=1
fi
```

`reviewThreads.pageInfo.hasNextPage` が `true` の場合は `after: <endCursor>` を付けて次ページを取得する。`hasNextPage` が `false` になるまで全ページを確認してから未解決指摘数を判定する。
PR 全体の review body と top-level comments も同じ基準で分類する。LOW / nit / style / 好みの問題だけが残る場合は、対応しない理由を記録して `REVIEWS_CLEAR=1` とする。

対応基準:

| 指摘 | 対応 |
|---|---|
| HIGH / critical / 🔴 / 修正必須 | **必ず修正** |
| MEDIUM / middle / warning / 🟡 | **正しさ・保守性・運用安定性に効くものは修正** |
| LOW / nit / style | **原則対応しない** |
| 好みの問題 | **対応しない** |

修正した場合:

1. 指摘ごとに root cause を修正する
2. 関連テストを実行する
3. 修正を commit する（Conventional Commits 形式、英語）
4. `git push` する
5. 7-3 に戻る

### 7-6: Ready 化

7-2 の完了条件を満たしたら draft を解除する。

`CHECKS_CLEAR=1` かつ `REVIEWS_CLEAR=1` を確認してから実行する。どちらかが `1` でなければ 7-3 / 7-5 に戻る。

```bash
gh pr ready "$PR_NUMBER"
gh pr view "$PR_NUMBER" --json isDraft,reviewDecision,mergeStateStatus,statusCheckRollup
```

`isDraft` が `false` で、対象 checks と対応対象 review 指摘が clear であることを確認して完了する。

---

## 注意事項

- PR 内容は日本語で書く
- デフォルトで `--draft` を付け、Phase 7 が all clear になってから `ready to merge` に変更する
- `--assignee @me` を常に付ける
- タイトルは簡潔に（70文字以内）
- コミットメッセージは Conventional Commits 形式（英語）
- 2つのレビューは **並列実行** する
- Codex レビューは必ず実行する（スキップ不可）。`codex` コマンドが見つからない場合は、mise が管理するパス（`~/.local/share/mise/installs/` 以下）を確認し、フルパスで実行を試みる。それでも見つからない場合はユーザーに報告して対処を求める
- GitHub Actions が存在する場合は、すべて成功するまで自動修正・commit・push を繰り返す
- Claude Code / Codex などの自動 review が走る場合は、HIGH 以上と対応価値のある MEDIUM / middle を自動修正する
- 好みの問題（フォーマット、命名の趣味）は指摘しない
- テストが壊れる修正はしない
- ワークツリー使用時は、ワークツリー内で作業を続ける。PR 作成後も修正が必要になる場合があるため、ワークツリーは自動削除しない
