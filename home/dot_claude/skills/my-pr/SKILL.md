---
name: my-pr
description: >-
  Unified pull request workflow: prepare a safe branch, run read-only review,
  fix Required findings, create/update a GitHub draft PR, and verify CI plus
  automated review comments.
  Subcommands: `create`, `review`, `fix`, `simplify`, and `verify`.
  Use when creating or reviewing PRs, self-reviewing changes, simplifying PR
  changes, or requesting "PR作成", "レビュー", "簡素化". Do NOT use for responding
  to review comments or a lightweight review of the current working diff
  without the PR workflow (use the built-in /code-review instead).
argument-hint: "[create|review|fix|simplify|verify]"
---

# PR — Pull Request Workflow

PR 作成を安全に進めるため、ブランチ準備、簡素化、レビュー、修正、PR作成、PR後検証を明確に分ける。

## リポジトリ状態(呼び出し時点のスナップショット)

```!
git status --short --branch
```

このスナップショットは初期判断にのみ使う。以後は規定のコマンド・スクリプトで取得する最新状態を正とする。

## 0. モード判定

$ARGUMENTS の先頭を確認し、references/commands.md を読んで実行パスを決める。

| 引数 | 動作 |
|---|---|
| 空（デフォルト） | full PR workflow |
| `create` | simplify + PR, skip local correctness review |
| `review` | read-only quality review and finding integration |
| `fix` | Required fixes + verification + commit, no push |
| `simplify` | simplification-only apply, no PR/push |
| `verify` | existing PR checks/reviews only |

不明な引数の場合は停止してユーザーに確認する。

bundled scripts は chezmoi により $HOME/.claude/skills/my-pr/ へ配置される。最初のスクリプト実行前に配置を検証する。

```bash
test -f "$HOME/.claude/skills/my-pr/SKILL.md"
test -x "$HOME/.claude/skills/my-pr/scripts/prepare-review-artifacts.sh"
test -x "$HOME/.claude/skills/my-pr/scripts/prepare-pr-context.sh"
```

## 1. Safety gate

`review` では references/branching.md の Review-only Safety gate を使う。protected branch 上でもその場でレビューし、worktree の移動・cleanup、reset、checkout、rm、stage / git add -N、commit、push、PR の変更を実行しない。main が作る .tmp/my-pr/ artifact だけが許可されるローカル書き込みである。

デフォルト、`create`、`fix`、`simplify` では references/branching.md の通常の protected branch / worktree 処理、worktree 移動後の元ブランチ cleanup、upstream safety を確認する。対象変更と作業ブランチを確定し、protected branch に対象差分が残っていないことを確認するまで、simplify、fix、PR作成へ進まない。

## 2. Base and PR state

`review` では既存の remote-tracking base ref だけを使う。base branch の取得に失敗した場合は推測で main にしない。fetch して ref を更新しない。既存の base ref を検証できない場合は停止する。

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
git diff "$BASE_REF"...HEAD --stat
git log "$BASE_REF"..HEAD --oneline
bash "$HOME/.claude/skills/my-pr/scripts/prepare-review-artifacts.sh" "$BASE_REF"
```

デフォルト、`create`、`fix`、`simplify` では base branch と既存 PR を確認する。base branch の取得に失敗した場合は推測で main にしない。

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git fetch origin "+refs/heads/$BASE_BRANCH:refs/remotes/origin/$BASE_BRANCH"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
git diff "$BASE_REF"...HEAD --stat
git log "$BASE_REF"..HEAD --oneline
bash "$HOME/.claude/skills/my-pr/scripts/prepare-review-artifacts.sh" "$BASE_REF"
```

ローカル protected branch ref を直接進める `git fetch origin "$BASE_BRANCH:$BASE_BRANCH"` は禁止する。

最後に出力された絶対パスを、この run の artifact state file として保持する。/absolute/path/to/artifact.env は必ずその実パスへ置き換える。latest-env.sh の推測や、前の shell call の環境変数へ依存しない。

```bash
bash "$HOME/.claude/skills/my-pr/scripts/prepare-pr-context.sh" "/absolute/path/to/artifact.env"
source "/absolute/path/to/artifact.env"
cat "$MY_PR_SCOPE_SUMMARY"
cat "$MY_PR_CONTEXT"
```

MY_PR_SCOPE_GATE が `ok` 以外の場合は停止する。`large` はユーザーがそのブランチ全体を PR 対象として明示済みの場合だけ続行できる。`review` で `untracked` または `large+untracked` なら、stage / git add -N や対象外化のための状態変更をせず停止して報告する。デフォルト、`create`、`fix`、`simplify` では、`untracked` の対象ファイルを明示して stage / git add -N するか、対象外と確認して artifact を作り直す。

MY_PR_CONTEXT_STATE=found の場合は、PR 本文、top-level comments、reviews、inline review comments を review 入力として扱う。no_existing_pr の場合は、PR 本文と過去のやり取りが存在しないことを明示し、推測で補わない。

## 3. Quality workflow

### `create` / `simplify`

references/simplify/overview.md を読み、native simplifier_apply に apply mode を委譲する。

- `create`: local correctness review なしで simplify apply → 修正があれば commit → PR 作成/更新へ進む。
- `simplify`: simplify apply → main による差分確認・検証・必要な commit を行い、PR作成・push せず終了する。

Codex host では agent_type: simplifier_apply と fork_turns: "none" を使う。model と reasoning_effort は指定しない。Claude Code host では native Agent に同じ自己完結 prompt を渡す。native subagent を起動できない場合は停止し、別の実行器へ切り替えない。simplifier_apply は commit、push、PR 操作をしない。main が差分確認、検証、commit を担当する。

### デフォルト / `review` / `fix`

references/review.md を読み、native reviewer と native simplifier を同時に起動して全結果を統合する。最初に simplify apply を実行しない。

main は prepare-review-artifacts.sh と prepare-pr-context.sh を実行し、repo-local artifact をレビュー範囲と変更内容の正とする。`reviewer` は下流影響を確認するため、関連する呼び出し元・契約・テストをread-onlyで追加調査できる。`simplifier` はartifactだけを使う。/tmp の diff や現在のファイル状態レビューへ暗黙に切り替えない。

Codex host では agent_type: reviewer と agent_type: simplifier、fork_turns: "none" を使う。model と reasoning_effort は指定しない。Claude Code host では同じ自己完結 prompt を native Agent に渡す。native subagent を起動できない場合は REVIEW_INCOMPLETE で停止する。別の実行器へ切り替えない。

小さい diff では2役を各1本、10,000行超または196,608 bytes超では split-review-chunks.sh で chunk 化し、各 chunk に2役を割り当てる。可能な限り並列に起動し、全 role・全 chunk の完了まで統合しない。失敗、欠損、入力不読は REVIEW_INCOMPLETE として停止する。単一ファイル上限による skip は COMPLETE_WITH_SKIPS とする。

references/review.md の統合規則と出力形式に従う。2役の結果を重複排除し、各指摘を Required / Recommended / Not needed のどれか1つに分類する。Signal は reviewer、simplify、multiple だけを使う。

`review` は read-only なのでここで終了する。ファイル編集、検証、commit、push、PR作成をしない。

デフォルト / `fix` では Required だけ修正する。Recommended は修正しない。振る舞い変更、API/schema/CLI/config 変更は修正せず停止して報告する。修正後は関連検証を実行し、修正を commit する。`fix` は push、PR作成、verify を行わずここで終了する。

## 4. PR create / update

`review` / `fix` / `simplify` の場合はスキップする。

references/pr-body.md を読み、PR title/body を作る。push 前には references/branching.md の Push destination safety を実行する。既存 PR がなければ draft PR を作成し、既存 PR があれば本文を更新する。

## 5. Verify

デフォルト、`create`、`verify` で実行する。`review` / `fix` / `simplify` ではスキップする。

references/verify.md を読み、既存 PR の checks polling、automated review 確認、必要な修正を行う。ready 化は行わない。

## 注意事項

- PR 本文は日本語で書く。
- draft PR を作成し、--assignee @me を付ける。
- commit message は Conventional Commits 形式の英語。
- review stage 中、main と subagent は product files を変更しない。main が作る .tmp/my-pr/ artifact だけは例外とする。
- fallback、default substitution、broad catch を追加しない。
- 好みの問題や style 指摘は修正対象にしない。
- テストが壊れる修正はしない。
- worktree 使用時は、PR 作成後も自動削除しない。
- .tmp/my-pr/ は local artifact 置き場。stage / commit しない。
