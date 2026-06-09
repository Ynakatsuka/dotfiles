---
name: my-epic
description: >-
  Orchestrate medium-to-large software development by turning a broad goal into
  an approved delivery tree of PR-sized subtasks and operational nodes,
  defining verification harnesses and gates for each node, then driving
  implementation, operation execution, and PR creation.
  Use when the user asks for large-scale development planning, PR decomposition,
  multi-PR execution, technical selection, or autonomous delivery of a broad
  epic. Do NOT use for a single small bug fix, one obvious PR, pure code
  review, or ordinary SDD work that already fits in one spec/PR.
---

# Epic Delivery Orchestrator

中〜大規模の開発ゴールを、検証可能な PR 単位のツリーへ分解し、ユーザー確認を挟みながら実装と PR 作成まで進める。

```text
Phase 0 Discover  →  Phase 1 Goal Contract  →  Phase 2 Architecture / Tech Choice
       ↓                       ↓                          ↓
Phase 3 Delivery Tree Decomposition  →  Phase 4 Harness Plan  →  Phase 5 Execute Nodes
       ↓
Phase 6 Program Closure
```

## 参照ファイル

- `references/templates.md` — `program.md` / `tree.md` / `leaves/*.md` / `operations/*.md` / `decisions.md` のテンプレート
- `references/harness.md` — PR leaf ごとの verification harness / gates 設計
- `references/execution.md` — PR leaf 実装、operation 実行、統合、PR 作成、失敗時停止条件

## 共通原則

- **このスキルの責務**: 分解、合意、依存管理、PR leaf 実装、operation 実行、検証ゲート、統合、PR 作成判断
- **実装方針**: まず自分で実装できる範囲を進める。必要なら Codex CLI などの外部実装エージェントを補助的に使う
- **PR leaf の定義**: 単独でレビュー・マージ可能で、受入基準と検証ゲートが明確な最小成果物
- **確認単位**: root goal、主要分岐、PR leaf goal、operation 実行内容、技術選定、破壊的変更、PR 作成前
- **自律性**: コード・テスト・docs・履歴から判断できることはユーザーに聞かない
- **停止方針**: 推測で進めない。失敗、曖昧な仕様、契約変更、検証不能は停止して確認する
- **外部スキル非依存**: 他スキル呼び出しを前提にしない。PR 作成、検証、状態更新はこのスキルの手順内で行う
- **補助エージェント**: Codex CLI などは、PR leaf が大きい、並列化したい、第二実装案が欲しい場合だけ使う

## 引数と状態検出

`$ARGUMENTS` を以下で解釈する。

| パターン | 動作 |
|---|---|
| `docs/epics/{name}` | 既存 epic を再開 |
| kebab-case 名 | `docs/epics/{name}` を作成または再開 |
| 自然言語要求 | Phase 0 の入力として epic 名を提案 |
| 空 | `docs/epics/` を走査し、進行中があれば提示。なければ要求を尋ねる |

`docs/epics/{name}/` を epic root とし、以下の有無で再開位置を決める。

1. `program.md` なし → Phase 0 / 1
2. `tree.md` なし → Phase 2 / 3
3. `leaves/*.md` なし → Phase 4
4. 未完 node あり → Phase 5
5. 全 node 完了 → Phase 6

開始時に必ず表示する。

```markdown
🔍 Epic 状態:
  📁 epic: docs/epics/{name}
  📄 program.md: ✅ / ❌
  🌳 tree.md: ✅ / ❌
  🍃 nodes: X/Y 完了

▶️ Phase {N} ({phase-name}) を開始します。
```

## Phase 0: Discover

大きな要求を受けたら、先に証拠を集める。

1. `git status --short` で作業状態を確認する
2. ADR / PRD / design docs / specs / README / package config / CI を探索する
3. 関連コード、テスト、既存の同種実装、公開 contract、schema、CLI/API を調べる
4. `gh issue` / `gh pr` が使える場合は関連 issue / PR / default branch を確認する
5. 調査から分かる制約、既存技術、危険な変更点を短くまとめる
6. 調査で確定できない仕様、優先順位、破壊的変更、検証方法を確認候補として列挙する
7. 各確認候補について「この回答ならこう進める」という分岐計画を作る

ユーザーに聞くのは、調査で確定できない product decision、優先順位、破壊的変更の許容だけにする。

## Phase 1: Goal Contract

`program.md` を作成する。テンプレートは `references/templates.md`。

必須項目:

- Problem / outcome
- Scope / non-goals
- Success metrics
- Constraints
- Public contracts that may change
- Data / migration / operational concerns
- Rollout and rollback expectations
- Decision brief before user questions
- Confirmation plan / decision tree
- Open decisions

### 確認計画

`program.md` 作成時は、Phase 0 の調査結果を先に埋めてから確認計画を作る。

1. 証拠で確定した内容と、証拠では確定できない内容を分ける
2. 不明点を `goal / scope / success metric / contract / data / rollout / priority` に分類する
3. 各不明点に、確認が必要な理由、選択肢、推奨案、分岐後の処理を記録する
4. ユーザー確認が不要な不明点は `Open decisions` に残すか、後続 Phase の調査タスクへ送る
5. 確認が必要な不明点だけを 1〜3 問に圧縮する

ユーザーに質問する前に、必ず判断材料を提示する。質問だけを先に出さない。

提示順:

1. 現状の理解: 要求、対象範囲、既存実装、制約
2. 調査で確定したこと: docs、コード、テスト、issue / PR から確認できた事実
3. 判断が必要な理由: 何が未確定で、どの Phase や delivery tree に影響するか
4. 選択肢ごとの影響: scope、PR 分割、検証、rollout / rollback、破壊的変更リスク
5. 推奨案: 推奨する選択肢と理由
6. 質問: ユーザーに決めてほしいこと

分岐計画の書き方:

```text
If the user chooses A, set X as in-scope and plan node Y.
If the user chooses B, mark X as non-goal and skip node Y.
If the user chooses C, stop Phase 3 until decision D-00N is resolved.
```

ユーザー確認では、各質問に以下を含める。

- 質問前の現状説明
- 判断に必要な事実と制約
- 何が不明か
- なぜ今確認が必要か
- 推奨選択肢
- 各選択肢を選んだ場合に次に何をするか

作成後、root goal と確認計画をユーザーに確認する。確認は 1〜3 問に絞り、各選択肢に推奨理由と分岐後の動きを付ける。

進めてよい条件:

- root goal が一文で説明できる
- non-goals が明記されている
- 成功判定がコード、テスト、データ、運用のいずれかで検証できる
- 確認計画が `program.md` に記録されている
- ユーザー回答ごとの分岐後の処理が明記されている
- 未決事項が `Open decisions` に分離されている

## Phase 2: Architecture / Tech Choice

技術選定は必要なときだけ行う。既存標準で十分な場合は「既存標準を採用」と記録し、比較表を作りすぎない。

技術選定が必要な条件:

- 新しい storage / queue / framework / external service を導入する
- 公開 API、schema、migration strategy、auth model、deployment topology が変わる
- 複数の実装方式があり、運用コストや rollback 性が大きく違う
- 既存 ADR と衝突する可能性がある

手順:

1. 既存 ADR / design docs / dependency policy を読む
2. 候補を 2〜4 個に絞る
3. `Cost / risk / migration / rollback / testability / owner familiarity` で比較する
4. 推奨案と却下案を `decisions.md` に記録する
5. 非自明な採用判断はユーザー確認を取る

破壊的 contract 変更が必要なら、編集前に停止して報告する。

## Phase 3: Delivery Tree Decomposition

`tree.md` を作成し、root goal を PR leaf と operation node を含む delivery tree へ分解する。

node 種別:

- **PR leaf**: コード、テスト、docs、config 変更をレビュー・マージする PR
- **Operation node**: PR ではなく、移行、backfill、初期 script 実行、feature flag 切替、外部サービス設定、手動確認などを行う作業
- **Verification node**: 既存状態、データ、監視、移行結果を確認するだけの作業
- **Decision node**: 実行前にユーザー、owner、運用担当の判断が必要な作業

分解の形:

```text
Root Initiative
├── Milestone A
│   ├── PR A1: Harness / contract tests
│   ├── PR A2: Backward-compatible implementation
│   ├── OP A3: Run initial backfill script
│   └── OP A4: Enable rollout flag
└── Milestone B
    ├── PR B1: Migration dry-run tooling
    ├── OP B2: Execute production migration
    └── VERIFY B3: Confirm data invariants and dashboards
```

分解ルール:

- 1 PR leaf = 1 PR
- PR leaf は 1〜3 日程度でレビュー可能なサイズを目安にする
- operation node は PR として表現しない。runbook、実行条件、証跡、rollback を持つ独立 node にする
- 先に harness / contract / migration dry-run / operation dry-run を置く
- データ移行、script 実行、public contract、rollout、cleanup を 1 つの PR leaf に混ぜない
- 依存関係は DAG として明記する
- 並列化できる node は file touch map、contract 影響、operational state 影響を分ける
- 1 PR で完結しない PR leaf はさらに分割する
- 手動作業、one-off script、migration、external console 操作が必要なら operation node を作る
- operation node は owner、実行環境、前提条件、exact command / action、expected evidence、rollback、実行してよい時間帯を明記する

ユーザー確認:

- milestone 分解ごとに確認する
- PR leaf の goal と検証ゲートを確認する
- operation node の実行内容、owner、timing、rollback、証跡を確認する
- 返答選択肢は `承認 / 分割 / 統合 / 順序変更 / スコープ変更` を基本にする
- ユーザー承認前に Phase 5 の実装・実行へ進まない

## Phase 4: Harness Plan

各 PR leaf について `leaves/{id}-{slug}.md` を作成する。各 operation node について `operations/{id}-{slug}.md` を作成する。テンプレートは `references/templates.md`、詳細基準は `references/harness.md`。

各 PR leaf に必ず含める:

- PR goal
- Out of scope
- Dependency and unlocks
- File touch map
- Contract impact
- Test gate
- Data gate
- Smoke gate
- Observability / rollout / rollback gate
- Spec compliance review gate
- Code quality review gate
- PR creation gate
- Implementation prompt
- Implementation record

各 operation node に必ず含める:

- Operation goal
- Out of scope
- Dependency and unlocks
- Owner / executor
- Execution environment
- Preconditions
- Exact command / manual action
- Expected evidence
- Data / operational impact
- Observability checks
- Rollback / abort procedure
- Approval gate
- Execution record

ハーネスが未整備なら、実装 PR leaf より前に `Harness PR` を作る。

PR 作成に進んでよい条件:

- 必須ゲートのコマンドまたは手順が明記されている
- 失敗時に何が未達か分かる
- データ変更の検証方法が明記されている
- スモークテストが人間の手順だけに依存していない
- spec compliance と code quality のレビュー観点が明記されている
- rollback / feature flag / cleanup の扱いが明記されている

operation node 実行に進んでよい条件:

- 前提 PR leaf と prerequisite operation node が完了している
- exact command / manual action が明記されている
- 実行対象環境、account、project、region、tenant などが明記されている
- dry-run、preview、backup、snapshot、または事前確認手順が必要なら明記されている
- expected evidence と rollback / abort procedure が明記されている
- 実行権限、owner、実行タイミング、ユーザー承認が明記されている

## Phase 5: Execute Nodes

承認済み node を依存順に実行する。並列 node は file touch map、contract、data / operational state が衝突しない場合だけ並列実行する。

PR leaf の実行手順:

1. `leaf.md` を読み、依存 leaf が完了していることを確認する
2. 作業ブランチまたは worktree の安全性を確認する
3. `references/execution.md` を読み、実装方法を決める
4. 補助エージェントを使った場合は、その結果を差分レビューする
5. leaf の Test / Data / Smoke gate を main 側で実行する
6. Spec compliance review → Code quality review の順で確認する
7. Implementation record を記録する
8. 失敗した場合は root cause を特定し、1 回だけ修正サイクルを回す
9. まだ失敗する、または設計矛盾がある場合は停止する
10. gate が全て通ったら `leaf.md` と `tree.md` を完了に更新する
11. `gh` で draft PR を作成・更新し、CI と自動レビューを確認する

operation node の実行手順:

1. `operation.md` を読み、依存 PR leaf / operation node が完了していることを確認する
2. 実行環境、account、project、region、tenant、権限を表示して確認する
3. precondition と dry-run / preview / backup / snapshot を実行する
4. ユーザー承認が必要な operation は、現状、判断材料、実行内容、rollback を提示してから確認する
5. exact command / manual action だけを実行する。未記載の補完や代替手順は使わない
6. expected evidence、data check、observability check を記録する
7. 失敗した場合は原因、影響範囲、rollback / abort 可否を確認し、推測で継続しない
8. gate が全て通ったら `operation.md` と `tree.md` を完了に更新する

停止条件:

- ユーザー承認前の leaf 実装または operation 実行
- public contract / schema / migration / CLI flag / config key の破壊的変更
- 検証ゲートが未定義または実行不能
- 実装が承認済み file touch map の範囲外を変更した
- operation が承認済み command / manual action の範囲外を必要とした
- operation の実行環境、権限、rollback、expected evidence が未定義
- spec compliance review で leaf goal 逸脱または受入基準漏れが見つかった
- テスト失敗が 1 修正で解消せず原因が不明
- fallback、mock continuation、default substitution が必要に見える

停止時は、対象 node、発生事象、観測済み証拠、選択肢、推奨案を提示する。

## Phase 6: Program Closure

全 PR leaf の PR が作成済みまたは merged になり、全 operation / verification node が完了したら、`program.md` に closure summary を追記する。

報告項目:

- 完了 node 数 / 全 node 数
- 作成 PR 一覧
- 実行した operation / migration / script 一覧
- 実行した検証
- 残った risk / follow-up
- 未マージ PR と blocking reason
- 削除すべき feature flag / cleanup 予定

## 完了メッセージ

```markdown
✅ Epic を更新しました。

📁 Epic: docs/epics/{name}
🌳 Tree: X milestones / Y nodes
🍃 Progress: A/Y nodes complete
🧪 Verified: lint / typecheck / unit / integration / data / smoke
🔗 PRs: #123, #124, ...

次:
  - 未完 node: {next_node}
  - Blocker: なし / {reason}
```
