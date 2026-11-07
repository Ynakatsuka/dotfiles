# Node Execution

Phase 5 で承認済み node ごとに使う。停止条件は `SKILL.md` の Phase 5 に従う。

## ブランチ安全性

PR leaf の実装前に `git branch --show-current` で現在のブランチを確認する。

- 保護ブランチ（`main` / `master` / `staging` / `develop` / `production` / `release/*`）上では実装しない。default branch を fetch し、`origin/<base>` を起点に feature branch または worktree を作ってから実装する

```bash
BASE_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git fetch origin "+refs/heads/${BASE_BRANCH}:refs/remotes/origin/${BASE_BRANCH}"
git switch -c "feat/{epic}-{leaf-id}" "origin/${BASE_BRANCH}"
# または
git worktree add -b "feat/{epic}-{leaf-id}" \
  "{repo_root}-worktree/feat-{epic}-{leaf-id}" "origin/${BASE_BRANCH}"
```

- ブランチを検出できない（detached HEAD など）場合は推測で進めず、停止してユーザーに確認する
- 保護パターン外の feature branch / worktree 上ならそのまま実装してよい

## 実装方式

PR leaf ごとに 1 つの mode を選び、leaf の実装記録に書く。

| Mode | 使う場面 | Notes |
|---|---|---|
| Subagent-delegated | 実装方針、file touch map、受入基準、検証 gate が確定している | Default。実装 subagent に委譲する |
| Explore-first | 実装経路が不明で codebase research が必要 | Read-only subagent の調査後に実装 node を再評価する |
| Direct-exception | Subagent を使えない、ユーザーが委譲を禁止した、または main が保持すべき作業 | 例外理由を実行 log に先に記録する。leaf が小さいことは理由にしない |

## PR leaf の委譲と統合確認

1. leaf ファイル、`ai/program.md`、`ai/tree.md` を読み、依存 node の完了と承認状態を確認する
2. leaf 実行部の `Implementation prompt` を埋め、利用可能な native subagent に渡す。specialized role があれば read-only 調査、低リスク実装、広範な実装の順に適した role を選ぶ。設定済みの model と reasoning effort はユーザー指示なしで上書きしない
3. subagent の実行中、main は同じ担当ファイルを編集しない
4. 返却後、main が `git diff` を読み、すべての編集が承認済み file touch map 内で、contract impact が leaf と一致することを確認する。公開・共有 contract に触れた場合は call site を探す
5. main が leaf の Test / Data / Smoke gate を直接実行する
6. main が leaf の Review gate 観点で Spec compliance と Code quality を 1 回の統合レビューとして確認する。公開 contract、security、migration、データ損失など高リスクな変更、またはユーザーが求めた場合だけ独立 reviewer を追加する。これらのレビューを delivery node にしない
7. 実行部の実装記録と実行 log を更新し、「PR 作成」へ進む

## Operation 実行

承認済み `ai/operations/{id}-{slug}.md` に使う。ファイル変更が必要でない限り、operation を PR として扱わない。

1. operation ファイル、`ai/program.md`、`ai/tree.md` を読み、依存 PR leaf と先行 operation の完了を確認する
2. current account、project、region、tenant、environment、executor identity を main が表示する
3. read-only の precondition check、dry-run / preview、evidence 収集は subagent に委譲し、main が結果を確認する
4. 承認前に、現状、確認済み事実、制約、選択肢ごとの影響、推奨案、exact command / action を承認ビューで示す
5. 承認済みで非破壊的かつ範囲が明確な command / action は executor subagent に委譲してよい。破壊的操作と外部状態変更は main が実行し、理由を実行 log に記録する
6. 承認済み command / action だけを実行する。代替 command、config path、branch、credential、endpoint、manual console step を推測で補わない
7. main が output、log、data check、metric、dashboard、trace など expected evidence を確認し、rollback の使用有無とともに実行記録へ書く
8. 失敗時は停止し、root cause の証拠、影響範囲、rollback / abort の状態、選択肢を報告する。partial execution は不足証跡とともに blocked または failed と記録し、黙って継続しない
9. 必須 evidence gate が通った後だけ `ai/tree.md` の node 表と `README.md` の進捗を更新する

## PR 作成

Test / Data / Smoke gate、Spec compliance review、Code quality review が完了し、ユーザーが PR 作成を承認した後に、`my-pr` スキルを `create` 引数で呼び出す。

handoff に含める情報:

- Leaf ID と goal
- Tree 上の依存関係
- Test / Data / Smoke gate の証跡
- Rollout と rollback
- 残存リスクと follow-up

`my-pr create` に任せる処理: simplify と変更後の検証、必要な commit と push、draft PR の作成または既存 PR の更新、CI・自動 review・required gate の確認。

完了後、leaf の実行部へ PR URL、最終 commit、`my-pr` の検証結果、blocker / follow-up を記録する。`my-pr` が成功した場合だけ `ai/tree.md` の node 表と `README.md` の進捗を更新する。
