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

## オーケストレーターの責務

ユーザーが `my-epic` を明示的に呼び出したときだけ開始し、同じ epic に関する後続 prompt でも再呼び出しなしで責務を維持する。別の作業へ切り替わったら適用しない。

- **main の役割**: node 分解、構成最小化レビュー、依存関係、承認、subagent への割り当て、統合、最終検証、epic 状態更新、完了判断。subagent の報告をそのまま完了扱いにせず、差分、証拠、gate 結果を main が確認する
- **node 作業は subagent へ委譲する**: PR leaf の調査・実装・テストと、委譲可能な operation / verification は、leaf の大小にかかわらず subagent に渡す。main は実装者を兼ねない
- **直接実行の例外**: subagent を使えない、ユーザーが委譲を禁止した、または承認・破壊的操作・外部状態変更・統合・最終検証など main が保持すべき作業に限る。例外理由を対象 node の実行 log に先に記録する
- **委譲契約**: node goal、対象ファイルまたは実行範囲、変更禁止範囲、受入基準、検証 gate、停止条件を渡す。subagent に再委譲させない
- **並列実行**: 依存関係がなく write set と外部状態が衝突しない node だけを並列化し、書き込む subagent には隔離した worktree を割り当てる

## PR 作成の委譲

PR leaf の draft PR 作成・更新は、必ず `my-pr` スキルを `create` 引数で呼び出して行う（`/my-pr create` と同等）。`git commit`、`git push`、`gh pr create`、`gh pr edit` を直接実行して代替しない。`my-pr` が失敗したら直接コマンドへ切り替えず、対象 node の blocker として記録して停止する。呼び出し条件と handoff 内容は `references/execution.md` の「PR 作成」に従う。

## 初回呼び出しの境界

新規 epic を作成する最初の呼び出しは、epic 作成と承認待ちの提示までに限る。

- 実行してよいこと: Phase 0〜4 の調査、goal contract、delivery tree、harness plan、`docs/epics/{name}/` 配下の計画ドキュメント作成
- 実行してはいけないこと: Phase 5 の leaf 実装、operation 実行、draft PR 作成、実装エージェント起動、`references/execution.md` の読み込み
- 停止位置: 構成最小化レビューと `README.md` の更新を終え、承認ビューで全体像と次に実装・実行する node を提示して終了する
- 再開条件: ユーザーが「実装して」「実行して」「node を進めて」「Phase 5 へ進んで」など実装または operation 実行を明示した場合だけ Phase 5 に入る

既存 epic の再開でも、依頼が状態確認、計画更新、分解、承認ビュー作成だけなら Phase 5 に入らない。

## ドキュメント区分

epic ドキュメントは日本語で書く。コマンド、識別子、API 名、schema 名、外部固有名詞は英語のまま残す。

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

- 同じ詳細情報は 1 ファイルにだけ書く。node 状態は `ai/tree.md` の node 表だけで管理し、leaf / operation ファイルには持たせない。file touch map と gate 詳細は leaf / operation ファイルが正
- `README.md` とチャットはこれらから作る承認用の要約で、矛盾したら `ai/` 配下を正とする

## 承認ビュー

すべてのユーザー確認をこの形式で行う。承認は epic の範囲、作業順、外部影響を確定する判断なので、短さのために判断材料を省かない。`README.md` を更新してから提示し、`ai/` 配下やリンク先を開かなくてもチャットだけで判断できるようにする。

- 承認対象、確認済み事実、目的と成功基準、対象と対象外、前提と未確定事項
- critical path、並列化できる部分、実行順。各 node の目的、成果物または実行範囲、依存関係、受入基準、検証方法、契約・データ・運用への影響、主なリスク、独立 node にする理由
- 承認後に開始する作業、まだ許可されない外部状態変更や破壊的操作、失敗時の停止・rollback 方針
- 質問は一度に判断できる最大 3 件。推奨案と理由を先に示し、選択肢ごとに scope、node、順序、リスクがどう変わるかを書く。行数上限は置かない
- 返答選択肢は `承認 / 分割 / 統合 / 順序変更 / スコープ変更` を基本にする
- 再承認では、前回承認版からの差分と、差分を反映した承認対象の全体を示す
- 結果は `README.md` の承認履歴と、`ai/program.md` の判断表または `ai/decisions.md` に記録する

## 引数と状態検出

| `$ARGUMENTS` | 動作 |
|---|---|
| `docs/epics/{name}` | 既存 epic を再開 |
| kebab-case 名 | `docs/epics/{name}` を作成または再開 |
| 自然言語要求 | Phase 0 の入力として epic 名を提案 |
| 空 | `docs/epics/` を走査し、進行中があれば提示。なければ要求を尋ねる |

再開位置: `ai/program.md` なし → Phase 0 / 1、`ai/tree.md` なし → Phase 2 / 3、`ai/leaves/*.md` なし → Phase 4、未完 node あり → Phase 5、全 node 完了 → Phase 6。

開始時に次を表示する。次の作業は内部フェーズ名ではなく、実装・実行・確認上の作業で書く。

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

計画の前に、作業状態、ADR / design docs / specs、関連コードとテスト、公開 contract、関連 issue / PR を調べる。確定した制約と、調査で確定できない事項を分け、確定できない事項ごとに回答別の分岐計画を作る。ユーザーに聞くのは product decision、優先順位、破壊的変更の許容だけにする。

## Phase 1: Goal Contract

`README.md` と `ai/program.md` を `references/templates.md` に従って作成する。Phase 計画と判断表の書き方、Phase 1 を終えてよい条件は `references/planning.md` の Phase 1 節に従う。root goal と質問は承認ビューで確認する。

## Phase 2: Architecture / Tech Choice

次のいずれかに該当するときだけ技術選定を行う。該当しなければ「既存標準を採用」と記録して進む。

- 新しい storage / queue / framework / external service を導入する
- 公開 API、schema、migration strategy、auth model、deployment topology が変わる
- 複数の実装方式があり、運用コストや rollback 性が大きく違う
- 既存 ADR と衝突する可能性がある

候補を 2〜4 個に絞り、`Cost / risk / migration / rollback / testability / owner familiarity` で比較して、推奨案と却下案を `ai/decisions.md` に記録する。非自明な採用判断は承認ビューで確認する。破壊的 contract 変更が必要なら編集前に停止して報告する。

## Phase 3: Delivery Tree Decomposition

`ai/tree.md` に、目的と成功基準の達成に必要な node だけで delivery tree を作る。placeholder node や「不要」と記録するためだけの node は作らない。分解の形と詳細ルールは `references/planning.md` の Phase 3 節に従う。

- **PR leaf**: 単独でレビュー・マージ可能で、受入基準と検証 gate が明確なコード、テスト、docs、config 変更の PR
- **Operation node**: 初回実行、one-off script、migration、backfill、feature flag 切替、外部サービス設定、手動確認など、PR の成果物とは別に実際に必要な実行
- **Verification node**: 別の時点、環境、owner で行い、その証跡が後続作業を独立して block する確認。実装直後のテストや同じ operation の結果確認は元 node の gate に含める
- **Decision node**: 今回の承認では決められず、将来の観測結果や別 owner の判断が後続作業を独立して block する事項

### 構成最小化レビュー

epic の新規作成後と、goal、scope、成功基準、delivery tree、harness の更新後に必ず行う。このレビュー自体を node や README.md の Phase にしない。

1. 外しても成功基準、正しさ、安全性、既存 contract のどれも弱まらない node を削除する
2. 独立した review / merge、実行環境、owner、承認、rollout、rollback の境界がない隣接 node を統合する
3. test、docs、config、同じ変更直後の検証は、独立して配布・実行する理由がない限り対象 node に含める
4. 不要な直列依存を外す。分割・統合・調整の時間が短縮時間を上回る並列化はしない
5. 全成功基準が 1 つ以上の node と gate に、全 node が 1 つ以上の成功基準または必須の安全条件に対応することを確認する

レビュー後の tree を承認対象とする。`README.md` の Phase 計画、node 一覧、主要リスク、成功基準を更新してから承認ビューで確認する。milestone 単位でまとめて確認してよいが、operation node と破壊的変更を含む node は個別に明示する。

## Phase 4: Harness Plan

各 PR leaf に `ai/leaves/{id}-{slug}.md`、各 operation node に `ai/operations/{id}-{slug}.md` を作る。テンプレートは `references/templates.md`、gate の設計と準備完了条件は `references/harness.md`。

各ファイルは承認部と実行部に分け、承認判断には承認部だけを使う。該当しない gate は `n/a — 理由` と一行で書き、空欄のまま残さない。harness 不足は原則として対象 leaf 内で補い、独立した `Harness PR` は `references/harness.md` の条件に該当する場合だけ作る。

## Phase 5: Execute Nodes

承認済み node を依存順に実行する。開始前に `references/execution.md` を読み、ブランチ安全性、委譲、operation 実行、統合確認、PR 作成をそれに従って行う。

- PR leaf: 保護ブランチ外で subagent に実装させ、main が file touch map との一致、Test / Data / Smoke gate、Spec compliance と Code quality の統合レビューを確認してから `my-pr create` に渡す。`my-pr` が成功するまで node を完了扱いにしない
- Operation node: 実行環境と権限を表示し、承認済みの exact command / manual action だけを実行する。破壊的操作と外部状態変更は main が実行する
- 失敗時は root cause を特定し、同じ subagent に 1 回だけ修正を依頼する。それでも失敗する、または設計矛盾があれば停止する

次の場合は停止し、対象 node、発生事象、観測済み証拠、選択肢、推奨案を提示する。

- ユーザー承認前の leaf 実装または operation 実行になる
- public contract / schema / migration / CLI flag / config key の破壊的変更が必要になる
- 検証 gate が未定義、実行不能、または利用できない credential に依存する
- 承認済み file touch map、command / manual action、環境、account、credential の範囲外が必要になる
- operation が partial success、曖昧な出力、証跡不足、rollback 状態不明になった
- spec compliance review で leaf goal 逸脱または受入基準漏れが見つかった
- テスト失敗が 1 回の修正で解消しない
- fallback、mock continuation、default substitution が必要に見える
- 新しい技術判断、または node の分割・統合が必要になった

## Phase 6: Program Closure

全 PR leaf の PR が作成済みまたは merged になり、全 operation / verification node が完了したら、`README.md` の完了サマリーに、完了 node 数、作成 PR、実行した operation / migration / script、実行した検証、残 risk / follow-up、未マージ PR と blocking reason、削除予定の feature flag / cleanup を記入する。

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
