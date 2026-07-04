# File Download Workflow

CCV ローカル API を使って、登録済みプロジェクト内の特定ファイルをブラウザまたは `curl` でダウンロードできる URL を生成する。

> 前提: SKILL.md の `## CCV Server` の通り、先に `BASE_URL="http://localhost:${CCV_PORT:-3434}"` を定義しておく。

## Step 1: Identify the project

```bash
curl -s "${BASE_URL}/api/projects" | jq .
```

- `meta.projectPath` で現在のプロジェクトディレクトリと照合し、対象の `id` を特定する
- 現在の作業ディレクトリ (`pwd`) と一致するプロジェクトを自動選択する
- 一致しない場合はユーザーに確認する

## Step 2: Determine the file path

- `path` はプロジェクトルートからの相対パスを指定する
- 絶対パスは指定しない
- `../` でプロジェクト外へ出るパスは拒否される
- `.env`, `*.pem`, `*.key`, credentials/secrets 系ファイルは拒否される

## Step 3: Build the download URL

ブラウザで開く URL:

```text
${BASE_URL}/api/projects/{projectId}/files/download?path={urlEncodedRelativePath}
```

URL エンコードは `jq` で行う:

```bash
REL_PATH="reports/result.csv"
ENCODED_PATH=$(jq -rn --arg v "$REL_PATH" '$v|@uri')
printf '%s/api/projects/%s/files/download?path=%s\n' "$BASE_URL" "$PROJECT_ID" "$ENCODED_PATH"
```

ブラウザでこの URL を開くと、サーバーは `Content-Disposition: attachment` を返し、ファイルダウンロードとして扱われる。

## Step 4: Download with curl

```bash
REL_PATH="reports/result.csv"
ENCODED_PATH=$(jq -rn --arg v "$REL_PATH" '$v|@uri')
curl -fL -OJ "${BASE_URL}/api/projects/${PROJECT_ID}/files/download?path=${ENCODED_PATH}"
```

- `-O`: レスポンスのファイル名で保存
- `-J`: `Content-Disposition` の `filename` を使う
- `-f`: 4xx/5xx を失敗として扱う

## File Download API Reference

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/projects/:projectId/files/download?path=:relativePath` | プロジェクト内ファイルを attachment として返す |

## File Download Error Handling

- CCV サーバーが起動していない場合: `curl: (7) Failed to connect` → ユーザーに CCV サーバーの起動を案内する
- プロジェクトが見つからない場合: `/api/projects` の一覧を表示してユーザーに選択を求める
- `400 Invalid path`: 絶対パスまたはプロジェクト外参照
- `400 not_file`: 対象が通常ファイルではない
- `403 sensitive_file`: sensitive file パターンに該当
- `404 not_found`: ファイルが存在しない
