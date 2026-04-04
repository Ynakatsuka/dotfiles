---
name: my-ccv
description: >-
  Manage Claude Code Viewer (CCV): register HTML artifacts or schedule jobs via CCV local API.
  Use when user asks to create dashboards, register artifacts to CCV, manage CCV artifacts,
  schedule CCV jobs, or manage CCV scheduler
  (e.g., "CCVに登録", "アーティファクト作成", "CCV artifact", "定性評価を登録",
  "スケジュール登録", "定期実行", "CCV schedule").
  Do NOT use for general HTML creation, static site generation, or Anthropic remote triggers.
argument-hint: "[artifact [name] | schedule [list|create|delete|update]]"
---

# CCV — Claude Code Viewer Management

CCV (Claude Code Viewer) のアーティファクト登録とリモートエージェントのスケジュール管理を行う統合スキル。

## Argument Routing

Route based on `$ARGUMENTS`:

1. **`schedule ...`**: → Schedule workflow (below)
2. **`artifact ...`** or **no argument** or **other**: → Artifact workflow (below)

---

# Artifact Workflow

CCV ローカル API を使って HTML アーティファクトを作成・登録する。

## CCV Server

- Base URL: `http://localhost:3434`

## Step 1: Identify the project

```bash
curl -s http://localhost:3434/api/projects | jq .
```

- `meta.projectPath` で現在のプロジェクトディレクトリと照合し、対象の `id` を特定する
- 現在の作業ディレクトリ (`pwd`) と一致するプロジェクトを自動選択する
- 一致しない場合はユーザーに確認する

## Step 2: Generate HTML content

ユーザーの要求に応じて HTML を生成する。典型的な用途:

- **定性評価ダッシュボード**: データの可視化、比較表
- **レポート**: 分析結果のまとめ
- **プレビュー**: UI モックアップ

HTML の要件:
- 単一ファイルで完結する（外部リソースへの依存なし）
- インラインCSS/JSを使用する
- `<html>`, `<head>`, `<body>` タグを含む完全なHTML文書にする
- 日本語コンテンツの場合は `<meta charset="utf-8">` を含める

## Step 3: Register the artifact

```bash
curl -s -X POST "http://localhost:3434/api/projects/{projectId}/artifacts" \
  -H 'Content-Type: application/json' \
  -d @/tmp/ccv-artifact.json
```

リクエストボディ (`/tmp/ccv-artifact.json`):
```json
{
  "name": "DISPLAY_NAME",
  "fileName": "FILENAME.html",
  "html": "FULL_HTML_STRING"
}
```

- `name`: ユーザーに表示される名前（日本語可）
- `fileName`: 保存時のファイル名（英数字・ハイフン推奨、`.html` 拡張子必須）
- `html`: 完全な HTML 文字列

HTML が大きい場合は必ず一時ファイル経由で送信する。JSON の構築には `jq` を使い、エスケープ漏れを防ぐ:

```bash
jq -n --arg name "$NAME" --arg fileName "$FILENAME" --arg html "$(cat /tmp/artifact.html)" \
  '{name: $name, fileName: $fileName, html: $html}' > /tmp/ccv-artifact.json
curl -s -X POST "http://localhost:3434/api/projects/{projectId}/artifacts" \
  -H 'Content-Type: application/json' -d @/tmp/ccv-artifact.json
```

## Step 4: Confirm and report

登録成功後、以下を報告する:

1. アーティファクト ID（レスポンスの `id`）
2. プレビュー URL: `http://localhost:3434/api/projects/{projectId}/artifacts/{artifactId}/html`
3. 登録内容の概要

## Artifact API Reference

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/projects` | プロジェクト一覧 |
| GET | `/api/projects/:projectId/artifacts` | アーティファクト一覧 |
| POST | `/api/projects/:projectId/artifacts` | 新規作成 |
| PUT | `/api/projects/:projectId/artifacts/:artifactId` | 更新（name, fileName, html すべて省略可） |
| DELETE | `/api/projects/:projectId/artifacts/:artifactId` | 削除 |
| GET | `/api/projects/:projectId/artifacts/:artifactId/html` | HTML 本体取得 |

## Artifact Error Handling

- CCV サーバーが起動していない場合: `curl: (7) Failed to connect` → ユーザーに CCV サーバーの起動を案内する
- プロジェクトが見つからない場合: 一覧を表示してユーザーに選択を求める

## Artifact Notes

- 既存アーティファクトの更新は PUT を使い、変更したいフィールドのみ送信する
- `list` サブコマンド的に使われた場合は GET で一覧を返す
- レスポンスの `id` は ULID 形式で自動生成される

---

# Schedule Workflow

CCV ローカル API (`http://localhost:3434/api/scheduler/jobs`) でスケジュールジョブを管理する。

ジョブは CCV サーバー上でローカル実行される。ローカルマシンのファイルや環境にフルアクセスできる。

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
curl -s http://localhost:3434/api/scheduler/jobs | jq .
```

見やすい形式で表示: 名前、スケジュール（cron式 + 人間が読める形式）、有効/無効、最終実行状況。
ジョブが0件なら「登録済みのスケジュールジョブはありません」と表示。

## Schedule: Create

### Step 1: Identify the project

```bash
curl -s http://localhost:3434/api/projects | jq .
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
- 実行後に自動削除される

### Step 4: Build and confirm

設定全体をユーザーに提示し、確認を得る。

### Step 5: Create the job

**cron ジョブ:**
```bash
curl -s -X POST http://localhost:3434/api/scheduler/jobs \
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
curl -s -X POST http://localhost:3434/api/scheduler/jobs \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "JOB_NAME",
    "schedule": {
      "type": "reserved",
      "reservedExecutionTime": "2025-10-25T00:00:00Z"
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
3. CCV UI で確認できることを案内: `http://localhost:3434`

## Schedule: Update

```bash
curl -s -X PATCH "http://localhost:3434/api/scheduler/jobs/{id}" \
  -H 'Content-Type: application/json' \
  -d '{ "enabled": false }'
```

更新可能なフィールド: `name`, `schedule`, `message`, `enabled`。
変更前後を提示して確認を得てから実行する。

## Schedule: Delete

```bash
curl -s -X DELETE "http://localhost:3434/api/scheduler/jobs/{id}"
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
