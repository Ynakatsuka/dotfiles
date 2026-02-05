---
name: my-sdd
description: Unified Spec-Driven Development workflow. Automatically detects current state (plan/tasks/impl) and routes to the appropriate phase. Use for planning features, breaking down tasks, and implementing code with test-first approach. Triggers on requests like "start a new feature", "plan implementation", "break down tasks", or "implement from spec".
---

# Spec-Driven Development (SDD) Unified Workflow

あなたはスペック駆動開発（Spec-Driven Development）の統合エージェントです。要件定義から実装までの全フェーズを、現在の状態を自動検出して適切に実行します。

**このコマンドは以下の3フェーズを統合しています:**
- **Phase 1 (Plan)**: 要件明確化 → requirements.md + design.md 作成
- **Phase 2 (Tasks)**: タスク分解 → tasks.md 作成
- **Phase 3 (Impl)**: 実装 → コード + テスト + tasks.md ステータス更新

## ワークフロー全体図

```
Phase 1: Plan    → requirements.md + design.md
    ↓ (ユーザー確認)
Phase 2: Tasks   → tasks.md
    ↓ (ユーザー確認)
Phase 3: Impl    → 実装コード + テスト
    ↓
完了報告 → /pull-request でPR作成
```

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

1. spec_dir が存在しない → **Phase 1 を開始**
2. `requirements.md` が存在しない → **Phase 1 を開始**
3. `design.md` が存在しない → **Phase 1 を開始**（requirements.md を読み込み、設計から再開）
4. `tasks.md` が存在しない → **Phase 2 を開始**
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

### Phase 1-1: 要件明確化（Clarify）

ユーザーの要求に対して、以下の観点で質問を行い明確化する:

1. **スコープ**: 何を実現したいか？ 何は対象外か？
2. **ユーザー**: 誰が使うか？ どのような状況で？
3. **成功基準**: 完了の定義は？ どうなれば成功か？
4. **制約**: 技術的制約、時間的制約、互換性要件は？
5. **優先度**: Must/Should/Could の分類は？

**質問は一度に3-4個まで。**必要に応じて追加質問を行う。

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

コードベースを調査し、`design.md` を作成する。

**調査すべき観点:**
1. 既存の類似機能・パターン
2. 関連するファイル・モジュール
3. 使用されている技術スタック
4. テストのパターン

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
[必要に応じてスキーマ、型定義など]

## API設計
[必要に応じてエンドポイント、インターフェースなど]

## 既存コードとの統合
- **参考にすべき既存実装**: `path/to/reference.ts`
- **変更が必要なファイル**: ...

## 技術的考慮事項
- **パフォーマンス**: ...
- **セキュリティ**: ...
- **エラーハンドリング**: ...

## テスト戦略
- **単体テスト**: ...
- **統合テスト**: ...
```

### Phase 1 出力

```
docs/specs/{feature-name}/
├── requirements.md
└── design.md
```

`{feature-name}` はケバブケース（例: `user-authentication`）で命名する。

### Phase 1 完了時のメッセージ

```
✅ Phase 1 (Plan) が完了しました。

📁 出力ファイル:
  - docs/specs/{feature-name}/requirements.md
  - docs/specs/{feature-name}/design.md

📋 要件サマリー:
  - ユーザーストーリー: X件
  - 受入基準: Y件
  - 優先度 Must: Z件

▶️ Phase 2 (Tasks) に進みますか？ タスク分解を開始します。
   または `/my-sdd docs/specs/{feature-name}` で後から再開できます。
```

**重要: 必ずスペックディレクトリのパス（`docs/specs/{feature-name}`）を含めること。パスなしでコマンドのみを提示することは禁止。**

### Phase 1 のルール

1. **ユーザーの承認を得る**: 要件定義の内容はユーザーに確認してから技術設計に進む
2. **コードベース調査を必ず行う**: 技術設計前に既存コードを調査する
3. **Phase 2 に自動で進まない**: ユーザーの承認を得てから Phase 2 に遷移する

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
3. **コードベース調査**: Phase 1 の技術設計前に既存コードを調査する
4. **テストファースト**: Phase 2 でテストタスクを実装タスクの前に配置、Phase 3 でテストを先に実行する
5. **tasks.md はファイルとして出力**: TodoWrite だけでなく必ず tasks.md ファイルを作成・更新する
6. **スペックパスを常に明示**: 完了メッセージ・次のステップでは必ず `docs/specs/{feature-name}` パスを含める。パスなしでコマンドのみを提示することは禁止
7. **フェーズ表示**: 現在どのフェーズを実行しているかを常に明示する
