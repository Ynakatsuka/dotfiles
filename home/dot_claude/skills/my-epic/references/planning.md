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

これらを固定の Phase としてすべて作らない。実際に必要な作業だけを残し、同じ変更境界で完了する実装とテスト、docs、検証は同じ Phase にまとめる。

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
4. ユーザー確認が必要な不明点を、一度に判断できる最大 3 問にまとめ、根拠と選択肢ごとの影響を落とさず `README.md` の承認待ち事項へ転記する
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
│   ├── PR A1: Backward-compatible implementation and its tests
│   └── OP A2: Run required backfill script
└── Milestone B
    └── PR B1: Remaining independently reviewable outcome
```

この例に node を合わせない。PR 外の実行や独立した確認がなければ PR leaf だけでよく、単独 PR で安全に完了できるなら root 直下に PR leaf を 1 つだけ置いてよい。

## Phase 3: 分解ルール

- 1 PR leaf = 1 PR
- まず 1 PR で安全にレビュー・検証できるか確認する。できる場合は、作業種類が複数あることだけを理由に分割しない
- 分割は、独立した review / merge、異なる owner や実行環境、個別 rollout / rollback、破壊的 contract 変更の隔離、または明確な並列化利益が必要な場合だけ行う
- operation node は PR として表現しない。runbook、実行条件、証跡、rollback を持つ独立 node にする
- harness / contract test / migration dry-run tooling は、それを複数 node が先に必要とする場合だけ独立 PR にする。それ以外は対象 PR leaf に含める
- migration、script 実行、rollout など外部状態を変える作業は operation node に分ける。script 自体の実装とテストは対象 PR leaf に含めてよい
- 依存関係は DAG として明記する
- 並列化は、write set、contract、operational state が衝突せず、追加の分割・統合時間を含めても完了が早くなる場合だけ使う
- 1 PR で完結しない PR leaf はさらに分割する
- 手動作業、one-off script、migration、external console 操作が必要なら operation node を作る
- operation node は owner、実行環境、前提条件、exact command / action、expected evidence、rollback、実行してよい時間帯を明記する
- 実装直後の test、data check、smoke、observability check は元 node の gate にする。別の時点、環境、owner で行い、結果が後続作業を独立して block する場合だけ verification node にする
- 今回の承認で決められる事項は承認待ち事項で扱う。将来の証拠や別 owner の判断を待つ場合だけ decision node にする
- 新規作成後と構成変更後に deletion test を行い、なくても成功基準、安全性、既存 contract が弱まらない node を削除する
