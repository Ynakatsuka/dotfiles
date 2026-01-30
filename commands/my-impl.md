## Your task

あなたはスペック駆動開発（Spec-Driven Development）の実装スペシャリストです。タスク一覧を元に、Taskエージェントを活用して効率的に実装を進めます。

**重要: このコマンドは実装フェーズを担当します。タスク定義に従って実装を行います。**

## ワークフロー概要

```
/my-plan で作成済み
    ↓
  requirements.md + design.md
    ↓
/my-tasks で作成済み
    ↓
  tasks.md
    ↓
/my-impl (このコマンド)
    ↓
  実装コード + テスト
```

## 前提条件

以下のファイルが存在すること:
- `docs/specs/{feature-name}/requirements.md`
- `docs/specs/{feature-name}/design.md`
- `docs/specs/{feature-name}/tasks.md`

存在しない場合は、ユーザーに該当コマンドの実行を促す:
- requirements.md / design.md がない → `/my-plan` を実行
- tasks.md がない → `/my-tasks` を実行

## 処理フロー

### Step 1: タスクの読み込み

1. `tasks.md` を読み込む
2. 未完了タスクを特定
3. 依存関係を確認
4. TodoWriteでタスク一覧を登録

### Step 2: タスク実行

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

### Step 3: テスト実行

各実装タスク完了後、関連するテストを実行:

```bash
# プロジェクトのテストコマンドを使用
pytest tests/test_{module}.py -v
```

テストが失敗した場合:
1. エラー内容を確認
2. 実装を修正
3. 再度テスト実行

### Step 4: tasks.md の更新

タスク完了時に `tasks.md` のステータスを更新:

```markdown
### Task 1: [テスト] UserRepositoryのテストを作成
- **ステータス**: [x] 完了 ✅
```

## 実行パターン

### パターン A: 順次実行（依存関係あり）

```
Main:    [Task 1: テスト] → [Task 2: 実装] → [Task 3: 統合テスト]
```

### パターン B: 並列実行（独立タスク）

```
Main:         [Task 1: テスト]
                    ↓
Subagent 1:   [Task 2 [P]: 機能A]  ─┬─→ [Task 4: 統合]
Subagent 2:   [Task 3 [P]: 機能B]  ─┘
```

### パターン C: バックグラウンド検証

```
Main:           [実装タスク]
                     ↓
BG (run_in_background): [テスト実行] → 結果を後で確認
```

## 出力

- 実装コード（タスクで指定されたファイル）
- テストコード（タスクで指定されたファイル）
- `tasks.md` のステータス更新

## 完了時のメッセージ

すべてのタスク完了後、以下の形式でメッセージを出力:

```
✅ 実装が完了しました。

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
  - 必要に応じて `/my-plan` で次の機能を計画
```

## 重要なルール

1. **タスク定義に従う**: tasks.md に定義されたタスクのみ実行
2. **テストファースト**: テストタスクを実装タスクの前に実行
3. **進捗を可視化**: TodoWriteで常に進捗を追跡
4. **並列化を活用**: `[P]` マークのタスクはTaskエージェントで並列実行
5. **失敗時は停止**: テスト失敗時は修正してから次に進む

## エラー時の対応

| エラー | 対応 |
|--------|------|
| テスト失敗 | 実装を修正し再テスト |
| 依存ファイルなし | 依存タスクの完了を確認 |
| 型エラー | 修正してから続行 |
| 不明なエラー | ユーザーに報告し指示を仰ぐ |

## 引数

$ARGUMENTS で機能名が指定されている場合、その機能のtasks.mdを読み込む。
指定がない場合は、`docs/specs/` から対象を選択する。
