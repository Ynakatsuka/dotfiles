---
name: my-epic
description: >-
  Manual-only orchestrator for medium-to-large software development. Turns a
  broad goal into PR-sized and operational nodes with verification gates, then
  coordinates approved execution across follow-up prompts. Activate only when
  the user explicitly invokes my-epic; once activated, keep orchestrating that
  epic for the rest of the session. Do NOT use for an uninvoked planning or
  implementation request, a single small bug fix, one obvious PR, pure code
  review, ordinary SDD work that fits in one spec/PR, or implementing an epic
  during the same first call that created it.
disable-model-invocation: true
argument-hint: "[epic-name|docs/epics/path|request]"
---

# Epic Delivery Orchestrator

中〜大規模の開発ゴールを、目的達成に必要な最小数の検証可能な node へ分解し、ユーザー確認を挟みながら実装と PR 作成まで進める。

## セッション中のオーケストレーター責務

このスキルは、ユーザーが `my-epic` を明示的に呼び出した場合だけ開始する。新規 epic を作成したセッションと、既存 epic のオーケストレーターとして呼ばれたセッションでは、同じ epic に関する後続 prompt でもこの責務を維持する。再呼び出しは不要。ユーザーが別の作業へ切り替えた場合は適用しない。

- **main の役割**: node 分解、構成最小化レビュー、依存関係、承認、subagent への割り当て、結果と差分のレビュー、統合、最終検証、epic 状態更新、完了判断
- **node 実行の既定**: PR leaf の調査・実装・テスト追加・修正と、委譲可能な operation / verification を subagent に実行させる。main が実装者を兼ねない
- **直接実行の例外**: subagent を使えない、ユーザーが委譲を禁止した、または承認・破壊的操作・外部状態変更・統合・最終検証など main が保持すべき作業に限る。例外理由を対象 node の実行 log に先に記録する
- **委譲契約**: node goal、対象ファイルまたは実行範囲、変更禁止範囲、受入基準、検証 gate、停止条件を渡す。subagent に再委譲させない
- **並列実行**: 依存関係がなく、write set と外部状態が衝突しない node だけを並列化する。書き込みを行う subagent には隔離した worktree と重複しない write set を割り当てる
- **main の確認**: subagent の報告をそのまま完了扱いにしない。main が差分、証拠、gate 結果を確認し、必要な最終検証を実行する

## PR 作成の委譲

PR leaf の draft PR を作成または更新するときは、必ず `my-pr` スキルを `create` 引数で明示的に呼び出す（`/my-pr create` と同等）。このスキルから `git commit`、`git push`、`gh pr create`、`gh pr edit` を直接実行して代替しない。

- 呼び出し条件: PR leaf の Test / Data / Smoke gate、Spec compliance review、Code quality review が完了し、PR 作成のユーザー承認がある
- 委譲する処理: simplify、必要な commit、push、draft PR の作成または更新、CI と自動レビューの確認
- 委譲前に渡す情報: leaf ID と goal、依存関係、検証結果、rollout / rollback、残存リスク
- 委譲後に記録する情報: PR URL、最終 commit、`my-pr` の検証結果、blocker / follow-up
- 失敗時: 直接コマンドへ切り替えず、`my-pr` が報告した失敗を対象 node の blocker として記録して停止する

## 初回呼び出しの境界

新規 epic を作成する最初の呼び出しでは、scope を epic 作成と承認待ちの提示だけに限定する。

- 実行してよいこと: Phase 0〜4 の調査、goal contract、delivery tree、harness plan、`docs/epics/{name}/` 配下の計画ドキュメント作成
- 実行してはいけないこと: Phase 5 の leaf 実装、operation 実行、draft PR 作成、実装エージェント起動、`references/execution.md` の読み込み
- 停止位置: 構成最小化レビューと `README.md` の更新を終え、承認ビューで epic の全体像と次に実装または実行する node を提示して終了する
- 再開条件: ユーザーが「実装して」「実行して」「node を進めて」「Phase 5 へ進んで」など、実装または operation 実行を明示した場合だけ Phase 5 に入る

既存 epic の再開でも、ユーザーの依頼が状態確認、計画更新、分解、承認ビュー作成だけなら Phase 5 に入らない。

```text
Phase 0 Discover  →  Phase 1 Goal Contract  →  Phase 2 Architecture / Tech Choice
       ↓                       ↓                          ↓
Phase 3 Delivery Tree Decomposition  →  Phase 4 Harness Plan  →  Phase 5 Execute Nodes
       ↓
Phase 6 Program Closure
```

## 参照ファイル

- `references/templates.md` — ドキュメント区分と `README.md` / `ai/` 配下各ファイルのテンプレート
- `references/planning.md` — Phase 1 の README / 判断表の書き方、Phase 3 の分解ルール詳細
- `references/harness.md` — PR leaf / operation node の verification harness / gates 設計
- `references/execution.md` — ブランチ安全性、PR leaf 実装、operation 実行、統合、PR 作成、失敗時停止条件

## ドキュメント区分

epic root は `docs/epics/{name}/`。人間向けと AI 用をディレクトリで分ける。

```text
docs/epics/{name}/
├── README.md            # 人間向け: 目的、実装・実行・確認の Phase 計画、成功基準、判断ダイジェスト
└── ai/                  # AI 用: 作業詳細と実行記録
    ├── program.md       # ゴール契約と判断表
    ├── tree.md          # delivery tree と node 状態の single source of truth
    ├── decisions.md     # 技術選定の判断記録
    ├── leaves/          # PR leaf の承認部と実行部
    └── operations/      # operation node の承認部と実行部
```

- 同じ詳細情報は 1 ファイルにだけ書く。node 状態は `ai/tree.md` の node 表、file touch map と gate 詳細は leaf / operation ファイルが正。`README.md` とチャットは、これらから作る承認用の要約とする
- 承認を求めるときは `README.md` を更新してから、承認判断に必要な情報をチャットだけで判断できる形にして提示する。`ai/` 配下を開くことを承認の前提にしない

## 承認ビュー

すべてのユーザー確認をこの形式で行う。承認は epic の範囲、作業順、外部影響を確定する重要な判断である。短さのために判断材料を省かない。

- チャットに、承認対象、現状と確認済み事実、目的と成功基準、対象と対象外、前提と未確定事項を示す
- 提案構成について、critical path、並列化できる部分、実行順を示す。各 node は、目的、成果物または実行範囲、依存関係、受入基準、検証方法、契約・データ・運用への影響、主なリスク、独立 node にする理由を示す
- 変更後に何を開始するか、まだ許可されていない外部状態変更や破壊的操作は何か、失敗時の停止・rollback 方針を示す
- 質問は一度に判断できる最大 3 件へまとめる。各質問は推奨案と理由を先に示し、選択肢ごとに scope、node、順序、リスクがどう変わるかを書く。情報量に一律の行数上限を置かない
- 返答選択肢は `承認 / 分割 / 統合 / 順序変更 / スコープ変更` を基本にする
- 再承認では、前回承認版からの差分と、差分を反映した承認対象の全体を示す。ユーザーに旧版との差分を頭の中で統合させない
- 詳細ファイルへのリンクは補足として付けてよいが、リンク先を読まなくても判断できる内容にする
- 結果は `README.md` の承認履歴と、`ai/program.md` の判断表または `ai/decisions.md` に記録する

## 共通原則

- **このスキルの責務**: 分解、合意、依存管理、node 実行の指揮、検証ゲート、統合、PR 作成判断と `my-pr` への handoff
- **記述言語**: epic ドキュメントは日本語で書く。コードコメント、docstring、commit message、コマンド、識別子は英語を維持する
- **実装方針**: 実装または operation 実行は、ユーザーが Phase 5 の開始または特定 node の実行を明示した後にだけ進める。実行可能な node 作業は subagent へ委譲する
- **PR leaf の定義**: 単独でレビュー・マージ可能で、受入基準と検証ゲートが明確な最小成果物
- **最小構成**: node 数ではなく、安全にレビュー・実行できる範囲で handoff と critical path が最小になる構成を選ぶ。独立した成果物、実行、承認、環境、rollout、rollback の境界がない作業は同じ node にまとめる
- **確認単位**: root goal、主要分岐、PR leaf goal、operation 実行内容、技術選定、破壊的変更、PR 作成前
- **自律性**: コード・テスト・docs・履歴から判断できることはユーザーに聞かない
- **停止方針**: 推測で進めない。失敗、曖昧な仕様、契約変更、検証不能は停止して確認する
- **スキル連携**: PR 作成・更新は `my-pr create` に委譲する。node の作業は利用可能な subagent に委譲し、検証結果と epic 状態は main が管理する
- **subagent 優先**: leaf の大小にかかわらず、境界と受入基準を定義できる node 作業は subagent へ渡す

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

開始時に必ず表示する。ユーザー向け表示では、内部フェーズ名ではなく実装・実行・確認上の次作業を示す。

```markdown
🔍 Epic 状態:
  📁 epic: docs/epics/{name}
  📖 README.md（人間向け）: ✅ / ❌
  📄 ai/program.md: ✅ / ❌
  🌳 ai/tree.md: ✅ / ❌
  🍃 nodes: X/Y 完了

▶️ 次の作業: {実装・実行・確認上の次作業}
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

- `README.md`: 現在地、目的、root goal、実装・実行・確認の Phase 計画、成功基準、主要リスク、node 一覧、承認待ち事項、承認履歴
- `ai/program.md`: 状態、ゴール契約、スコープ、制約、既存情報、判断表、公開 contract、rollout / rollback 方針

README.md の Phase 計画の書き方、判断表の作り方（Phase 0 調査結果の反映、質問の圧縮、分岐後の処理の記法）、Phase 1 を進めてよい条件は `references/planning.md` の Phase 1 節に従う。root goal と質問の確認は承認ビュー形式で行う。

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

Delivery tree には、目的と成功基準の達成に必要な node だけを置く。初回実行、one-off script、migration、backfill、feature flag 切替、外部サービス設定など、PR の成果物とは別の実行が実際に必要な場合だけ operation node を作る。該当しない作業のための placeholder node や「不要」と記録するためだけの node は作らない。

node 種別:

- **PR leaf**: コード、テスト、docs、config 変更をレビュー・マージする PR
- **Operation node**: PR ではなく、移行、backfill、初期 script 実行、feature flag 切替、外部サービス設定、手動確認などを行う作業
- **Verification node**: 別の時点、環境、owner で既存状態、データ、監視、移行結果を確認し、その証跡が後続作業を独立して block する作業。実装直後のテストや同じ operation の結果確認は元 node の gate に含める
- **Decision node**: 計画承認では確定できず、将来の観測結果や別 owner の判断が後続作業を独立して block する作業。今の承認で決められる事項は承認待ち事項と判断記録で扱う

分解の形（milestone / PR / OP / VERIFY のツリー例）と分解ルールの詳細は `references/planning.md` の Phase 3 節に従う。

### 構成最小化レビュー

epic の新規作成後と、goal、scope、成功基準、delivery tree、harness の更新後に必ず行う。このレビュー自体を delivery node や README.md の Phase にしない。

1. 各 node を外した場合に、成功基準、正しさ、安全性、既存 contract のいずれが満たせなくなるか確認する。どれも弱まらない node は削除する
2. 隣接 node 間に独立した review / merge、実行環境、owner、承認、rollout、rollback の境界がなければ統合する
3. test、docs、config、同じ変更直後の検証は、独立して配布または実行する理由がない限り対象 PR leaf または operation node に含める
4. verification は元 node の gate で表現できない場合だけ独立 node にする。decision は今回の承認で解決できない場合だけ独立 node にする
5. 不要な直列依存を外し、競合しない作業は並列化する。ただし分割・統合・調整の時間が短縮時間を上回る並列化は行わない
6. 全成功基準が少なくとも 1 つの node と gate に対応し、全 node が少なくとも 1 つの成功基準または必須の安全条件に対応することを確認する

レビュー後の delivery tree を承認対象とする。安全な境界を保ったまま、PR 数、operation 数、handoff 数、critical path を最小にする。

ユーザー確認:

- `README.md` の Phase 計画、node 一覧、主要リスク、成功基準、承認対象の詳細を更新してから、承認ビュー形式で確認する
- `README.md` の Phase 計画は、delivery tree を作った後に「今回の目的を達成する実装・実行・テストの順序」へ言い換える。承認、tree 分解、harness plan などの内部作業を phase として載せない
- milestone 単位でまとめて確認してよい。operation node と破壊的変更を含む node は個別に明示する
- ユーザー承認前に Phase 5 の実装・実行へ進まない

## Phase 4: Harness Plan

各 PR leaf に `ai/leaves/{id}-{slug}.md`、各 operation node に `ai/operations/{id}-{slug}.md` を作成する。テンプレートは `references/templates.md`、詳細基準は `references/harness.md`。

各ファイルは「承認部」と「実行部」に分ける。承認判断に使うのは承認部だけ。該当しない gate は `n/a — 理由` と一行で書き、空欄のまま残さない。

- PR leaf 承認部: PR goal、依存関係、file touch map、contract impact、受入基準、検証 gate、review gate 観点
- operation 承認部: operation goal、依存関係、実行 scope、前提条件、実行手順、rollback / abort、承認 gate

ハーネスが未整備でも、対象 leaf 内の最小変更で検証可能なら同じ leaf に含める。複数 leaf が先に依存する共有 harness など、独立した merge 境界が必要な場合だけ `references/harness.md` の条件に従って `Harness PR` を作る。

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

main は承認済み node を依存順に割り当て、実行結果を統合する。並列 node は file touch map、contract、data / operational state が衝突しない場合だけ subagent に並列実行させる。

PR leaf の実行手順:

1. leaf ファイルを読み、依存 leaf が完了していることを確認する
2. `references/execution.md` の「ブランチ安全性」に従い、現在のブランチを検出する。保護ブランチ（`main` / `master` / `staging` / `develop` / `production` / `release/*`）上なら `origin/<base>` 起点の feature branch / worktree を先に作成し、検出に失敗したら停止してユーザーに確認する
3. `references/execution.md` を読み、subagent への割り当てと self-contained prompt を作る
4. 調査が必要なら read-only subagent、実装方針が確定しているなら実装 subagent に委譲する
5. main が subagent の結果と差分を確認し、承認済み file touch map 内であることを確認する
6. leaf の Test / Data / Smoke gate を main 側で実行する
7. main が Spec compliance と Code quality を 1 回の統合レビューで確認する。公開 contract、security、migration、データ損失など高リスクな変更、またはユーザーが求めた場合だけ独立 reviewer を追加する
8. 実行部の実装記録を記録する
9. 失敗した場合は root cause を特定し、同じ実装 subagent に 1 回だけ修正サイクルを依頼する
10. まだ失敗する、または設計矛盾がある場合は停止する
11. gate が全て通ったら leaf の実行記録を更新する。PR 作成が完了するまで node は完了扱いにしない
12. 「PR 作成の委譲」に従い、`my-pr` スキルを `create` 引数で呼び出す
13. `my-pr` の結果から PR URL、最終 commit、検証結果、blocker / follow-up を leaf の実行記録へ反映する
14. `my-pr` が成功した場合だけ `ai/tree.md` の node 表と `README.md` の進捗を更新する

operation node の実行手順:

1. operation ファイルを読み、依存 PR leaf / operation node が完了していることを確認する
2. 実行環境、account、project、region、tenant、権限を表示して確認する
3. read-only の precondition、dry-run / preview、evidence 収集は subagent に委譲し、main が結果を確認する
4. ユーザー承認が必要な operation は、main が承認ビュー形式で現状、実行内容、rollback を提示してから確認する
5. 承認済みで非破壊的かつ実行範囲が明確な command / manual action は executor subagent に委譲する。破壊的操作または外部状態変更は main が実行し、直接実行の理由を実行 log に記録する
6. exact command / manual action だけを実行する。未記載の補完や代替手順は使わない
7. main が expected evidence、data check、observability check を確認し、実行部に記録する
8. 失敗した場合は原因、影響範囲、rollback / abort 可否を確認し、推測で継続しない
9. gate が全て通ったら `ai/tree.md` の node 表と `README.md` の進捗を更新する

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
