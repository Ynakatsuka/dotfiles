# SARIF Output Format

scan 結果は **SARIF 2.1.0 互換のサブセット**として `"$SCAN_OUT_DIR/findings.sarif.json"` に保存する。これで Semgrep / Code Scanning / その他ツールに渡せる。

## 最低限の形

```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [{
    "tool": {
      "driver": {
        "name": "my-refactor",
        "informationUri": "https://github.com/Ynakatsuka/dotfiles",
        "rules": [
          { "id": "remove-duplication", "shortDescription": { "text": "Duplicated logic across call sites" } },
          { "id": "extract-function", "shortDescription": { "text": "Long or deeply nested function" } }
          /* ... 他 catalog の category をそのまま rule id に ... */
        ]
      }
    },
    "results": [
      {
        "ruleId": "remove-duplication",
        "level": "error",
        "message": { "text": "Two near-identical auth header builders. Diverging bug-fixes already happened once (commit abc123)." },
        "locations": [
          { "physicalLocation": {
              "artifactLocation": { "uri": "src/api/user.ts" },
              "region": { "startLine": 42, "endLine": 58 } } },
          { "physicalLocation": {
              "artifactLocation": { "uri": "src/api/admin.ts" },
              "region": { "startLine": 61, "endLine": 77 } } }
        ],
        "partialFingerprints": {
          "refactorFingerprint/v1": "<sha1(ruleId + \"|\" + path + \"|\" + normalized snippet, per location)>"
        },
        "properties": {
          "severity": "high",
          "effort_minutes": 30,
          "suggested_approach": "Extract to src/api/_auth.ts::buildAuthHeader, import from both sites.",
          "risks": ["Shared test coverage required before extraction."],
          "suggested_title": "Extract shared auth header builder (2 copies in src/api/)"
        }
      }
    ]
  }]
}
```

## マッピングの決まり

- `ruleId` = catalog category（ハイフン形式、`category/` プレフィクスなし）
- `level`: `critical`/`high` → `"error"`, `medium` → `"warning"`, `low` → `"note"`。`critical` と `high` は同じ `"error"` に潰れるため、順位付けには `properties.severity` を第 2 ソートキーとして併用する（Phase S-3 参照）
- `properties.severity`, `properties.effort_minutes`: my-refactor 固有の拡張プロパティ
- `properties.suggested_title`, `properties.suggested_approach`, `properties.risks`: issue 本文の生成に使う

## fingerprint 規則（決定的）

`partialFingerprints["refactorFingerprint/v1"]` は次の式で決定的に計算する:

```text
fingerprint = sha1(ruleId + "|" + path_1 + "|" + snippet_1 + "|" + path_2 + "|" + snippet_2 + ...)
```

- `path_i`: `locations[]` の並び順どおりの repo-relative path（`artifactLocation.uri`）
- `snippet_i`: その location の指摘対象行（flagged lines）を正規化したもの
  1. 各行の先頭・末尾の空白を除去する
  2. 行内の連続する空白を 1 つのスペースに潰す
  3. 各行を `"\n"` で join する
- 行番号は入力に**含めない**（行 shift 耐性のため）
- 変数名の `$var` 化などのリネーム正規化は**行わない**（実行ごとに結果が変わり非決定的になるため）

findings.sarif.json は scan ごとに**上書き**する（run history は Git で追う）。

## severity の基準

- `critical`: バグ温床、セキュリティ、データ不整合に直結
- `high`: 明確な重複・破綻した設計。放置で負債が急速に増える
- `medium`: 可読性・保守性の低下。機能追加のたびに痛い
- `low`: 軽微な整理。ただし Nice-to-have は **skip**

## effort_minutes の基準

実装 + テスト修正 + レビュー反映までのざっくり見積（`< 30`, `30-120`, `120-480`, `> 480` の刻み）。480 超は issue を分割するようユーザーに相談する。
