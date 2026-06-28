---
name: my-pr
description: >-
  Unified pull request workflow: prepare a safe branch, run read-only review,
  fix Required findings, create/update a GitHub draft PR, and verify CI plus
  automated review comments.
  Subcommands: `create` (simplify + PR, skip code review), `review`
  (read-only findings only), `fix` (Required fixes + commit, no push),
  `simplify` (simplification only), `verify` (existing PR checks/reviews only).
  Use when creating PRs, self-reviewing changes, simplifying PR changes, or
  requesting "PR作成", "レビュー", "簡素化". Do NOT use for responding to others'
  review comments or reviewing external repositories.
argument-hint: "[create|review|fix|simplify|verify]"
---

# PR — Pull Request Workflow

PR 作成を安全に進めるため、ブランチ準備、簡素化、レビュー、修正、PR作成、PR後検証を明確に分ける。

## 0. モード判定

`$ARGUMENTS` の先頭を確認し、`references/commands.md` を読んで実行パスを決める。

| 引数 | 動作 |
|---|---|
| 空（デフォルト） | full PR workflow |
| `create` | simplify + PR, skip local code review |
| `review` | read-only quality review and finding integration |
| `fix` | Required fixes + verification + commit, no push |
| `simplify` | simplification-only apply, no PR/push |
| `verify` | existing PR checks/reviews only |

不明な引数の場合は停止してユーザーに確認する。

---

## 1. Safety gate

`verify` 以外では、`references/branching.md` を読み、変更対象の分離、protected branch / worktree 処理、worktree 移動後の元ブランチ cleanup、upstream safety を確認する。

ここで対象変更と作業ブランチを確定し、protected branch に対象差分が残っていないことを確認するまで、simplify、review、fix、PR作成へ進まない。

---

## 2. Base and PR state

`verify` 以外では base branch と既存 PR を確認する。base branch の取得に失敗した場合は推測で `main` にしない。

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git fetch origin "$BASE_BRANCH:$BASE_BRANCH"
git diff "$BASE_BRANCH"..HEAD --stat
git log "$BASE_BRANCH"..HEAD --oneline
```

PR scope を確認する。未コミット差分だけでなく、base branch との差分量を必ず報告する。

```bash
eval "$(${CLAUDE_SKILL_DIR}/scripts/prepare-review-artifacts.sh "$BASE_BRANCH")"
```

出力された `MY_PR_ARTIFACT_ENV` は再開用に source できる。`MY_PR_SCOPE_SUMMARY` を読む。`MY_PR_SCOPE_GATE` が `ok` 以外の場合は停止する。`large` はユーザーがそのブランチ全体を PR 対象として明示済みの場合だけ続行できる。`untracked` は対象ファイルを明示して stage / `git add -N` するか、対象外と確認してから artifact を作り直す。

既存 PR の有無を確認する。

```bash
ERR_FILE=$(mktemp -t my-pr-view.XXXXXX.err)
trap 'rm -f "$ERR_FILE"' EXIT
if gh pr view --json number,title,state 2>"$ERR_FILE"; then
  echo "Existing PR found."
elif rg -qi "no pull requests|not found" "$ERR_FILE"; then
  echo "No existing PR for this branch."
else
  cat "$ERR_FILE"
  exit 1
fi
```

---

## 3. Quality workflow

### 3-1. `create` / `simplify`

コードレビューをスキップするモードでは、`references/simplify/overview.md` を読み、integrated simplify を `apply` mode で実行する。特に指定がない場合は `/my-agent codex` で行う。

- `create`: local correctness review なしで simplify apply → 修正があれば commit → PR 作成/更新へ進む。
- `simplify`: 簡素化専用。simplify apply → 修正・検証・必要な commit まで行い、PR作成・push せず終了する。

### 3-2. デフォルト / `review` / `fix`: read-only quality review

`references/review.md` を読み、そこに定義された Reviewer A/B/C と統合ルールに従う。

最初に simplify apply を実行しない。先に apply すると、Claude/Codex が古い diff をレビューするため。

`prepare-review-artifacts.sh` が作成した repo-local artifact を使う。`/tmp` の diff や「現在のファイル状態」レビューへ暗黙に切り替えない。

以下 3 つを同時に起動し、全て完了するまで統合しない。

- Reviewer A: integrated simplify review
- Reviewer B: Claude correctness review (Claude Code Agent when available; Claude CLI otherwise)
- Reviewer C: Codex correctness review via `/my-agent codex`

いずれかの reviewer が失敗、quota、permission、diff access 不可、timeout になった場合は review incomplete として停止する。別 reviewer や local review への代替、部分レビューでの PR 作成は、ユーザーが明示承認した場合だけ行う。

### 3-3. 統合

`references/review.md` の Integration rules と Integration output に従う。3つの結果を重複排除し、各指摘を Required / Recommended / Not needed のどれか1つに分類する。

background 実行した reviewer が残っている間は最終回答しない。やむを得ず待機に入る場合は、再開に必要な artifact path、reviewer output path、次の手順を保存し、CCV の background monitor が利用可能なら監視登録する。

`review` は read-only なのでここで終了する。ファイル編集、検証、commit、push、PR作成をしない。

### 3-4. Required fix

デフォルト / `fix` では、🔴 Required だけ修正する。🟡 Recommended は修正しない。

| 変更の性質 | 対応 |
|---|---|
| タイポ、未使用 import、dead code、重複削除 | 修正する |
| 振る舞いが変わらない簡素化 | 修正する |
| バグ・セキュリティ修正 | root cause を確認して修正する |
| 振る舞い変更、API/schema/CLI/config 変更 | 修正せず停止して報告する |
| 好み、style、clever one-liner 化 | 修正しない |

修正後は関連検証を実行し、修正を commit する。`fix` は push、PR作成、verify を行わずここで終了する。

---

## 4. PR create / update

`review` / `fix` / `simplify` の場合はスキップする。

`references/pr-body.md` を読み、PR title/body を作る。push 前には `references/branching.md` の Push destination safety を実行する。

既存 PR がなければ draft PR を作成し、既存 PR があれば本文を更新する。

---

## 5. Verify

デフォルト、`create`、`verify` で実行する。`review` / `fix` / `simplify` ではスキップする。

`references/verify.md` を読み、既存 PR の checks polling、automated review 確認、必要な修正を行う。ready 化は行わない。

---

## 注意事項

- PR 本文は日本語で書く。
- draft PR を作成する。ready 化は行わない。
- `--assignee @me` を付ける。
- commit message は Conventional Commits 形式の英語。
- `create` でも integrated simplify apply は必ず実行する。
- `review` は read-only。指摘の収集と統合だけを行う。
- read-only reviewer は repo 内外を問わずファイルを書かない。`.plans`、`/tmp`、`.tmp/my-pr` への追加メモも禁止する。main orchestrator が作る `.tmp/my-pr/` artifact だけは例外。
- `fix` は Required だけ修正・検証・commit し、push しない。
- デフォルトでは read-only review → Required fix → PR作成/更新 → verify の順に実行する。
- Codex レビューは `/my-agent codex` を使う。
- Claude correctness review は host-aware に実行する。Claude Code Agent が使えるセッションでは Agent を使い、それ以外では Claude CLI の `claude --permission-mode plan -p` を使う。
- Codex、Claude reviewer、diff artifact 取得のいずれかに失敗したら停止する。暗黙に他 reviewer や local review へ切り替えない。
- fallback、default substitution、broad catch を追加しない。
- 好みの問題や style 指摘は修正対象にしない。
- テストが壊れる修正はしない。
- worktree 使用時は、PR 作成後も自動削除しない。
- `.tmp/my-pr/` は local artifact 置き場。stage / commit しない。
