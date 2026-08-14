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
| Subagent-delegated | 実装方針、file touch map、受入基準、検証 gate が確定している | Default。実装 subagent に委譲する |
| Explore-first | 実装経路が不明で codebase research が必要 | Read-only subagent の調査後に実装 node を再評価する |
| Direct-exception | Subagent を使えない、ユーザーが委譲を禁止した、または main が保持すべき作業 | 例外理由を実行 log に先に記録する |

PR 作成・更新は `my-pr create` に委譲する。実装 node は subagent に委譲し、main は割り当て、レビュー、統合、最終 gate、状態更新を担う。

## Subagent 委譲

1. Main が leaf ファイル、`ai/program.md`、`ai/tree.md` を読み、依存関係と承認状態を確認する
2. 実装経路が不明なら read-only subagent に既存コード、tests、shared contracts、callers を調査させる
3. Main が node goal、file touch map、変更禁止範囲、受入基準、検証 gate、停止条件を確定する
4. 方針が確定した実装を、利用可能な実装 subagent に委譲する。subagent に再委譲させない
5. Subagent の実行中、main は同じ担当ファイルを編集しない
6. Main が返却された差分と報告を読み、承認済み file touch map と契約に一致することを確認する
7. Main が Test / Data / Smoke gates を実行する
8. Spec compliance review、Code quality review の順で確認し、実行部の実装記録と実行 log を更新する

書き込みを行う subagent を並列起動する場合は、各 subagent に隔離した worktree と重複しない write set を割り当てる。main が直接実装してよいのは `Direct-exception` だけであり、leaf が小さいこと自体は理由にしない。

## Operation 実行

承認済み `ai/operations/{id}-{slug}.md` node に使う。
Files を変更する必要がない限り、operation を PR として扱わない。

1. operation ファイル、`ai/program.md`、`ai/tree.md` を読む
2. 依存 PR leaves と prior operation nodes が完了していることを確認する
3. 関連する current account、project、region、tenant、environment、executor identity を main が表示する
4. Read-only の dry-run、preview、precondition checks、evidence 収集は subagent に委譲し、main が結果を確認する
5. 承認前に、main が現状、確認済み事実、制約、選択肢ごとの影響、推奨案、exact command / action を説明する
6. 承認済みで非破壊的かつ実行範囲が明確な command / action は executor subagent に委譲する。破壊的操作または外部状態変更は main が実行し、理由を実行 log に記録する
7. 承認済み command / action だけを実行する。代替 command、config path、branch、credential、endpoint、manual console step を推測しない
8. Main が output、log、data check、metric、dashboard、trace、その他 expected evidence を確認して記録する
9. 失敗した場合は停止し、root cause evidence、影響範囲、rollback / abort status、選択肢を報告する
10. Required evidence gates が通った後だけ実行記録、`ai/tree.md`、`README.md` の進捗を更新する

Partial operation 後に黙って継続しない。Partial execution は missing evidence とともに blocked or failed として記録する。

## Subagent prompt

利用可能な native subagent を優先し、`ai/leaves/{id}-{slug}.md` から self-contained prompt を渡す。実行環境に specialized role がある場合は、read-only 調査、低リスク実装、広範な実装の順に適した role を選ぶ。設定済みの model と reasoning effort をユーザー指示なしで上書きしない。

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
- Subagent に再委譲しないこと
- 不明点、契約変更、破壊的操作は実装せず blocker として返すこと

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
- Mode: Subagent-delegated | Explore-first | Direct-exception
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

Test / Data / Smoke gate、Spec compliance review、Code quality review が完了し、ユーザーが PR 作成を承認した後に、`my-pr` スキルを `create` 引数で明示的に呼び出す（`/my-pr create` と同等）。`git commit`、`git push`、`gh pr create`、`gh pr edit` を直接実行して代替しない。

`my-pr create` への handoff には以下を含める。

- Leaf ID and goal
- Tree dependency context
- Test / Data / Smoke gate evidence
- Rollout and rollback notes
- Remaining risks or follow-ups

`my-pr create` に以下を委譲する。

- Simplify と変更後の検証
- 必要な commit と push
- Draft PR の作成または既存 PR の更新
- CI、自動 review、required gates の確認

完了後、leaf の実行部へ PR URL、最終 commit、`my-pr` の検証結果、blocker / follow-up を記録する。`my-pr` が失敗した場合は直接コマンドへ切り替えず、対象 node を完了扱いにしない。

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
