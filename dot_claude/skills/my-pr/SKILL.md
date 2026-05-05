---
name: my-pr
description: >-
  Unified pull request workflow: prepare a safe branch, run the integrated
  simplify workflow and parallel reviews, apply fixes, create/update a GitHub
  draft PR, and verify CI plus automated review comments before marking ready.
  Subcommands: `create` (simplify + PR, skip code review), `review`
  (parallel review only), `simplify` (simplify only), `verify`
  (existing PR checks/reviews only).
  Use when creating PRs, self-reviewing changes, simplifying PR changes, or
  requesting "PR作成", "レビュー", "簡素化". Do NOT use for responding to others'
  review comments or reviewing external repositories.
argument-hint: "[create|review|simplify|verify]"
---

# PR — Pull Request Workflow

PR 作成を安全に進めるため、ブランチ準備、簡素化、レビュー、修正、PR作成、PR後検証を明確に分ける。

## 0. モード判定

`$ARGUMENTS` の先頭を確認し、`references/commands.md` を読んで実行パスを決める。

| 引数 | 動作 |
|---|---|
| 空（デフォルト） | full PR workflow |
| `create` | simplify + PR, skip local code review |
| `review` | quality review + Required fixes, no PR/push |
| `simplify` | integrated simplify only, no PR/push |
| `verify` | existing PR checks/reviews only |

不明な引数の場合は停止してユーザーに確認する。

---

## 1. Safety gate

`verify` 以外では、`references/branching.md` を読み、変更対象の分離、protected branch / worktree 処理、upstream safety を確認する。

ここで対象変更と作業ブランチを確定するまで、simplify、review、PR作成へ進まない。

---

## 2. Base and PR state

`verify` 以外では base branch と既存 PR を確認する。base branch の取得に失敗した場合は推測で `main` にしない。

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git fetch origin "$BASE_BRANCH:$BASE_BRANCH"
git diff "$BASE_BRANCH"..HEAD --stat
git log "$BASE_BRANCH"..HEAD --oneline
```

既存 PR の有無を確認する。

```bash
if gh pr view --json number,title,state 2>/tmp/my-pr-view.err; then
  echo "Existing PR found."
elif rg -qi "no pull requests|not found" /tmp/my-pr-view.err; then
  echo "No existing PR for this branch."
else
  cat /tmp/my-pr-view.err
  exit 1
fi
```

---

## 3. Quality workflow

### 3-1. `create` / `simplify`

コードレビューをスキップするモードでは、`references/simplify/overview.md` を読み、integrated simplify を `apply` mode で実行する。特に指定がない場合は `/my-agent codex` で行う。

- `create`: simplify apply → 修正があれば commit → PR 作成/更新へ進む。
- `simplify`: simplify apply → 修正・検証・必要な commit まで行い、PR作成・push せず終了する。

### 3-2. デフォルト / `review`: 並列 quality review

`references/review.md` を読み、そこに定義された Reviewer A/B/C と統合ルールに従う。

最初に simplify apply を実行しない。先に apply すると、Claude/Codex が古い diff をレビューするため。

以下 3 つを同時に起動する。

- Reviewer A: integrated simplify review
- Reviewer B: Claude Code correctness review
- Reviewer C: Codex correctness review via `/my-agent codex`

### 3-3. 統合

`references/review.md` の Integration rules と Integration output に従う。3つの結果を重複排除し、各指摘を Required / Recommended / Not needed のどれか1つに分類する。

### 3-4. 修正

🔴 Required だけ自動修正する。🟡 Recommended はユーザー確認後に修正する。

| 変更の性質 | 対応 |
|---|---|
| タイポ、未使用 import、dead code、重複削除 | 修正する |
| 振る舞いが変わらない簡素化 | 修正する |
| バグ・セキュリティ修正 | root cause を確認して修正する |
| 振る舞い変更、API/schema/CLI/config 変更 | ユーザー確認後に修正する |
| 好み、style、clever one-liner 化 | 修正しない |

修正後は関連検証を実行し、修正を commit する。`review` はここで終了する。

---

## 4. PR create / update

`review` / `simplify` の場合はスキップする。

`references/pr-body.md` を読み、PR title/body を作る。push 前には `references/branching.md` の Push destination safety を実行する。

既存 PR がなければ draft PR を作成し、既存 PR があれば本文を更新する。

---

## 5. Verify and ready

デフォルト、`create`、`verify` で実行する。`review` / `simplify` ではスキップする。

`references/verify.md` を読み、checks polling、automated review 確認、必要な修正、ready 化を行う。

---

## 注意事項

- PR 本文は日本語で書く。
- draft PR を作成し、verify 後にだけ ready にする。
- `--assignee @me` を付ける。
- commit message は Conventional Commits 形式の英語。
- `create` でも integrated simplify apply は必ず実行する。
- デフォルト / `review` では integrated simplify review、Claude Code、`/my-agent codex` を並列実行し、統合後に修正する。
- Codex レビューは `/my-agent codex` を使う。
- fallback、default substitution、broad catch を追加しない。
- 好みの問題や style 指摘は修正対象にしない。
- テストが壊れる修正はしない。
- worktree 使用時は、PR 作成後も自動削除しない。
