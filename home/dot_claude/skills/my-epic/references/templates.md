# Epic Templates

`docs/epics/{epic}/` 配下に作成するファイルのテンプレートです。
epic ドキュメントは日本語で書きます。コマンド、コード識別子、API 名、schema 名、外部固有名詞は英語を維持します。

## ドキュメント区分

人間向けと AI 用をディレクトリで分ける。

```text
docs/epics/{epic}/
├── README.md            # 人間向け: 目的、実装・実行・確認の Phase 計画、成功基準、判断ダイジェスト
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

<!-- 人間向け概要ドキュメント。実装・実行・確認の現在地を優先し、詳細な調査ログと実行記録は ai/ 配下へ置く。 -->

## 現在地
- **実装フェーズ**: {Phase 計画の現在行}
- **進捗**: {A}/{Y} nodes 完了
- **承認待ち**: なし / {対象}
- **次の判断**: なし / {判断内容}

## 判断サマリー
- **目的**: {この epic で解決したい問題と、今やる理由}
- **Root goal**: {一文}
- **対象**: {in-scope の要約}
- **対象外**: {non-goals の要約}
- **前提 / 制約**: {構成判断に影響する確認済み事実}

## 成功基準
<!-- 完了判断に使う基準だけを書く。各基準は code / test / data / operation / PR の証跡に接続する。 -->
| 基準 | 確認方法 | 対応 node |
|---|---|---|
| {期待成果} | {command / query / PR / dashboard / manual evidence} | {PR-001 / OP-001 / VERIFY-001} |

## Phase 計画
<!-- 今回の目的を達成するために実際に必要な実装・実行・テストの順序だけを書く。固定の Phase を埋めず、同じ変更境界の作業はまとめる。スキル内部の承認、tree 分解、harness plan、closure を phase として載せない。 -->
| Phase | 目的 | 実装・実行内容 | 確認方法 | 状態 |
|---|---|---|---|---|
| 1 {利用者に分かる作業名} |  |  |  | planned |

## 主要リスク
<!-- 3 件以内。承認判断に影響するものだけ。 -->
| リスク | 影響 | 回避・検知・rollback |
|---|---|---|

## 承認対象
- **対象**: {新規計画 / 更新内容}
- **確認済み事実**: {計画の根拠にした code、docs、tests、運用情報}
- **提案方針**: {採用する実装・実行方針と理由}
- **Critical path**: {node の順序}
- **並列実行**: {同時に進める node と、安全に並列化できる根拠 / なし}
- **公開 contract への影響**: {API / schema / CLI / config / event}
- **データ・運用・外部状態への影響**: {対象環境、変更内容、権限、不可逆性 / なし}
- **停止・rollback 方針**: {失敗条件と戻し方}
- **承認後に開始する作業**: {最初の node と、承認によって許可される範囲}
- **まだ許可されない作業**: {push / PR / migration / production 操作など / なし}
- **前回承認版との差分**: {新規の場合は n/a}

## Node 一覧
<!-- 承認対象の全 node を載せる。各セルは、ai/leaves/ ai/operations/ の承認部から判断に必要な内容を要約する。 -->
| Node | 目的・成果 | 変更・実行範囲 | 依存・順序 | 受入基準・検証 | 影響・リスク | 独立 node にする理由 | 状態 |
|---|---|---|---|---|---|---|---|

## 承認待ち事項
<!-- 質問は一度に判断できる最大 3 問。根拠と分岐後の影響を省かない。決定したら承認履歴へ移す。 -->
| # | 判断に必要な事実 | 質問 | 推奨案と理由 | 選択肢ごとの scope・node・順序・リスクへの影響 |
|---|---|---|---|---|

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

## 構成最小化レビュー
- **削除・統合した候補**: {候補 → 統合先と理由 / なし}
- **残した分割境界**: {node → 独立した review / merge / owner / environment / approval / rollout / rollback 境界}
- **並列化**: {並列 group と短縮できる理由 / なし}

## Tree

```text
Root Initiative
└── M1: {milestone}
    └── PR-001: {leaf title including its tests and immediate verification}
```

<!-- PR 外の実行や独立した確認が実際に必要な場合だけ OP / VERIFY / DECISION node を追加する。 -->

## Node 表（状態の single source of truth）
<!-- file touch map と gate 詳細は各 leaf / operation ファイルに書く。 -->
| Node | 種別 | 内容 | 依存 | Unlocks | 並列 group | 承認 | 状態 | PR |
|---|---|---|---|---|---|---|---|---|
| PR-001 | PR leaf |  | none | - | serial | pending | planned | - |

承認: pending | approved。状態: planned | in-progress | blocked | PR-open | complete | merged | skipped。

## Milestones

### M1: {milestone}
- **Goal**:
- **Exit criteria**:
- **Nodes**: PR-001
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
- **Mode**: Subagent-delegated | Explore-first | Direct-exception
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
