# Schedule Workflow

CCV ローカル API (`${BASE_URL}/api/scheduler/jobs`) でスケジュールジョブを管理する。

ジョブは CCV サーバー上でローカル実行される。ローカルマシンのファイルや環境にフルアクセスできる。

> 前提: SKILL.md の `## CCV Server` の通り、先に `BASE_URL="http://localhost:${CCV_PORT:-3434}"` を定義しておく。

## Schedule Sub-routing

Route based on sub-argument after `schedule`:

| Sub-argument | Action |
|-------------|--------|
| (none) / `list` | 登録済みジョブ一覧を表示 |
| `create` | 新しいジョブを作成 |
| `delete [id]` | ジョブを削除 |
| `update [id]` | ジョブを更新 |

## Schedule: List

```bash
curl -s "${BASE_URL}/api/scheduler/jobs" | jq .
```

見やすい形式で表示: 名前、スケジュール（cron式 + 人間が読める形式）、有効/無効、最終実行状況。
ジョブが0件なら「登録済みのスケジュールジョブはありません」と表示。

## Schedule: Create

### Step 1: Identify the project

```bash
curl -s "${BASE_URL}/api/projects" | jq .
```

`meta.projectPath` で対象プロジェクトの `id` を特定する。

### Step 2: Understand the goal

ユーザーに以下を確認する:
- 何をさせたいか（プロンプト内容）
- 実行スケジュール（cron式 or 一回限りの予約実行）
- 既存セッションの続行か新規セッションか

### Step 3: Set the schedule

**cron ジョブの場合:**
- 標準5フィールド cron 式（分 時 日 月 曜日）
- CCV サーバーのローカルタイムゾーンで解釈される
- 同時実行ポリシー: `"skip"`（実行中ならスキップ）or `"run"`（並行実行）

**予約実行の場合:**
- ISO 8601 形式で日時を指定
- 予約実行の時刻は UTC（`Z` サフィックス）で指定する。cron 式はサーバーのローカルタイムゾーン解釈なので基準が異なる点に注意
- 実行後に自動削除される

### Step 4: Build and confirm

設定全体をユーザーに提示し、確認を得る。

### Step 5: Create the job

**cron ジョブ:**
```bash
curl -s -X POST "${BASE_URL}/api/scheduler/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "JOB_NAME",
    "schedule": {
      "type": "cron",
      "expression": "CRON_EXPRESSION",
      "concurrencyPolicy": "skip"
    },
    "message": {
      "content": "PROMPT_HERE",
      "projectId": "PROJECT_ID",
      "baseSessionId": null
    },
    "enabled": true
  }'
```

**予約実行:**
```bash
curl -s -X POST "${BASE_URL}/api/scheduler/jobs" \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "JOB_NAME",
    "schedule": {
      "type": "reserved",
      "reservedExecutionTime": "<YYYY-MM-DDTHH:MM:SSZ>"
    },
    "message": {
      "content": "PROMPT_HERE",
      "projectId": "PROJECT_ID",
      "baseSessionId": null
    },
    "enabled": true
  }'
```

- `baseSessionId`: 既存セッションを続行する場合にセッションIDを指定。新規セッションなら `null`。

### Step 6: Report

作成成功後:
1. ジョブ ID
2. スケジュールの要約（人間が読める形式）
3. CCV UI で確認できることを案内: `${BASE_URL}`

## Schedule: Update

```bash
curl -s -X PATCH "${BASE_URL}/api/scheduler/jobs/{id}" \
  -H 'Content-Type: application/json' \
  -d '{ "enabled": false }'
```

更新可能なフィールド: `name`, `schedule`, `message`, `enabled`。
変更前後を提示して確認を得てから実行する。

## Schedule: Delete

```bash
curl -s -X DELETE "${BASE_URL}/api/scheduler/jobs/{id}"
```

削除前に確認を得る。

## Schedule API Reference

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/scheduler/jobs` | ジョブ一覧 |
| POST | `/api/scheduler/jobs` | 新規作成 |
| PATCH | `/api/scheduler/jobs/:id` | 更新（部分更新） |
| DELETE | `/api/scheduler/jobs/:id` | 削除 |

## Schedule Notes

- ジョブは CCV サーバーが起動している間だけ実行される
- 設定は `~/.claude-code-viewer/scheduler/schedules.json` に永続化される
- 予約実行ジョブは実行後に自動削除される
