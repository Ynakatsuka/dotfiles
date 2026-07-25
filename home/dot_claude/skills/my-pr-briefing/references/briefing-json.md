# briefing.json 仕様

`pr_briefing.py render` の入力。解説だけを書き、コードは書かない。
コード抜粋は `excerpt` で hunk 番号を指定し、renderer が `pr.diff` から原文のまま転記する。

renderer は未知のキー、必須項目の欠落、diff に存在しないパス、範囲外の hunk 番号をすべてエラーにする。
エラーが出た場合は JSON を直す。HTML を手で作らない。

## 全体構造

```json
{
  "pr": 8,
  "purpose": { "stated": "", "observed": "", "gaps": [] },
  "flows": [],
  "files": [],
  "contracts": [],
  "priorities": [],
  "limits": []
}
```

| キー | 必須 | 内容 |
|---|---|---|
| `pr` | 必須 | PR 番号。`pr.json` の `number` と一致しないとエラー |
| `purpose` | 必須 | `stated`（PR 本文の主張）と `observed`（差分から確認できる内容）は必須。`gaps` は本文と実装の差異・不明点の配列 |
| `flows` | 任意 | 処理の流れ。不要なら空配列 |
| `files` | 必須 | `files.json` の全パスを過不足なく 1 回ずつ含める |
| `contracts` | 任意 | 公開契約の変更 |
| `priorities` | 任意 | 優先確認箇所 |
| `limits` | 任意 | 取得できなかった情報 |

## files

`category` で必要なキーが変わる。

### `source` / `config` / `doc`

```json
{
  "path": "src/server/auth.ts",
  "category": "source",
  "attention": "high",
  "role": "この PR 内でのファイルの役割",
  "change": "変更前 → 変更後を実際の識別子で",
  "excerpt": [2, 3],
  "impact": "呼び出し元・データ・外部契約・失敗時の挙動",
  "review_points": ["人がコードで確認すべき条件や境界"]
}
```

- `attention`: `high`（要注目、HTML で展開表示）、`medium`（確認）、`low`（参考）
- `role` / `change` / `impact`: 必須。空文字は不可
- `excerpt`: 表示する hunk の番号（1 始まり）。`files.json` の `hunks[].index` に対応する。判断に必要な hunk だけを選ぶ。抜粋不要なら `[]`
- `review_points`: 任意だが、`high` では必ず書く

### `test`

```json
{ "path": "tests/auth.test.ts", "category": "test" }
```

`path` と `category` 以外のキーはエラーになる。テストの内容説明・評価は書かない。

### `generated` / `binary`

```json
{ "path": "pnpm-lock.yaml", "category": "generated", "note": "生成元: package.json の依存更新" }
```

`note` は任意。生成元や差し替えの有無など、内容の推測にならない範囲で書く。

## flows

Mermaid は使わない（HTML を単一ファイルで完結させるため）。renderer が SVG を組み立てる `flow` と `sequence`、および `steps` と `table` を使う。
label と node は差分で確認できる識別子と条件に限定する。見栄えのための架空の処理を加えない。

| kind | 向いている対象 |
|---|---|
| `flow` | 分岐・合流・戻りのある処理。早期 return、エラー経路、再試行 |
| `sequence` | 複数の主体をまたぐ request/response、外部 I/O の順序 |
| `steps` | 分岐のない一直線の処理 |
| `table` | API、config、schema、権限の変更前後 |

### `flow`

```json
{
  "title": "リクエスト処理",
  "kind": "flow",
  "nodes": [
    { "id": "handle", "label": "router.ts:handle" },
    { "id": "verify", "label": "auth.ts:verify" },
    { "id": "deny", "label": "401 を返す" },
    { "id": "run", "label": "handler 実行" }
  ],
  "edges": [
    { "from": "handle", "to": "verify" },
    { "from": "verify", "to": "deny", "label": "期限切れ" },
    { "from": "verify", "to": "run", "label": "検証 OK" },
    { "from": "deny", "to": "handle", "label": "再試行" }
  ]
}
```

- `nodes[].id` は一意にする。`edges` の `from` / `to` は宣言済み id だけを指す
- 段は入力から出力へ自動で決まる。同じ段のノードは宣言順に左から並ぶ
- 逆向きの辺（再試行、ループ）は左に膨らむ曲線、段を飛ばす辺は右に膨らむ曲線になる
- 全ノードに入力辺があると開始点が決まらずエラーになる。起点となるノードを必ず 1 つ以上作る

### `sequence`

```json
{
  "title": "トークン検証",
  "kind": "sequence",
  "actors": [
    { "id": "api", "label": "api server" },
    { "id": "cache", "label": "redis" }
  ],
  "messages": [
    { "from": "api", "to": "cache", "label": "GET session" },
    { "from": "cache", "to": "api", "label": "hit/miss", "kind": "return" },
    { "from": "api", "to": "api", "label": "期限を再計算" }
  ]
}
```

- `messages` は上から順に描かれる。`kind` は `call`（既定、実線）か `return`（破線）
- `from` と `to` が同じ場合は自己呼び出しのループとして描かれる
- 主体が 1 つだけの処理は `sequence` にせず `flow` か `steps` を使う

### `steps` と `table`

```json
{
  "title": "リクエスト処理",
  "kind": "steps",
  "steps": [
    { "label": "router.ts:handle", "detail": "セッション検証" },
    { "label": "auth.ts:verify", "detail": "失敗時は 401" }
  ]
}
```

```json
{
  "title": "設定キーの変更",
  "kind": "table",
  "columns": ["キー", "変更前", "変更後"],
  "rows": [["timeout", "30", "10"]]
}
```

`rows` の各行は `columns` と同じ要素数にする。

## contracts

```json
{ "kind": "CLI", "name": "--format", "before": "なし", "after": "json|text", "note": "既定は text" }
```

`kind` / `name` / `before` / `after` は必須、`note` は任意。API、config、schema、型、環境変数、永続化形式も同じ形で書く。

## priorities

```json
{ "path": "src/server/auth.ts", "target": "src/server/auth.ts:verify", "reason": "期限切れトークンの分岐" }
```

`path` は diff に存在するパス。HTML では該当ファイルのカードへのリンクになる。`target` は任意で、既定は `path`。
