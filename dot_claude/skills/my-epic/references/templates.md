# Epic Templates

`docs/epics/{epic}/` 配下に作成するファイルのテンプレートです。
epic ドキュメントは日本語で書きます。コマンド、コード識別子、API 名、schema 名、外部固有名詞は英語を維持します。

## ドキュメント区分

人間向けと AI 用をディレクトリで分ける。

```text
docs/epics/{epic}/
├── README.md            # 人間向け: 目的、Phase 計画、成功基準、承認事項の判断ダイジェスト
└── ai/                  # AI 用: 作業詳細と実行記録
    ├── program.md       # ゴール契約と判断表
    ├── tree.md          # delivery tree と node 状態の single source of truth
    ├── decisions.md     # 技術選定の判断記録
    ├── leaves/          # PR leaf の承認部と実行部
    └── operations/      # operation node の承認部と実行部
```

- 同じ情報は 1 ファイルにだけ書く。`README.md` は `ai/` 配下の要約であり、矛盾したら `ai/` 配下を正とする。
- node 状態は `ai/tree.md` の node 表だけで管理する。leaf / operation ファイルには状態を持たせない。

## README.md（人間向け）

```markdown
# {Initiative title}

<!-- 人間向け承認ドキュメント。判断に必要な情報を優先し、詳細な調査ログと実行記録は ai/ 配下へ置く。 -->

## 現在地
- **Phase**: {N} {phase-name}
- **進捗**: {A}/{Y} nodes 完了
- **承認待ち**: なし / {対象}
- **次の判断**: なし / {判断内容}

## 判断サマリー
- **目的**: {この epic で解決したい問題と、今やる理由}
- **Root goal**: {一文}
- **対象**: {in-scope の要約}
- **対象外**: {non-goals の要約}

## 成功基準
<!-- 完了判断に使う基準だけを書く。各基準は code / test / data / operation / PR の証跡に接続する。 -->
| 基準 | 確認方法 | 対応 node |
|---|---|---|
| {期待成果} | {command / query / PR / dashboard / manual evidence} | {PR-001 / OP-001 / VERIFY-001} |

## Phase 計画
<!-- 大まかな流れを示す。承認判断に不要な実装詳細は ai/tree.md と leaf / operation ファイルへ置く。 -->
| Phase | やること | 成功基準 | 状態 |
|---|---|---|---|
| 0 Discover | 既存 docs、code、tests、contract、運用制約を調べる | 不明点と制約が判断表に整理済み | planned |
| 1 Goal Contract | 目的、root goal、scope、non-goals、成功基準を確定する | README.md と ai/program.md が承認可能 | planned |
| 2 Architecture / Tech Choice | 必要な技術選定と破壊的変更の有無を判断する | 採用案、却下案、rollback 方針が記録済み | planned |
| 3 Delivery Tree | PR leaf、operation、verification、decision node に分解する | 依存関係と PR 外作業が ai/tree.md に明記済み | planned |
| 4 Harness Plan | 各 node の受入基準、gate、rollback、証跡を定義する | 実装または実行に進める gate が明記済み | planned |
| 5 Execute Nodes | 承認済み node を依存順に実装、実行、検証する | gate が通り、PR または operation 証跡が残る | planned |
| 6 Program Closure | 完了状況、PR、operation、残リスクをまとめる | 完了サマリーと follow-up が記録済み | planned |

## 主要リスク
<!-- 3 件以内。承認判断に影響するものだけ。 -->
-

## Node 一覧
<!-- 1 node 1 行。詳細は ai/leaves/ ai/operations/ を参照。 -->
| Node | 種別 | 目的 | 成功基準 | 状態 |
|---|---|---|---|---|

## 承認待ち事項
<!-- 質問は最大 3 問。推奨案を先頭に置く。決定したら承認履歴へ移す。 -->
| # | 質問 | 推奨案 | 選択肢と分岐 |
|---|---|---|---|

## 承認履歴
| 日付 | 対象 | 決定 |
|---|---|---|

## 完了サマリー
<!-- Phase 6 で記入する。 -->
- **完了 node**:
- **作成 PR**:
- **実行した operation**:
- **実行した検証**:
- **残リスク / follow-up**:
```

## ai/program.md

```markdown
# {Initiative title} — Goal Contract

## 状態
- **現在の Phase**:
- **次に確認すること**:
- **PR 外作業の見込み**: あり（{種別}） / なし / 未確認
<!-- PR 外作業の詳細は ai/tree.md に書く。 -->

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
- **Docs / ADR**:
- **関連コード**:
- **関連テスト**:
- **関連 issue / PR**:

## 判断表
<!-- 不明点と判断事項をすべてここで管理する。user-confirm は README.md の承認待ち事項へ転記する。 -->
| ID | 種別 | 未確定事項 | 今決める理由 | 選択肢 | 推奨案 | 分岐後の処理 | 状態 |
|---|---|---|---|---|---|---|---|
| Q-001 | user-confirm / open |  |  | A: / B: |  | If A: / If B: | open |

## 影響し得る公開 contract
- **API**:
- **Schema / migration**:
- **CLI / config**:
- **Event / queue**:

## Rollout / rollback 方針
- **Rollout**:
- **Rollback**:
- **Feature flag**:
- **Cleanup 条件**:
```

## ai/decisions.md

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

## ai/tree.md

````markdown
# Delivery Tree

## 概要
- **Root goal**:
- **Milestones**:
- **Critical path**:

## PR 外作業
- **PR だけで完結するか**: yes | no | unknown
- **必要な作業**: <!-- 該当するものだけ: initial script / migration / backfill / feature flag / external console / manual verification / cleanup / none -->
- **不要と判断した根拠**:
- **再確認する条件**:

## Tree

```text
Root Initiative
└── M1: {milestone}
    ├── PR-001: {leaf title}
    ├── OP-001: {operation title}
    └── VERIFY-001: {verification title}
```

## Node 表（状態の single source of truth）
<!-- file touch map と gate 詳細は各 leaf / operation ファイルに書く。 -->
| Node | 種別 | 内容 | 依存 | Unlocks | 並列 group | 承認 | 状態 | PR |
|---|---|---|---|---|---|---|---|---|
| PR-001 | PR leaf |  | none | OP-001 | P1 | pending | planned | - |
| OP-001 | Operation |  | PR-001 | - | serial | pending | planned | n/a |

承認: pending | approved。状態: planned | in-progress | blocked | PR-open | complete | merged | skipped。

## Milestones

### M1: {milestone}
- **Goal**:
- **Exit criteria**:
- **Nodes**: PR-001, OP-001
- **承認**: pending | approved
````

## ai/leaves/{id}-{slug}.md

承認部と実行部に分ける。人間向けダイジェストは承認部から作る。
該当しない gate は `n/a — 理由` と一行で書き、空欄のまま残さない。

````markdown
# {ID}: {Leaf title}

## 承認部

### PR goal
- **成果**:
- **必要な理由**:
- **対象外**:

### 依存関係
- **依存**:
- **Unlocks**:
- **並列可否**:

### File touch map
- **CREATE**:
  - `path/to/new_file`
- **MODIFY**:
  - `path/to/existing_file`
- **TEST**:
  - `path/to/test_file`
- **DOCS**:
  - `path/to/doc_file`
- **DO NOT TOUCH**:
  - `path/to/out_of_scope_file`

### Contract impact
- **API**: none | additive | breaking
- **Schema / data**: none | additive | migration | backfill
- **CLI / config**: none | additive | breaking
- **Event / queue**: none | additive | breaking

### 受入基準
- [ ] AC-1:

### 検証 gate

#### Test gate
- [ ] Command:
- [ ] Expected result:

#### Data gate
- [ ] Command / query:
- [ ] Expected result:

#### Smoke gate
- [ ] Command / scenario:
- [ ] Expected result:

#### Observability gate
- [ ] Logs / metrics / traces:
- [ ] Expected result:

#### Rollout / rollback gate
- [ ] Rollout:
- [ ] Rollback:

### Review gate 観点

#### Spec compliance review
- [ ] 承認済み PR goal だけを実装している
- [ ] すべての受入基準を満たしている
- [ ] 余分な機能や scope creep がない
- [ ] out-of-scope file を変更していない
- [ ] Contract impact が承認済み内容と一致している

#### Code quality review
- [ ] 既存 pattern に従っている
- [ ] 共有 contract と caller を確認している
- [ ] Error semantics を維持している
- [ ] テストが実挙動を検証している
- [ ] fallback behavior、silent retry、broad catch、mock continuation、default substitution を追加していない

## 実行部

### Branch / PR
- **Branch / worktree**:
- **PR URL**:

### Implementation prompt
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

### 実装記録
- **Mode**: Direct | Codex-assisted | Explore-only
- **Summary**:
- **Files changed**:
- **Contracts changed**:
- **Tests run**:
- **Data checks run**:
- **Smoke checks run**:
- **Spec compliance review**:
- **Code quality review**:
- **Remaining risks / follow-ups**:

### 実行 log
| Time | Actor | Action | Result |
|---|---|---|---|
````

## ai/operations/{id}-{slug}.md

承認部と実行部に分ける。承認部の内容がユーザー承認の対象になる。

````markdown
# {ID}: {Operation title}

## 承認部

### Operation goal
- **成果**:
- **必要な理由**:
- **対象外**:

### 依存関係
- **依存**:
- **Unlocks**:
- **並列可否**:

### 実行 scope
- **作業種別**: migration | backfill | initial script | feature flag | external console | verification | cleanup
- **Owner / executor**:
- **環境**:
- **対象 account / project / region / tenant**:
- **影響 system**:
- **データ / 運用影響**:
- **実行予定時間帯**:

### 前提条件
- [ ] Required PRs merged:
- [ ] Credentials / permissions confirmed:
- [ ] Current account / project shown:
- [ ] Dry-run / preview / backup / snapshot completed:
- [ ] User approval recorded:

### 実行手順

#### Dry-run / preview
- [ ] Command / action:
- [ ] Expected result:

#### Execute
- [ ] Command / action:
- [ ] Expected result:

#### Evidence
- [ ] Logs / output:
- [ ] Data checks:
- [ ] Metrics / dashboard / traces:

### Rollback / abort
- **中止条件**:
- **Rollback command / action**:
- **不可逆影響**:
- **エスカレーション先**:

### 承認 gate
- [ ] 現状と確定事実を提示した
- [ ] 実行する場合 / しない場合の影響を説明した
- [ ] 推奨案を提示した
- [ ] ユーザーが exact command / action を承認した

## 実行部

### 実行記録
- **実行者**:
- **実行日時**:
- **実行した command / action**:
- **結果**:
- **証跡 link / output**:
- **Rollback 実施**: yes | no
- **Remaining risks / follow-ups**:

### 実行 log
| Time | Actor | Action | Result |
|---|---|---|---|
````
