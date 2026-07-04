---
name: my-ccv
description: >-
  Manage Claude Code Viewer (CCV): preview in-progress CCV changes on ccv-preview,
  register HTML artifacts, download files, or schedule jobs via CCV local API.
  Use when user asks for CCV preview, ccv-preview, browser visual QA, UI/UX validation,
  CCV artifacts, CCV file download, or CCV scheduler jobs. Treat preview/プレビュー
  as the CCV app preview service first; use artifacts only when the user explicitly
  asks for artifact/dashboard/report HTML. Do NOT use for generic web app previews
  outside CCV, production deployment, Cloudflare config, or Anthropic remote triggers.
argument-hint: "[preview [worktree-path] | artifact [name] | download <path> | schedule [list|create|delete|update]]"
---

# CCV — Claude Code Viewer Management

CCV (Claude Code Viewer) の preview 環境、アーティファクト登録、ファイルダウンロード、リモートエージェントのスケジュール管理を行う統合スキル。

## CCV Server

全ワークフロー共通。API を呼ぶ前に base URL を一度だけ定義する（ポートは `CCV_PORT` 環境変数で上書き可、デフォルト 3434）:

```bash
BASE_URL="http://localhost:${CCV_PORT:-3434}"
```

## Argument Routing

Route based on `$ARGUMENTS`:

1. **`preview ...`**, **`ccv-preview ...`**, **`プレビュー ...`**, **`ブラウザ確認 ...`**, **visual/UX QA for CCV**: → Read `references/preview.md` and follow the CCV App Preview workflow
2. **`schedule ...`**: → Read `references/schedule.md` and follow the Schedule workflow
3. **`download ...`** or **`dl ...`**: → Read `references/download.md` and follow the File Download workflow
4. **`artifact ...`** or explicit dashboard/report/HTML artifact creation: → Artifact workflow (below)
5. **no argument** or **other**: → Artifact workflow (below)

## Preview First Rule

- 「preview」「プレビュー」だけなら、まず CCV app preview service (`ccv-preview`) と解釈する
- HTML artifact preview と解釈するのは、ユーザーが `artifact`、`dashboard`、`report`、`HTML`、`アーティファクト登録` を明示した場合だけ
- CCV 以外の一般的な Web アプリ preview には使わない

---

# Artifact Workflow

CCV ローカル API を使って HTML アーティファクトを作成・登録する。

## Step 1: Identify the project

```bash
curl -s "${BASE_URL}/api/projects" | jq .
```

- `meta.projectPath` で現在のプロジェクトディレクトリと照合し、対象の `id` を特定する
- 現在の作業ディレクトリ (`pwd`) と一致するプロジェクトを自動選択する
- 一致しない場合はユーザーに確認する

## Step 2: Generate HTML content

ユーザーの要求に応じて HTML を生成する。典型的な用途:

- **定性評価ダッシュボード**: データの可視化、比較表
- **レポート**: 分析結果のまとめ
- **HTML モックアップ**: UI の静的確認用 HTML

HTML の要件:
- 単一ファイルで完結する（外部リソースへの依存なし）
- インラインCSS/JSを使用する
- `<html>`, `<head>`, `<body>` タグを含む完全なHTML文書にする
- 日本語コンテンツの場合は `<meta charset="utf-8">` を含める

## Step 3: Register the artifact

リクエストボディ:
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

HTML が大きい場合は必ず一時ファイル経由で送信する。JSON の構築には `jq` を使い、エスケープ漏れを防ぐ。一時ファイル名は `$$-$RANDOM` で衝突を避ける:

```bash
CCV_JSON="/tmp/ccv-artifact-$$-$RANDOM.json"
jq -n --arg name "$NAME" --arg fileName "$FILENAME" --arg html "$(cat /tmp/artifact.html)" \
  '{name: $name, fileName: $fileName, html: $html}' > "$CCV_JSON"
curl -s -X POST "${BASE_URL}/api/projects/{projectId}/artifacts" \
  -H 'Content-Type: application/json' -d @"$CCV_JSON"
rm -f "$CCV_JSON"
```

## Step 4: Confirm and report

登録成功後、以下を報告する:

1. アーティファクト ID（レスポンスの `id`）
2. HTML 表示 URL: `${BASE_URL}/api/projects/{projectId}/artifacts/{artifactId}/html`
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
