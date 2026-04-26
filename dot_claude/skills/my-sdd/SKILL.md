---
name: my-sdd
description: >-
  Unified Spec-Driven Development workflow: plan → tasks → implement with test-first approach.
  Automatically detects current phase and routes accordingly.
  Use when the user asks to plan a feature, break down tasks from a spec, or implement from
  requirements (e.g., "新機能を設計", "タスク分解", "specから実装", "SDD").
  Do NOT use for simple bug fixes, refactoring, or tasks that don't need a spec-driven approach.
argument-hint: "[feature-name]"
---

# Spec-Driven Development (SDD) Unified Workflow

あなたはスペック駆動開発（Spec-Driven Development）の統合エージェントです。要件定義から実装までの全フェーズを、現在の状態を自動検出して適切に実行します。

**このコマンドは以下の3フェーズを統合しています:**
- **Phase 1 (Plan)**: 事前調査 → 要件明確化 → requirements.md → design.md → 外部レビュー（codex / gemini / claude）
- **Phase 2 (Tasks)**: タスク分解 → tasks.md 作成
- **Phase 3 (Impl)**: 実装 → コード + テスト + tasks.md ステータス更新

## ワークフロー全体図

```
Phase 1: Plan
  1-0 Investigation → 1-1 Clarify → 1-2 Specify → 1-3 Design → 1-4 External Review
  出力: docs/specs/{name}/{requirements.md, design.md} + /tmp/sdd-reviews/{name}/
    ↓ (ユーザー確認)
Phase 2: Tasks   → tasks.md
    ↓ (ユーザー確認)
Phase 3: Impl    → 実装コード + テスト
    ↓
完了報告 → /pull-request でPR作成
```

## 参照ファイル

- `references/senior-review-checklist.md` — Phase 1-0 の調査範囲、Phase 1-3 の設計観点、Phase 1-4 のレビュー基準
- `references/external-review.md` — Phase 1-4 (External Review) の起動手順・反映ルール

## 引数処理

$ARGUMENTS の値に応じて処理を分岐する:

1. **パス指定** (`docs/specs/` を含む場合):
   - そのパスを spec_dir として使用
   - 例: `/my-sdd docs/specs/user-auth`

2. **機能名指定** (ケバブケース英数字のみ):
   - `docs/specs/{value}` を spec_dir として使用
   - 例: `/my-sdd user-auth`

3. **要求説明** (日本語または自然言語):
   - Phase 1 の初期要求として処理
   - 機能名はユーザーとの対話後にケバブケースで決定
   - 例: `/my-sdd ユーザー認証機能を追加したい`

4. **指定なし**:
   - `docs/specs/` ディレクトリを走査
   - 進行中の機能があれば候補を表示して選択を促す
   - なければユーザーに要求を尋ねる

## 状態検出

spec_dir が特定されたら、以下の順序でファイルの存在を確認し、実行するフェーズを判定する:

### 判定ロジック

1. spec_dir が存在しない → **Phase 1-0 から開始**（事前調査）
2. `requirements.md` が存在しない → **Phase 1-0 / 1-1 から再開**
3. `design.md` が存在しない → **Phase 1-3 から再開**（requirements.md を読み込んで設計から）
4. `design.md` は存在するが `tasks.md` が存在しない:
   - `/tmp/sdd-reviews/{feature-name}/done` がない、または mtime が 7 日より古い（TTL 切れ）→ **Phase 1-4 (External Review) を開始**
   - 有効な `done` があれば、ユーザーに確認の上 **Phase 2** へ
5. `tasks.md` の全タスクが完了 `[x]` → **完了報告**
6. `tasks.md` に未完了タスク `[ ]` がある → **Phase 3 を開始**

### フェーズ開始時の表示

フェーズ開始時に必ず以下を表示する:

```
🔍 状態検出結果:
  📁 スペックディレクトリ: docs/specs/{feature-name}/
  📄 requirements.md: ✅ 存在 / ❌ 未作成
  📄 design.md:       ✅ 存在 / ❌ 未作成
  📄 tasks.md:        ✅ 存在 (X/Y 完了) / ❌ 未作成

▶️ Phase {N} ({phase-name}) を開始します。
```

---

## Phase 1: Plan（要件定義と技術設計）

### Phase 1-0: 事前調査（Investigation）

要件明確化に入る前に、シニア/スタッフエンジニアの目線で関連情報を集める。**「コードで分かることはユーザーに聞かない」**を徹底するための前準備で、時間は十分かけてよい。

調査範囲（詳細は `references/senior-review-checklist.md`）:
- 既存の類似機能・関連モジュール・呼び出し元・テスト
- 関連 ADR / PRD / 過去 PR / issue
- 依存ライブラリのバージョンと主要 API（fast-moving topics は live source で確認）
- CI / lint / test / formatter の規約
- 既存の運用観測基盤（ログ・メトリクス・アラート）

`Explore` subagent で並列化してよい。調査結果から自明に決まる項目は質問せず、確認のみ（「Y を使う前提でよいか」）にする。

### Phase 1-1: 要件明確化（Clarify）

ユーザーの要求をルートとした**決定木**として捉え、合意に達するまで対話で枝を1つずつ確定する。

#### 質問の出し方

1. **1問ずつ**: 1つの分岐 = 1つの質問。関連が強い決定（例: ハッシュアルゴリズムと強度要件）はまとめて聞いてよい。一度に3問を超えない。
2. **推奨回答を必ず添える**: 各質問に「推奨: X（理由）」を付け、ユーザーは赤入れだけで済むようにする。推奨を出せないなら、まず自分で調査する。
3. **コードベースで分かることは聞かない**: 既存の依存・規約・パターンで答えが決まる質問は、ツールを使って自分で調べ、「Y を使う前提でよいか」と確認のみにする。
4. **依存の深い枝から下る**: 親の決定が子の質問を変える場合、親を先に確定する（例: 認証方式 → ハッシュアルゴリズム）。互いに独立な決定はあとに回す。
5. **決定木はファイル化しない**: 頭の中で展開する。書き出すと冗長になる。

#### 網羅性チェックリスト

決定木を下りきったら、以下5観点で漏れを確認する。未確定の観点があれば追加質問する:

- [ ] **スコープ**: 対象範囲と対象外
- [ ] **ユーザー**: 利用者と利用状況
- [ ] **成功基準**: 完了の定義
- [ ] **制約**: 技術・時間・互換性
- [ ] **優先度**: Must/Should/Could

### Phase 1-2: 要件定義（Specify）

明確化した内容を元に `requirements.md` を作成する。

```markdown
# {機能名} 要件定義

## 概要
[1-2文で機能の目的を説明]

## ユーザーストーリー
- [ ] US-1: [ユーザー]として、[機能]を行いたい。なぜなら[理由]だから。
- [ ] US-2: ...

## 受入基準（Acceptance Criteria）
### US-1: [ストーリー名]
- [ ] AC-1.1: [Given-When-Then形式またはEARS形式で記述]
- [ ] AC-1.2: ...

## スコープ
### 対象範囲
- ...

### 対象外
- ...

## 制約
- ...

## 優先度
### Must（必須）
- ...

### Should（推奨）
- ...

### Could（あれば良い）
- ...
```

### Phase 1-3: 技術設計（Design）

Phase 1-0 の調査結果と要件をもとに `design.md` を作成する。シニア/スタッフエンジニア視点で論点を網羅し、最初の段階でできる限り潰す。

**設計時に必ず潰す観点（詳細チェックリストは `references/senior-review-checklist.md`）:**
1. 失敗モード・エッジケース・並行性・idempotency
2. 非機能要件（latency p50/p95/p99 / throughput / cost / 可用性 / SLO）
3. セキュリティ（authn / authz / PII / secrets / injection / 最小権限）
4. 運用（rollout / rollback / feature flag / data migration / backfill）
5. 観測性（metrics / logs / alerts / tracing / 相関ID）
6. 契約と blast radius（公開API / upstream / downstream / 後方互換）
7. 隠れた前提と不変条件
8. 採用しなかった代替案（最低 2 つ）
9. 1-3 年後の後悔ポイント（10 倍規模・チーム交代・類似機能追加）
10. **既存コードベースとの整合性（プロジェクト固有）**:
    - 同種実装の有無・重複・統合機会・移行漏れ
    - 既存規約（命名 / error / log / metric / config / feature flag / i18n / 認可）との一致
    - 共有 helper / 公開型 / DB schema / shared lib への波及（呼び出し元を列挙）
    - 既存境界（DDD / layer / module visibility）の尊重
    - 既存テストパターン・fixture・mocks の再利用
    - 過去 PR / ADR / postmortem / deprecated 通告との整合
    - 進行中マイグレーションへの影響

全観点について「触れた／触れない理由がある」状態にする。リスク・代替案・未確定事項は必ず明示。

```markdown
# {機能名} 技術設計

## アーキテクチャ概要
[図または説明]

## コンポーネント設計
### {コンポーネント1}
- **責務**: ...
- **ファイル**: `path/to/file.ts`
- **依存関係**: ...

## データモデル
[スキーマ、型定義。スキーマ進化と後方互換性も明記]

## API設計
[エンドポイント、インターフェース、契約。後方互換性方針を明記]

## 既存コードとの統合
- **参考にすべき既存実装**: `path/to/reference.ts`
- **変更が必要なファイル**: ...
- **Blast radius**: 影響を受ける upstream / downstream（テスト・設定・スクリプト含む）

## Codebase coherence
- **同種実装の網羅検索結果**: 類似実装のパス一覧と差分の意図（重複を許容するなら理由）
- **再利用する既存資産**: 採用する helper / shared module / fixture / pattern とその場所
- **共有契約への影響**: 公開 API / DB schema / 共通型 / shared lib の変更と互換戦略・呼び出し元一覧
- **規約からの逸脱**: 既存規約（命名 / error / log / metric / config / feature flag / i18n / test）から外れる箇所と理由
- **過去知見の参照**: 関連する ADR / postmortem / 採用見送り PR / 進行中マイグレーション

## 非機能要件 (NFR)
- **レイテンシ / スループット**: ...
- **コスト**: ...
- **可用性 / SLO**: ...

## セキュリティ
- **認証 / 認可**: ...
- **PII / 機微情報**: ...
- **シークレット管理**: ...

## 観測性
- **メトリクス**: ...
- **ログ**: ...
- **アラート**: ...

## 運用・デプロイ
- **ロールアウト**: feature flag / canary / blue-green
- **ロールバック**: 手順と DB 変更の戻し方
- **データ移行 / バックフィル**: 手順・所要時間

## 失敗モードとエラーハンドリング
- 入力境界・タイムアウト・部分失敗・並行性
- リトライと idempotency 戦略

## テスト戦略
- **単体テスト**: ...
- **統合テスト**: ...
- **シナリオテスト**: 失敗モードを含む

## Risks & Mitigations
- リスク → 緩和策

## Rejected alternatives
- 採用しなかった代替案と不採用理由（最低 2 つ）

## Open Questions
- レビューや実装中に検証が必要な未確定事項
```

### Phase 1-4: 外部レビュー（External Review）

`requirements.md` と `design.md` がそろったら、シニア/スタッフ視点の red-team レビューを `codex` / `gemini` / `claude (subagent)` の **3 者並列で自動起動**する。詳細手順・プロンプト・反映ルールは `references/external-review.md` を参照。

**フロー:**
1. `/tmp/sdd-reviews/{feature-name}/` を作成し、共通プロンプトを `_prompt.txt` に書き出す
2. 1 メッセージ内で Bash 2 件 (codex / gemini) + Agent 1 件 (claude) を**並列起動**
3. 出力: `/tmp/sdd-reviews/{feature-name}/{codex,gemini,claude}.md`
4. メインが 3 つを読み、共通指摘・矛盾・重要度を整理してユーザーに統合サマリーを提示
5. 反映ルールに従って `requirements.md` / `design.md` を更新
6. 反映完了後、`/tmp/sdd-reviews/{feature-name}/done` を作成して Phase 1 完了。**有効期限は mtime + 7 日**（過ぎたら次回 `/my-sdd` 起動時に自動で再レビュー）

**反映ルール（重要）:**
- **挙動・データモデルが変わらない指摘**（用語統一、Open Questions 追記、Risks/Rejected alternatives 補完、構造整理など）→ **自動で `requirements.md` / `design.md` を更新**
- **挙動・API 仕様・スキーマ・DB の持ち方・移行戦略が変わる指摘** → 変更内容と理由を**ユーザーに提示し、合意の上で反映**
- **採用しない指摘** → `/tmp/sdd-reviews/{feature-name}/decisions.md` に「不採用 + 理由」を記録
- 判断が微妙な場合は確認側に倒す

### Phase 1 出力

```
docs/specs/{feature-name}/
├── requirements.md
└── design.md

/tmp/sdd-reviews/{feature-name}/
├── _prompt.txt    # レビュー共通プロンプト（再実行用）
├── codex.md       # codex の生レビュー
├── gemini.md      # gemini の生レビュー
├── claude.md      # claude subagent の生レビュー
├── decisions.md   # 採否の記録
└── done           # Phase 1-4 完了マーカー（mtime + 7 日 が有効期限）
```

`{feature-name}` はケバブケース（例: `user-authentication`）で命名する。
`/tmp/sdd-reviews/` は OS 一時領域。リポジトリ外で永続性なし。`done` の有効期限を過ぎたら次回起動時に自動で再レビューする。コミット対象は `docs/specs/` のみ。

### Phase 1 完了時のメッセージ

```
✅ Phase 1 (Plan) が完了しました（Investigation → Clarify → Specify → Design → External Review）。

📁 出力ファイル:
  - docs/specs/{feature-name}/requirements.md
  - docs/specs/{feature-name}/design.md
  - /tmp/sdd-reviews/{feature-name}/{codex,gemini,claude}.md

🔎 外部レビューサマリー:
  - 自動反映（挙動/DB変更なし）: A件
  - ユーザー合意の上で反映（挙動/DB変更あり）: B件
  - 不採用: C件（理由は decisions.md 参照）

📋 要件サマリー:
  - ユーザーストーリー: X件
  - 受入基準: Y件
  - 優先度 Must: Z件

▶️ Phase 2 (Tasks) に進みますか？ タスク分解を開始します。
   または `/my-sdd docs/specs/{feature-name}` で後から再開できます。
```

**重要: 必ずスペックディレクトリのパス（`docs/specs/{feature-name}`）を含めること。パスなしでコマンドのみを提示することは禁止。**

### Phase 1 のルール

1. **事前調査を先に行う**: Phase 1-0 で十分時間をかけて既存コード・ADR・関連 PR を調査し、自明な決定はユーザーに聞かない
2. **要件はユーザー承認を得る**: 要件定義の内容はユーザーに確認してから技術設計に進む
3. **設計はシニア/スタッフ視点で潰し切る**: `references/senior-review-checklist.md` の全観点を網羅し、Risks / Rejected alternatives / Open Questions を必ず記載
4. **外部レビューは必ず通す**: Phase 1-3 完了後に Phase 1-4 (External Review) を 3 者並列・自動で実行する
5. **挙動/DB 変更を伴う指摘はユーザー合意**: それ以外（用語整理・項目補完・構造整理）は自動反映。判断が微妙なら確認側に倒す
6. **Phase 2 に自動で進まない**: レビュー反映完了（`done` マーカー作成）後、ユーザーの承認を得てから Phase 2 に遷移する

---

## Phase 2: Tasks（タスク分解）

### Phase 2 前提条件

以下のファイルが存在すること:
- `docs/specs/{feature-name}/requirements.md`
- `docs/specs/{feature-name}/design.md`

### Phase 2-1: 仕様の読み込み

1. `requirements.md` と `design.md` を読み込む
2. ユーザーストーリーと受入基準を把握

### Phase 2-2: タスク分解

以下のルールに従ってタスクを分解する:

**分解の原則:**
1. **テストファースト**: テスト作成タスクを実装タスクの前に配置
2. **小さく**: 1タスク = 1つの明確な成果物（1ファイルまたは1機能）
3. **独立性**: 可能な限り他タスクへの依存を減らす
4. **並列化**: 独立したタスクには `[P]` マークを付ける

**タスクの粒度:**
- 良い例: 「UserRepository の create メソッドを実装する」
- 悪い例: 「ユーザー機能を実装する」

### Phase 2-3: tasks.md の作成

```markdown
# {機能名} タスク一覧

## 概要
- **総タスク数**: X件
- **並列実行可能**: Y件

## 依存関係図

```
Task 1 (テスト) ──→ Task 2 (実装)
      ↓
Task 3 [P] (並列可能)
Task 4 [P] (並列可能)
      ↓
Task 5 (統合テスト)
```

## タスク詳細

### Task 1: [テスト] {テスト対象}のテストを作成
- **ステータス**: [ ] 未着手
- **ファイル**: `tests/test_{module}.py`
- **依存**: なし
- **並列**: -
- **受入基準**: AC-1.1, AC-1.2
- **詳細**:
  - テストケース1: ...
  - テストケース2: ...

### Task 2: [実装] {機能}を実装
- **ステータス**: [ ] 未着手
- **ファイル**: `src/{module}.py`
- **依存**: Task 1
- **並列**: -
- **受入基準**: AC-1.1
- **詳細**:
  - ...

### Task 3: [P] [実装] {独立した機能}を実装
- **ステータス**: [ ] 未着手
- **ファイル**: `src/{other_module}.py`
- **依存**: なし
- **並列**: Task 4 と並列実行可能
- **受入基準**: AC-2.1
- **詳細**:
  - ...

...
```

### Phase 2 出力

```
docs/specs/{feature-name}/
├── requirements.md  (既存)
├── design.md        (既存)
└── tasks.md         (新規作成)
```

### Phase 2 完了時のメッセージ

```
✅ Phase 2 (Tasks) が完了しました。

📁 出力ファイル:
  - docs/specs/{feature-name}/tasks.md

📋 タスクサマリー:
  - 総タスク数: X件
  - テストタスク: Y件
  - 実装タスク: Z件
  - 並列実行可能: W件

📊 依存関係:
  Task 1 → Task 2 → Task 5
  Task 3 [P], Task 4 [P] → Task 5

▶️ Phase 3 (Impl) に進みますか？ 実装を開始します。
   または `/my-sdd docs/specs/{feature-name}` で後から再開できます。
```

**重要: 必ずスペックディレクトリのパス（`docs/specs/{feature-name}`）を含めること。パスなしでコマンドのみを提示することは禁止。**

### Phase 2 のルール

1. **実装に進まない**: Phase 2 ではタスク分解のみ行い、コードは書かない
2. **テストファースト**: 必ずテストタスクを実装タスクの前に配置
3. **ファイルパスを明記**: 各タスクに対象ファイルパスを明記
4. **Phase 3 に自動で進まない**: ユーザーの承認を得てから Phase 3 に遷移する

---

## Phase 3: Impl（実装）

### Phase 3 前提条件

以下のファイルが存在すること:
- `docs/specs/{feature-name}/requirements.md`
- `docs/specs/{feature-name}/design.md`
- `docs/specs/{feature-name}/tasks.md`

### Phase 3-1: タスクの読み込み

1. `tasks.md` を読み込む
2. 未完了タスクを特定
3. 依存関係を確認
4. TodoWriteでタスク一覧を登録

### Phase 3-2: タスク実行

**実行ルール:**

1. **依存関係を尊重**: 依存タスクが完了してから実行
2. **並列実行**: `[P]` マークのタスクはTaskエージェントで並列実行
3. **テストファースト**: テストタスクを先に実行
4. **進捗更新**: 各タスク完了時にTodoWriteとtasks.mdを更新

**Taskエージェントの活用:**

```
# 並列実行可能なタスクがある場合
Task 3 [P] と Task 4 [P] を同時に起動:

<Task tool>
  subagent_type: general-purpose
  description: "Implement {task_3_name}"
  prompt: |
    以下のタスクを実装してください:

    ## タスク情報
    - ファイル: {file_path}
    - 受入基準: {acceptance_criteria}
    - 詳細: {details}

    ## 既存コードの参考
    - {reference_code}

    ## 制約
    - テストが通ることを確認
    - 既存のコーディング規約に従う
</Task>

<Task tool>
  subagent_type: general-purpose
  description: "Implement {task_4_name}"
  ...
</Task>
```

**順次実行のタスク:**

依存関係があるタスクは順次実行する:

```
Task 1 (テスト作成) → 完了確認 → Task 2 (実装) → 完了確認
```

### Phase 3-3: テスト実行

各実装タスク完了後、関連するテストを実行:

```bash
# プロジェクトのテストコマンドを使用
pytest tests/test_{module}.py -v
```

テストが失敗した場合:
1. エラー内容を確認
2. 実装を修正
3. 再度テスト実行

### Phase 3-4: tasks.md の更新

タスク完了時に `tasks.md` のステータスを更新:

```markdown
### Task 1: [テスト] UserRepositoryのテストを作成
- **ステータス**: [x] 完了 ✅
```

### 実行パターン

#### パターン A: 順次実行（依存関係あり）

```
Main:    [Task 1: テスト] → [Task 2: 実装] → [Task 3: 統合テスト]
```

#### パターン B: 並列実行（独立タスク）

```
Main:         [Task 1: テスト]
                    ↓
Subagent 1:   [Task 2 [P]: 機能A]  ─┬─→ [Task 4: 統合]
Subagent 2:   [Task 3 [P]: 機能B]  ─┘
```

#### パターン C: バックグラウンド検証

```
Main:           [実装タスク]
                     ↓
BG (run_in_background): [テスト実行] → 結果を後で確認
```

### Phase 3 完了時のメッセージ

```
✅ Phase 3 (Impl) が完了しました。

📋 タスク完了状況:
  - 完了: X/Y件
  - テストタスク: A/B件 ✅
  - 実装タスク: C/D件 ✅

🧪 テスト結果:
  - 実行: Z件
  - 成功: Z件
  - 失敗: 0件

📁 変更ファイル:
  - src/{module}.py (新規)
  - tests/test_{module}.py (新規)
  - ...

👉 次のステップ:
  - コードレビューを依頼
  - `/pull-request` でPRを作成
  - `/my-sdd {new-feature}` で次の機能を計画
```

### Phase 3 のルール

1. **タスク定義に従う**: tasks.md に定義されたタスクのみ実行
2. **テストファースト**: テストタスクを実装タスクの前に実行
3. **進捗を可視化**: TodoWriteで常に進捗を追跡
4. **並列化を活用**: `[P]` マークのタスクはTaskエージェントで並列実行
5. **失敗時は停止**: テスト失敗時は修正してから次に進む

### エラー時の対応

| エラー | 対応 |
|--------|------|
| テスト失敗 | 実装を修正し再テスト |
| 依存ファイルなし | 依存タスクの完了を確認 |
| 型エラー | 修正してから続行 |
| 不明なエラー | ユーザーに報告し指示を仰ぐ |

---

## 完了報告

全タスクが完了している場合に表示:

```
🎉 すべてのタスクが完了しています。

📁 スペック: docs/specs/{feature-name}/
📋 タスク完了状況: X/X件 (100%)

👉 次のステップ:
  - コードレビューを依頼
  - `/pull-request` でPRを作成
  - `/my-sdd {new-feature}` で次の機能を計画
```

---

## 共通ルール

1. **フェーズ間の自動遷移はユーザー確認を経る**: Phase 1→2、Phase 2→3 の遷移前に必ずユーザーの承認を得る
2. **日本語で記述**: すべての仕様書・タスク説明は日本語で記述する
3. **事前調査を先に行う**: Phase 1-0 で既存コード・ADR・関連 PR を時間をかけて調査し、コードで分かることはユーザーに聞かない
4. **シニア/スタッフ視点で潰す**: Phase 1-3 で `references/senior-review-checklist.md` の全観点を網羅する
5. **外部レビューを必ず通す**: Phase 1-4 で codex / gemini / claude を 3 並列・自動で起動する。挙動/DB 変更を伴う指摘のみユーザー合意、それ以外は自動反映
6. **テストファースト**: Phase 2 でテストタスクを実装タスクの前に配置、Phase 3 でテストを先に実行する
7. **tasks.md はファイルとして出力**: TodoWrite だけでなく必ず tasks.md ファイルを作成・更新する
8. **スペックパスを常に明示**: 完了メッセージ・次のステップでは必ず `docs/specs/{feature-name}` パスを含める。パスなしでコマンドのみを提示することは禁止
9. **フェーズ表示**: 現在どのフェーズ（1-0 / 1-1 / ... / 1-4 / 2 / 3）を実行しているかを常に明示する
