---
name: my-ccv
description: >-
  Manage Claude Code Viewer (CCV): register HTML artifacts or schedule remote agent jobs.
  Use when user asks to create dashboards, register artifacts to CCV, manage CCV artifacts,
  schedule remote agents, or create CCV triggers
  (e.g., "CCVに登録", "アーティファクト作成", "CCV artifact", "定性評価を登録",
  "スケジュール登録", "定期実行", "トリガー作成", "CCV schedule").
  Do NOT use for general HTML creation, static site generation, or local cron jobs (use CronCreate for local).
argument-hint: "[artifact [name] | schedule [list|create|run|get|update]]"
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

`RemoteTrigger` ツールでリモートエージェントのスケジュールジョブを管理する。

**重要**: リモートエージェントは Anthropic クラウド上で実行される。ローカルマシンのファイルや環境変数にはアクセスできない。

## Schedule Sub-routing

Route based on sub-argument after `schedule`:

| Sub-argument | Action |
|-------------|--------|
| (none) / `list` | 登録済みトリガー一覧を表示 |
| `create` | 新しいトリガーを作成 |
| `run [id]` | トリガーを即時実行 |
| `get [id]` | トリガーの詳細を取得 |
| `update [id]` | トリガーを更新 |

## Schedule: List

1. `RemoteTrigger` ツールを `{action: "list"}` で呼び出す
2. 見やすい形式で表示: 名前、スケジュール（人間が読める形式）、有効/無効、リポジトリ
3. トリガーが0件なら「登録済みのスケジュールジョブはありません」と表示

## Schedule: Create

### Step 1: Understand the goal

ユーザーに以下を確認する:
- リモートエージェントに何をさせたいか
- 対象リポジトリ（デフォルト: `https://github.com/Ynakatsuka/dotfiles`）
- リモート実行であることを伝える（ローカルファイルにはアクセスできない）

### Step 2: Craft the prompt

効果的なプロンプトを一緒に作成する:
- 何をするか具体的に
- 成功の定義を明確に
- 対象ファイル・領域を明示
- 取るべきアクション（PR作成、コミット、分析のみ等）を指定

### Step 3: Set the schedule

- ユーザーのタイムゾーンは **Asia/Tokyo**
- cron式は **UTC** で指定する必要がある（JST - 9時間）
- 変換を必ず確認する（例: 「JST 9:00 = UTC 0:00 なので `0 0 * * 1-5`」）
- 最小間隔は **1時間**
- `:00` や `:30` は避け、少しずらす（例: `57 23 * * *` for JST 8:57am）

### Step 4: Choose the model

デフォルト: `claude-sonnet-4-6`。ユーザーに確認し、希望があれば変更する。

### Step 5: Build and confirm

設定全体をユーザーに提示し、確認を得る。

### Step 6: Create the trigger

`RemoteTrigger` ツールで作成する。ボディの構造:

```json
{
  "name": "AGENT_NAME",
  "cron_expression": "CRON_EXPR_IN_UTC",
  "enabled": true,
  "job_config": {
    "ccr": {
      "environment_id": "env_01KVzCYJ8EWndiXmzCoYFn8V",
      "session_context": {
        "model": "claude-sonnet-4-6",
        "sources": [
          {"git_repository": {"url": "https://github.com/USER/REPO"}}
        ],
        "allowed_tools": ["Bash", "Read", "Write", "Edit", "Glob", "Grep"]
      },
      "events": [
        {"data": {
          "uuid": "<generate a lowercase v4 UUID>",
          "session_id": "",
          "type": "user",
          "parent_tool_use_id": null,
          "message": {"content": "PROMPT_HERE", "role": "user"}
        }}
      ]
    }
  }
}
```

UUID は自分で生成する（`uuidgen | tr '[:upper:]' '[:lower:]'` で取得可能）。

### Step 7: Report

作成成功後:
1. トリガー ID
2. 管理 URL: `https://claude.ai/code/scheduled/{TRIGGER_ID}`
3. スケジュールの要約（人間が読める形式 + UTC/JST 両方）

## Schedule: Run

1. ID が指定されていなければ一覧を表示してユーザーに選択を求める
2. 確認後、`{action: "run", trigger_id: "..."}` で実行
3. 結果を報告

## Schedule: Get / Update

- **get**: `{action: "get", trigger_id: "..."}` で詳細を取得し、見やすく表示
- **update**: 変更前後を提示して確認を得てから `{action: "update", trigger_id: "...", body: {...}}` で更新

## Schedule: Delete

API ではトリガーを削除できない。ユーザーに以下を案内する:
- 管理画面: https://claude.ai/code/scheduled
- 代替: `enabled: false` で無効化できる

## Schedule Notes

- 環境 ID: `env_01KVzCYJ8EWndiXmzCoYFn8V`（Anthropic Cloud デフォルト）
- MCP コネクタが必要な場合: https://claude.ai/settings/connectors で事前に接続が必要
- プロンプトはリモートエージェントの唯一のコンテキスト。自己完結した内容にする
