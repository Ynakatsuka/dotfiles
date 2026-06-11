# Epic Templates

`docs/epics/{epic}/` 配下に作成するファイルのテンプレートです。
計画、tree、node、decision、実行記録は日本語で書きます。
コマンド、コード識別子、API 名、schema 名、外部固有名詞、PR body の慣例は必要に応じて英語を維持します。

## program.md

```markdown
# {Initiative title}

## 実行計画（最初に読む）
- **目的**:
- **現在の Phase**: Phase 0 / 1 / 2 / 3 / 4 / 5 / 6
- **次に確認すること**:
- **PR 以外の作業見込み**: あり / なし / 未確認
- **PR 以外の作業がある場合**: initial script / migration / backfill / feature flag / external console / manual verification / cleanup / other

| Phase | 目的 | 主な確認 | 成果物 | ユーザー確認 |
|---|---|---|---|---|
| 0 Discover | 既存情報から制約と不明点を把握する | docs / ADR / PRD / code / tests / issue / PR / CI / public contract | 調査メモ、確認候補、分岐案 | product decision、優先順位、破壊的変更だけ |
| 1 Goal Contract | root goal と成功条件を固定する | scope、non-goals、success metrics、contract、data、rollout | この `program.md` | root goal、確認計画 |
| 2 Architecture / Tech Choice | 技術選定が必要か判断する | 既存標準、ADR、migration、rollback、運用コスト | `decisions.md` | 非自明な採用判断 |
| 3 Delivery Tree | PR と PR 外作業を DAG に分解する | PR leaf、operation、verification、decision、依存順、並列可否 | `tree.md` | milestone、node 分割、operation 内容 |
| 4 Harness Plan | 各 node の実行条件と検証を定義する | test / data / smoke / observability / rollback / evidence | `leaves/*.md`, `operations/*.md` | 実行条件、rollback、承認 gate |
| 5 Execute Nodes | 承認済み node を依存順に進める | file touch map、環境、権限、dry-run、証跡、gate 結果 | PR、実行記録、検証証跡 | operation 実行、破壊的変更、未定義手順 |
| 6 Program Closure | 完了状態と残リスクを整理する | PR 状態、operation 結果、検証、follow-up、cleanup | closure summary | 残 block / follow-up 判断 |

## ゴール契約
- **問題**:
- **期待する成果**:
- **成功指標**:
- **主な利用者**:

## スコープ
### 対象
-

### 対象外
-

## 制約
- **技術**:
- **プロダクト**:
- **運用**:
- **セキュリティ / privacy**:

## 既存情報
- **Docs / ADRs（関連資料）**:
- **関連コード**:
- **関連テスト**:
- **関連 issue / PR**:

## PR 外作業の想定
| 種別 | 必要性 | 理由 | 依存 node | 想定証跡 | rollback / abort |
|---|---|---|---|---|---|
| Initial script | 未確認 |  |  |  |  |
| Migration / backfill | 未確認 |  |  |  |  |
| Feature flag / rollout | 未確認 |  |  |  |  |
| External console / manual action | 未確認 |  |  |  |  |
| Verification only | 未確認 |  |  |  |  |
| Cleanup | 未確認 |  |  |  |  |

## 判断材料
- **現状理解**:
- **確認済み事実**:
- **今判断が必要な理由**:
- **選択肢ごとの影響**:
- **推奨案**:
- **ユーザーに聞くこと**:

## 確認計画
| ID | 未確定事項 | 今聞く理由 | 選択肢 | 分岐後の処理 | 推奨案 | 状態 |
|---|---|---|---|---|---|---|
| Q-001 |  |  | A: / B: / C: | If A: / If B: / If C: |  | open |

## 影響し得る公開 contract
- **API（公開 API）**:
- **Schema / migrations（schema / migration）**:
- **CLI / config（CLI / 設定）**:
- **Events / queues（event / queue）**:

## Rollout / rollback 方針
- **Rollout plan（展開計画）**:
- **Rollback plan（戻し方）**:
- **Feature flags（feature flag）**:
- **Cleanup trigger（cleanup 条件）**:

## 未決事項
| ID | 判断事項 | 選択肢 | 推奨案 | 状態 |
|---|---|---|---|---|
| D-001 |  |  |  | open |

## 完了サマリー
<!-- Phase 6 で記入する。 -->
```

## decisions.md

```markdown
# 判断記録

## D-001: {判断タイトル}

- **状態**: proposed | accepted | rejected | superseded
- **背景**:
- **検討した選択肢**:
  1.
  2.
- **決定**:
- **理由**:
- **トレードオフ**:
- **却下した代替案**:
- **再検討条件**:
```

## tree.md

````markdown
# Delivery Tree

## 概要
- **Root goal（ルートゴール）**:
- **Milestones（マイルストーン）**:
- **Total nodes（総 node 数）**:
- **PR leaves（PR leaf 数）**:
- **Operation nodes（operation node 数）**:
- **Critical path（クリティカルパス）**:

## PR 外作業の確認
- **PR だけで完結するか**: yes | no | unknown
- **PR 以外に必要な作業**: initial script / migration / backfill / feature flag / external console / manual verification / cleanup / none
- **不要と判断した根拠**:
- **後続 Phase で再確認する条件**:

## Tree（ツリー）

```text
Root Initiative
└── M1: {milestone}
    ├── PR-001: {leaf title}
    ├── OP-001: {operation title}
    └── VERIFY-001: {verification title}
```

## 依存 DAG

| Node | 種別 | 依存 | Unlocks | 並列 group | 状態 |
|---|---|---|---|---|---|
| PR-001 | PR leaf | none | OP-001 | P1 | planned |
| OP-001 | Operation | PR-001 | VERIFY-001 | serial | planned |

## 進捗 matrix

| Node | 種別 | 承認 | 実行 | Test gate | Data gate | Smoke / evidence gate | Review gates | PR |
|---|---|---|---|---|---|---|---|---|
| PR-001 | PR leaf | pending | not-started | pending | n/a | pending | pending | not-created |
| OP-001 | Operation | pending | not-started | n/a | pending | pending | n/a | n/a |

## File touch matrix（ファイル変更範囲）

| Node | CREATE | MODIFY | TEST | DO NOT TOUCH | 並列可能な node |
|---|---|---|---|---|---|
| PR-001 | `src/new.ts` | `src/index.ts` | `tests/new.test.ts` | `src/legacy.ts` | PR-003 |
| OP-001 | n/a | n/a | n/a | application code | none |

## Operation matrix（運用作業一覧）

| Node | 環境 | Owner | Action | 前提条件 | 証跡 | Rollback / abort |
|---|---|---|---|---|---|---|
| OP-001 | staging |  | Run script | PR-001 merged | log line / data check | abort command |

## Milestones（マイルストーン）

### M1: {milestone}
- **Goal（目的）**:
- **Exit criteria（完了条件）**:
- **Nodes（node 一覧）**: PR-001, OP-001, VERIFY-001
- **User approval（ユーザー承認）**: pending | approved
````

## leaves/{id}-{slug}.md

````markdown
# {ID}: {Leaf title}

## 状態
- **State（状態）**: planned | approved | in-progress | blocked | PR-open | merged | skipped
- **Branch / worktree（branch / worktree）**:
- **PR**:

## PR goal（PR の目的）
- **Outcome（成果）**:
- **この PR が必要な理由**:
- **Out of scope（対象外）**:

## 依存関係
- **Depends on（依存）**:
- **Unlocks（後続）**:
- **Parallel safety（並列可否）**:

## File touch map（ファイル変更範囲）
- **CREATE（作成）**:
  - `path/to/new_file`
- **MODIFY（変更）**:
  - `path/to/existing_file`
- **TEST（テスト）**:
  - `path/to/test_file`
- **DOCS（docs）**:
  - `path/to/doc_file`
- **DO NOT TOUCH（触らない）**:
  - `path/to/out_of_scope_file`

## Contract impact（契約影響）
- **Public API（公開 API）**: none | additive | breaking
- **Schema / data（schema / data）**: none | additive | migration | backfill
- **CLI / config（CLI / 設定）**: none | additive | breaking
- **Events / queues（event / queue）**: none | additive | breaking

## 受入基準
- [ ] AC-1:

## 検証 gate
### Test gate（テスト）
- [ ] Command:
- [ ] Expected result:

### Data gate（データ）
- [ ] Command / query:
- [ ] Expected result:

### Smoke gate（スモーク）
- [ ] Command / scenario:
- [ ] Expected result:

### Observability gate（観測）
- [ ] Logs / metrics / traces:
- [ ] Expected result:

### Rollout / rollback gate（展開 / 戻し）
- [ ] Rollout:
- [ ] Rollback:

## Review gates（レビュー）
### Spec compliance review（仕様適合）
- [ ] 承認済み PR goal だけを実装している
- [ ] すべての受入基準を満たしている
- [ ] 余分な機能や scope creep がない
- [ ] out-of-scope file を変更していない
- [ ] Contract impact が承認済み leaf と一致している

### Code quality review（品質）
- [ ] 既存 pattern に従っている
- [ ] 共有 contract と caller を確認している
- [ ] Error semantics を維持している
- [ ] テストが実挙動を検証している
- [ ] fallback behavior、silent retry、broad catch、mock continuation、default substitution を追加していない

## Implementation prompt（実装依頼）
```text
You are implementing PR leaf {ID}: {title}.

Goal:
- ...

Non-goals:
- ...

File touch map:
- ...

Acceptance criteria:
- ...

Verification gates to satisfy:
- ...

Constraints:
- Do not add fallback behavior, silent retries, broad exception swallowing, mock continuation, or default substitution.
- Stop and report if a public contract, schema, CLI/config key, migration semantics, or documented error behavior must change beyond this leaf.
- Keep comments, docstrings, commit messages, and README text in English.

Return:
- Summary
- Files changed
- Tests run and results
- Review gate results
- Any unresolved blockers
```

## 実装記録
- **Mode（実装方式）**: Direct | Codex-assisted | Explore-only
- **Summary（要約）**:
- **Files changed（変更ファイル）**:
- **Contracts changed（契約変更）**:
- **Tests run（実行したテスト）**:
- **Data checks run（実行したデータ確認）**:
- **Smoke checks run（実行した smoke 確認）**:
- **Spec compliance review（仕様適合確認）**:
- **Code quality review（品質確認）**:
- **PR URL**:
- **Remaining risks / follow-ups（残リスク / follow-up）**:

## 実行 log
| Time | Actor | Action | Result |
|---|---|---|---|
````

## operations/{id}-{slug}.md

````markdown
# {ID}: {Operation title}

## 状態
- **State（状態）**: planned | approved | in-progress | blocked | complete | skipped
- **Owner / executor（責任者 / 実行者）**:
- **Environment（環境）**:
- **Scheduled time / window（実行予定時間）**:

## Operation goal（運用作業の目的）
- **Outcome（成果）**:
- **この operation が必要な理由**:
- **Out of scope（対象外）**:

## 依存関係
- **Depends on（依存）**:
- **Unlocks（後続）**:
- **Parallel safety（並列可否）**:

## 実行 scope
- **Operation type（作業種別）**: migration | backfill | initial script | feature flag | external console | verification | cleanup
- **Target account / project / region / tenant（対象 account / project / region / tenant）**:
- **Systems touched（影響 system）**:
- **Data / operational impact（データ / 運用影響）**:

## 前提条件
- [ ] Required PRs merged:
- [ ] Required credentials / permissions confirmed:
- [ ] Current account / project shown:
- [ ] Dry-run / preview / backup / snapshot completed:
- [ ] User approval recorded:

## 実行手順
### Dry-run / preview（事前確認）
- [ ] Command / action:
- [ ] Expected result:

### Execute（実行）
- [ ] Command / action:
- [ ] Expected result:

### Evidence（証跡）
- [ ] Logs / output:
- [ ] Data checks:
- [ ] Metrics / dashboard / traces:

## Rollback / abort（戻し / 中止）
- **Abort condition（中止条件）**:
- **Rollback command / action（戻し command / action）**:
- **Irreversible effects（不可逆影響）**:
- **Escalation owner（エスカレーション先）**:

## 承認 gate
- [ ] 質問前に現状を説明した
- [ ] 事実と制約を提示した
- [ ] 実行する場合 / しない場合の影響を説明した
- [ ] 推奨案を提示した
- [ ] ユーザーが exact command / action を承認した

## 実行記録
- **Executed by（実行者）**:
- **Executed at（実行日時）**:
- **Command / action run（実行した command / action）**:
- **Result（結果）**:
- **Evidence links / output（証跡 link / output）**:
- **Rollback used（rollback 実施）**: yes | no
- **Remaining risks / follow-ups（残リスク / follow-up）**:

## 実行 log
| Time | Actor | Action | Result |
|---|---|---|---|
````
