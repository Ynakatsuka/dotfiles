# Node Execution

承認済み delivery node ごとにこの workflow を使う。
PR leaf は code change と draft PR を生む。
Operation node は migration、backfill、initial script、rollout、external console、cleanup、verification など、PR 自体ではない作業を実行する。

## Node 種別判断

実行前に node type を選ぶ。

| Type | 使う場面 | Output |
|---|---|---|
| PR leaf | Code、test、docs、config、schema file、script を変更して review する必要がある | Draft PR |
| Operation | 既存 command / script / manual action を環境に対して実行する必要がある | Execution record |
| Verification | 既存状態、data、log、metric、dashboard を確認するだけ | Evidence record |
| Decision | Product、rollout、owner、risk の判断がないと実行できない | Recorded decision |

## ブランチ安全性

PR leaf の実装を始める前に、現在のブランチを確認する。

```bash
CURRENT_BRANCH=$(git branch --show-current)
```

- `CURRENT_BRANCH` が保護ブランチ（`main` / `master` / `staging` / `develop` / `production` / `release/*`）に一致する場合は、保護ブランチ上で実装しない。先に `origin/<base>` を起点に feature branch または worktree を作成してから実装する。

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"

# Feature branch:
git switch -c "feat/{epic}-{leaf-id}" "origin/${BASE_BRANCH}"

# または worktree:
git worktree add -b "feat/{epic}-{leaf-id}" \
  "{repo_root}-worktree/feat-{epic}-{leaf-id}" "origin/${BASE_BRANCH}"
```

- `CURRENT_BRANCH` が空（detached HEAD など）でブランチ検出に失敗した場合は、推測で進めず停止してユーザーに確認する。
- 既に保護パターン外の feature branch / worktree 上にいる場合はそのまま実装してよい。

## 実装方式判断

PR leaf ごとに 1 つの mode を選び、leaf の実行 log に記録する。

| Mode | 使う場面 | Notes |
|---|---|---|
| Direct | leaf が小さく、file touch map が明確で、現在の agent が安全に実装できる | Default |
| Codex-assisted | leaf が大きいが境界が明確、または並列実装が有効 | Main agent が review と gate の責任を持つ |
| Explore-only | 実装経路が不明で codebase research が必要 | 明示 scope がない限り編集しない |

別の local skill 呼び出しを default path にしない。workflow は自己完結させる。

## 直接実装

1. leaf ファイル、`ai/program.md`、`ai/tree.md` を読む
2. 編集前に target files と最寄りの relevant tests を読む
3. Exported behavior を変える前に shared contracts と callers を探す
4. 承認済み file touch map の範囲だけ実装する
5. leaf 完了前に test を追加または更新する
6. Test / Data / Smoke gates を実行する
7. Spec compliance review、Code quality review の順で確認する
8. 実行部の実装記録と実行 log を更新する

## Operation 実行

承認済み `ai/operations/{id}-{slug}.md` node に使う。
Files を変更する必要がない限り、operation を PR として扱わない。

1. operation ファイル、`ai/program.md`、`ai/tree.md` を読む
2. 依存 PR leaves と prior operation nodes が完了していることを確認する
3. 関連する current account、project、region、tenant、environment、executor identity を表示する
4. 書かれている通りに dry-run、preview、backup、snapshot、precondition checks を実行する
5. 承認前に、現状、確認済み事実、制約、選択肢ごとの影響、推奨案、exact command / action を説明する
6. 承認済み command / action だけを実行する。代替 command、config path、branch、credential、endpoint、manual console step を推測しない
7. Output、log、data check、metric、dashboard、trace、その他 expected evidence を記録する
8. 失敗した場合は停止し、root cause evidence、影響範囲、rollback / abort status、選択肢を報告する
9. Required evidence gates が通った後だけ実行記録、`ai/tree.md`、`README.md` の進捗を更新する

Partial operation 後に黙って継続しない。Partial execution は missing evidence とともに blocked or failed として記録する。

## Codex 補助実装

Codex CLI を使う場合は、`ai/leaves/{id}-{slug}.md` から self-contained prompt を渡す。

Prompt には以下を含める。

- Repo path and current branch/worktree
- Leaf file path
- Goal and non-goals
- File touch map
- Existing implementation anchors
- Acceptance criteria
- Test / Data / Smoke gates
- No implicit fallback rule
- Required return format

Example command:

```bash
codex exec "<SELF_CONTAINED_PROMPT>"
```

Model name を hardcode しない。CLI default に任せる。

## Prompt 雛形

```text
Implement PR leaf {ID}: {title} in {repo_path}.

Read first:
- docs/epics/{epic}/ai/program.md
- docs/epics/{epic}/ai/tree.md
- docs/epics/{epic}/ai/leaves/{id}-{slug}.md
- {relevant existing files}

File touch map:
- ...

Do not edit outside the approved file touch map unless you stop and report why it is required.

Goal:
- ...

Non-goals:
- ...

Acceptance criteria:
- ...

Verification gates:
- Test:
- Data:
- Smoke:

Rules:
- Do not add fallback behavior, silent retries, broad exception swallowing, mock continuation, or default substitution.
- Do not change public API, schema, CLI/config keys, migration semantics, or documented error behavior beyond this leaf.
- If a required dependency, fixture, environment variable, or external service is missing, stop and report the exact blocker.
- Keep code comments, docstrings, commit messages, and README text in English.

Return:
1. Summary
2. Files changed
3. Tests run
4. Gate results
5. Review gate results
6. Blockers or follow-up
```

## 統合確認

PR leaf 実装後:

1. `git diff --stat` と `git diff` を確認する
2. すべての編集が承認済み file touch map 内であることを確認する
3. leaf gates を直接実行する
4. Public or shared contract に触れた場合は related call sites を探す
5. Code quality review の前に Spec compliance review を実行する
6. 実行部の実装記録と実行 log を更新する
7. Required gates がすべて通った後だけ `ai/tree.md` の node 表と `README.md` の進捗を更新する

Operation 実行後:

1. 実行記録と evidence を確認する
2. 実行した command / action が承認済み operation node と一致することを確認する
3. Data / smoke / observability evidence が expected results と一致することを確認する
4. Rollback を使ったか、不要だったことを記録する
5. Required evidence gates がすべて通った後だけ `ai/tree.md` の node 表と `README.md` の進捗を更新する

## Review gates

実装後、PR creation 前に実行する。
Spec compliance が通るまで code quality cleanup を始めない。

### Spec compliance review

- 承認済み PR goal だけを実装している
- すべての acceptance criteria を満たしている
- 余分な feature や scope creep がない
- Out-of-scope file changes がない
- Contract impact が承認済み leaf と一致している
- Test / Data / Smoke gates が実行済み、または明示的な blocking reason がある

### Code quality review

- Existing patterns に従っている
- Shared contracts and callers を確認している
- Error semantics を維持している
- Tests が実挙動を検証している
- Fallback behavior、silent retry、broad catch、mock continuation、default substitution を追加していない
- 実装が 1 PR として review 可能な大きさに収まっている

## 実装記録

Leaf ファイルの実行部に以下を更新する。

- Branch / worktree と PR URL
- Mode: Direct | Codex-assisted | Explore-only
- Summary
- Files changed
- Contracts changed
- Tests run
- Data checks run
- Smoke checks run
- Spec compliance review result
- Code quality review result
- Remaining risks / follow-ups

## PR 作成

`gh` で draft PR を作成または更新する。

Preflight:

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
BASE_REF="origin/$BASE_BRANCH"
git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
git rev-parse --verify "$BASE_REF^{commit}" >/dev/null
git diff "$BASE_REF"...HEAD --stat
git log "$BASE_REF"..HEAD --oneline
```

Base branch は remote-tracking ref（`refs/remotes/origin/...`）にのみ fetch し、比較は `origin/$BASE_BRANCH` に対して行う。`git fetch origin "$BASE_BRANCH:$BASE_BRANCH"` は実行しない。別 worktree で checked out された保護ブランチの ref だけが進み、その worktree/index が更新されず、マージ済みの remote 変更が staged / unstaged の逆差分として残るためである。

Existing PR check:

```bash
ERR_FILE=$(mktemp -t epic-pr-view.XXXXXX.err)
trap 'rm -f "$ERR_FILE"' EXIT
if gh pr view --json number,title,state 2>"$ERR_FILE"; then
  echo "Existing PR found."
elif grep -Eqi "no pull requests|not found" "$ERR_FILE"; then
  echo "No existing PR for this branch."
else
  cat "$ERR_FILE"
  exit 1
fi
```

PR body には以下を含める。

- Leaf ID and goal
- Tree dependency context
- Test / Data / Smoke gate evidence
- Rollout and rollback notes
- Remaining risks or follow-ups

CI、自動 review、required gates が green になるまで draft PR のままにする。

## 失敗時対応

黙って retry しない。原因が明確な場合だけ、1 回の bounded repair loop を許可する。

以下では停止してユーザーに確認する。

- 実装が承認済み file touch map 外を変更する必要がある
- Gate が未定義、実行不能、または unavailable credentials に依存する
- Operation execution が operation node に書かれていない command/action、environment、account、project、region、tenant、credential、console step を必要とする
- Operation execution が partial success、ambiguous output、missing evidence、unclear rollback status になった
- Test failure が 1 回の targeted fix 後も残る
- 実装に fallback behavior が必要になる
- 新しい technical decision が必要になる
- Node の split or merge が必要になる
