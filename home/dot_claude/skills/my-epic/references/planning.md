# Planning Details

Phase 1 の README.md / 判断表の作り方と、Phase 3 の delivery tree 分解ルールの詳細。

## Phase 1: README.md の Phase 計画の書き方

README.md の Phase 計画は、ユーザーが今回の目的を達成する作業順を理解するためのものにする。スキル内部の orchestration phase（Goal Contract、Architecture / Tech Choice、Delivery Tree、Harness Plan、Program Closure）をそのまま載せない。
README.md の現在地も、この実装・実行・確認の Phase 計画上の現在行で表す。`Phase 1 Goal Contract` のような内部フェーズ名を現在地として載せない。

Phase 計画に含める内容:

- 現状確認、失敗再現、既存挙動調査
- テスト、fixture、verification harness の準備
- コード、設定、docs、script の実装
- migration、backfill、初期 script、feature flag、manual operation の実行
- unit / integration / contract / data / smoke / observability の確認
- cleanup、rollback 確認、PR / CI 確認

Phase 計画に含めない内容:

- ユーザー承認そのもの
- delivery tree 分解そのもの
- leaf / operation ファイル作成そのもの
- README.md や ai/program.md を承認可能にすること
- このスキルの内部フェーズ名

## Phase 1: 判断表の作り方

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

## Phase 1: 進めてよい条件

- root goal が一文で説明できる
- 目的と「なぜ今やるか」が README.md に書かれている
- non-goals が明記されている
- 成功判定がコード、テスト、データ、運用のいずれかで検証できる
- Phase ごとの実装・実行・確認内容と成功基準が README.md から分かる
- 判断表に選択肢と分岐後の処理が記録されている
- ユーザー確認の結果が承認履歴と判断表に反映されている

## Phase 3: 分解の形

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

## Phase 3: 分解ルール

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
