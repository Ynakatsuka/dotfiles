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

- `references/templates.md` — ドキュメント区分と `README.md` / `ai/` 配下各ファイルのテンプレート
- `references/harness.md` — PR leaf / operation node の verification harness / gates 設計
- `references/execution.md` — PR leaf 実装、operation 実行、統合、PR 作成、失敗時停止条件

## ドキュメント区分

epic root は `docs/epics/{name}/`。人間向けと AI 用をディレクトリで分ける。

```text
docs/epics/{name}/
├── README.md            # 人間向け: 承認に必要な情報だけの 1 画面ダイジェスト
└── ai/                  # AI 用: 作業詳細と実行記録
    ├── program.md       # ゴール契約と判断表
    ├── tree.md          # delivery tree と node 状態の single source of truth
    ├── decisions.md     # 技術選定の判断記録
    ├── leaves/          # PR leaf の承認部と実行部
    └── operations/      # operation node の承認部と実行部
```

- 同じ情報は 1 ファイルにだけ書く。node 状態は `ai/tree.md` の node 表、file touch map と gate 詳細は leaf / operation ファイルが正。`README.md` はその要約
- 承認を求めるときは `README.md` を更新してから、該当部分だけをチャットに提示する。`ai/` 配下の全文を人間に読ませない

## 承認ビュー

すべてのユーザー確認をこの形式で行う。

- チャット提示は 1 画面以内。冒頭に現状理解と確定事実を 3 行以内で示す
- 質問は最大 3 問。各質問は 5 行以内で、推奨案を先頭に置き、選択肢ごとの分岐後の処理を付ける
- 返答選択肢は `承認 / 分割 / 統合 / 順序変更 / スコープ変更` を基本にする
- 再承認では前回承認版との差分だけを示す
- 結果は `README.md` の承認履歴と、`ai/program.md` の判断表または `ai/decisions.md` に記録する

## 共通原則

- **このスキルの責務**: 分解、合意、依存管理、PR leaf 実装、operation 実行、検証ゲート、統合、PR 作成判断
- **記述言語**: epic ドキュメントは日本語で書く。コードコメント、docstring、commit message、コマンド、識別子は英語を維持する
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

`docs/epics/{name}/` の以下の有無で再開位置を決める。

1. `ai/program.md` なし → Phase 0 / 1
2. `ai/tree.md` なし → Phase 2 / 3
3. `ai/leaves/*.md` なし → Phase 4
4. 未完 node あり → Phase 5
5. 全 node 完了 → Phase 6

開始時に必ず表示する。

```markdown
🔍 Epic 状態:
  📁 epic: docs/epics/{name}
  📖 README.md（人間向け）: ✅ / ❌
  📄 ai/program.md: ✅ / ❌
  🌳 ai/tree.md: ✅ / ❌
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

`README.md`（人間向け）と `ai/program.md` を作成する。テンプレートは `references/templates.md`。

- `README.md`: 現在地、ゴール、主要リスク、node 一覧、承認待ち事項、承認履歴
- `ai/program.md`: 状態、ゴール契約、スコープ、制約、既存情報、判断表、公開 contract、rollout / rollback 方針

### 判断表の作り方

Phase 0 の調査結果を `ai/program.md` に埋めてから判断表を作る。

1. 証拠で確定した内容と確定できない内容を分ける
2. 不明点ごとに、今決める理由、選択肢、推奨案、分岐後の処理を判断表に記録する
3. ユーザーに聞くのは product decision、優先順位、破壊的変更の許容だけ。それ以外は `open` のまま後続 Phase の調査タスクへ送る
4. ユーザー確認が必要な不明点を最大 3 問に圧縮し、`README.md` の承認待ち事項へ転記する
5. 承認ビュー形式で root goal と質問を確認する

分岐後の処理の書き方:

```text
If the user chooses A, set X as in-scope and plan node Y.
If the user chooses B, mark X as non-goal and skip node Y.
```

進めてよい条件:

- root goal が一文で説明できる
- non-goals が明記されている
- 成功判定がコード、テスト、データ、運用のいずれかで検証できる
- 判断表に選択肢と分岐後の処理が記録されている
- ユーザー確認の結果が承認履歴と判断表に反映されている

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
4. 推奨案と却下案を `ai/decisions.md` に記録する
5. 非自明な採用判断は承認ビュー形式でユーザー確認を取る

破壊的 contract 変更が必要なら、編集前に停止して報告する。

## Phase 3: Delivery Tree Decomposition

`ai/tree.md` を作成し、root goal を PR leaf と operation node を含む delivery tree へ分解する。node 状態は `ai/tree.md` の node 表を single source of truth にする。

Delivery tree は、調査で「PR 以外の作業が不要」と確認できた場合を除き、PR leaf だけで完結させない。初回実行、one-off script、migration、backfill、feature flag 切替、外部サービス設定、手動確認、検証だけの作業を必ず operation / verification / decision node として検討し、不要なら理由を `ai/tree.md` に記録する。

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

- `README.md` の node 一覧（1 node 1 行）と主要リスクを更新してから、承認ビュー形式で確認する
- milestone 単位でまとめて確認してよい。operation node と破壊的変更を含む node は個別に明示する
- ユーザー承認前に Phase 5 の実装・実行へ進まない

## Phase 4: Harness Plan

各 PR leaf に `ai/leaves/{id}-{slug}.md`、各 operation node に `ai/operations/{id}-{slug}.md` を作成する。テンプレートは `references/templates.md`、詳細基準は `references/harness.md`。

各ファイルは「承認部」と「実行部」に分ける。承認判断に使うのは承認部だけ。該当しない gate は `n/a — 理由` と一行で書き、空欄のまま残さない。

- PR leaf 承認部: PR goal、依存関係、file touch map、contract impact、受入基準、検証 gate、review gate 観点
- operation 承認部: operation goal、依存関係、実行 scope、前提条件、実行手順、rollback / abort、承認 gate

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

1. leaf ファイルを読み、依存 leaf が完了していることを確認する
2. 作業ブランチまたは worktree の安全性を確認する
3. `references/execution.md` を読み、実装方法を決める
4. 補助エージェントを使った場合は、その結果を差分レビューする
5. leaf の Test / Data / Smoke gate を main 側で実行する
6. Spec compliance review → Code quality review の順で確認する
7. 実行部の実装記録を記録する
8. 失敗した場合は root cause を特定し、1 回だけ修正サイクルを回す
9. まだ失敗する、または設計矛盾がある場合は停止する
10. gate が全て通ったら `ai/tree.md` の node 表と `README.md` の進捗を更新する
11. `gh` で draft PR を作成・更新し、CI と自動レビューを確認する

operation node の実行手順:

1. operation ファイルを読み、依存 PR leaf / operation node が完了していることを確認する
2. 実行環境、account、project、region、tenant、権限を表示して確認する
3. precondition と dry-run / preview / backup / snapshot を実行する
4. ユーザー承認が必要な operation は、承認ビュー形式で現状、実行内容、rollback を提示してから確認する
5. exact command / manual action だけを実行する。未記載の補完や代替手順は使わない
6. expected evidence、data check、observability check を実行部に記録する
7. 失敗した場合は原因、影響範囲、rollback / abort 可否を確認し、推測で継続しない
8. gate が全て通ったら `ai/tree.md` の node 表と `README.md` の進捗を更新する

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

全 PR leaf の PR が作成済みまたは merged になり、全 operation / verification node が完了したら、`README.md` の完了サマリーに記入する。

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
