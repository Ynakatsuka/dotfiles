---
name: my-ccv-artifact
description: >-
  Register HTML artifacts to Claude Code Viewer (CCV) via its local API.
  Use when the user asks to create a qualitative evaluation dashboard, register an HTML artifact to CCV,
  or view/manage CCV artifacts (e.g., "CCVに登録", "アーティファクト作成", "CCV artifact", "定性評価を登録").
  Do NOT use for general HTML file creation, static site generation, or non-CCV artifact management.
argument-hint: "[name]"
---

# CCV Artifact — HTML Artifact Registration

CCV (Claude Code Viewer) のローカル API を使って HTML アーティファクトを作成・登録する。

## CCV Server

- Base URL: `http://localhost:3434`

## Workflow

### Step 1: Identify the project

```bash
curl -s http://localhost:3434/api/projects | jq .
```

- `meta.projectPath` で現在のプロジェクトディレクトリと照合し、対象の `id` を特定する
- 現在の作業ディレクトリ (`pwd`) と一致するプロジェクトを自動選択する
- 一致しない場合はユーザーに確認する

### Step 2: Generate HTML content

ユーザーの要求に応じて HTML を生成する。典型的な用途:

- **定性評価ダッシュボード**: データの可視化、比較表
- **レポート**: 分析結果のまとめ
- **プレビュー**: UI モックアップ

HTML の要件:
- 単一ファイルで完結する（外部リソースへの依存なし）
- インラインCSS/JSを使用する
- `<html>`, `<head>`, `<body>` タグを含む完全なHTML文書にする
- 日本語コンテンツの場合は `<meta charset="utf-8">` を含める

### Step 3: Register the artifact

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

### Step 4: Confirm and report

登録成功後、以下を報告する:

1. アーティファクト ID（レスポンスの `id`）
2. プレビュー URL: `http://localhost:3434/api/projects/{projectId}/artifacts/{artifactId}/html`
3. 登録内容の概要

## API Reference

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/projects` | プロジェクト一覧 |
| GET | `/api/projects/:projectId/artifacts` | アーティファクト一覧 |
| POST | `/api/projects/:projectId/artifacts` | 新規作成 |
| PUT | `/api/projects/:projectId/artifacts/:artifactId` | 更新（name, fileName, html すべて省略可） |
| DELETE | `/api/projects/:projectId/artifacts/:artifactId` | 削除 |
| GET | `/api/projects/:projectId/artifacts/:artifactId/html` | HTML 本体取得 |

## Error Handling

- CCV サーバーが起動していない場合: `curl: (7) Failed to connect` → ユーザーに CCV サーバーの起動を案内する
- プロジェクトが見つからない場合: 一覧を表示してユーザーに選択を求める

## Notes

- 既存アーティファクトの更新は PUT を使い、変更したいフィールドのみ送信する
- `list` サブコマンド的に使われた場合は GET で一覧を返す
- レスポンスの `id` は ULID 形式で自動生成される
