# Refactoring Catalog — 検出カテゴリと判断基準

Martin Fowler の Refactoring Catalog（https://refactoring.com/catalog/）と code smells を実務向けに圧縮したもの。Phase 2 のスキャンで **必ずこのカタログを参照し、該当 category ラベルを決定する**。

該当する category がない場合のみ `category/other` を使うこと。

---

## Category 一覧（ラベルと対応する smell）

### `category/remove-duplication`

- 同一ロジックが複数箇所にコピペ。片方の修正が他方に伝播しない
- 定数の重複定義（別ファイルに同じ enum/magic number）
- 似た名前の関数が微妙に違う実装を持つ

**見分け方:** grep で同じ行が複数出るか、AST 的に似たブロックがあるか

### `category/extract-function`

- 1 関数が 50 行以上、かつコメントで区切られている
- ネストが 4 段以上（`if` の中の `for` の中の `if`…）
- 1 関数に 3 つ以上の異なる責務がある

**関連する Fowler の技法:** Extract Function, Extract Variable, Replace Temp with Query

### `category/rename`

- 名前が実装と乖離（`calculateTotal` が合計を返さない、`getUser` が副作用を持つ）
- 古い用語が残っている（legacy 名のまま使われ続けている）
- 略語が独自で意味が取れない（`utl`, `svc`, `hdl` など）

**関連:** Rename Variable, Rename Function, Rename Field

### `category/move`

- モジュール境界をまたいだ不自然な依存
- 呼び出し元からはるか離れたファイルに helper が置かれている
- 循環 import を生むクラスの配置

**関連:** Move Function, Move Field, Move Statements to Callers

### `category/simplify-conditional`

- 深いネストの `if`
- 否定の否定、ド・モルガン律で簡素化可能
- 同じ分岐条件が複数箇所
- マジックナンバーや string literal の分岐

**関連:** Decompose Conditional, Replace Nested Conditional with Guard Clauses, Replace Conditional with Polymorphism

### `category/dead-code`

- 使われていない関数・変数・import
- 到達不能な分岐（常に true/false になる条件）
- feature flag 除去後に残った分岐
- TODO コメントだけ残って実装が進まないもの

**関連:** Remove Dead Code, Remove Flag Argument

### `category/encapsulate`

- データ構造が外部にそのまま露出している（mutable な配列を直接返す等）
- クラスの内部状態を外から書き換えられる
- 複数のフィールドが常にセットで使われる（Data Clump）

**関連:** Encapsulate Variable, Encapsulate Collection, Introduce Parameter Object

### `category/replace-primitive`

- 意味を持つ値が string/int で裸のまま API に露出（`userId: string` が単なる文字列）
- 単位がコメントでしか示されていない（`timeout: number // ms`）
- 列挙値が string literal の直書きで散らばっている

**関連:** Replace Primitive with Object, Replace Magic Literal

### `category/other`

上記のどれにも該当しないリファクタ。可能な限り避け、上記カテゴリのどれに最も近いか再検討すること。

---

## Severity 判定の補助

| 条件 | 推奨 severity |
|---|---|
| セキュリティ・データ不整合・race condition の温床 | critical |
| 既にバグの発生履歴がある箇所（`git log --grep=fix` で検出） | critical または high |
| 重複が 3 箇所以上、または diverging history がある | high |
| 長い関数・深いネストで **かつ** 頻繁に変更される（hot file） | high |
| 長い関数・深いネストだが変更頻度が低い | medium |
| 命名不整合 | medium |
| 単純な dead code（未使用 import 等） | low |
| 完全に localized・1箇所だけの整理 | low |

**hot file の判定:** `git log --format=format: --name-only --since=3.months | sort | uniq -c | sort -rn | head` で頻出ファイルを把握する。

---

## Effort 見積の補助

| 作業規模 | 見積 |
|---|---|
| 1ファイル内、テスト変更なし | < 30 min |
| 1-2ファイル、テスト少し修正 | 30-120 min |
| 複数モジュール、公開 API に波及、テスト大幅修正 | 120-480 min |
| アーキテクチャ変更、複数パッケージ、migration 要 | > 480 min（issue を分割することを推奨） |

**480 min を超える候補は 1 issue にしない。** サブタスクに分解し、親 issue + 子 issue の形にするかユーザーに確認する。

---

## 除外すべきもの（false positive を避ける）

- **スタイル/フォーマット**: linter/formatter で自動解決すべきもの
- **投機的リファクタ**: 「将来拡張したくなったら」系。具体的な痛みがないなら skip
- **テストコードの DRY 化**: テストは重複しても読みやすさ優先、安易に共通化しない
- **単発の命名の好み**: 既存コードベースと整合していれば変えない
- **generated code**: `*.pb.go`, `*.generated.ts` など生成物は対象外
- **vendored/third-party**: `node_modules/`, `vendor/`, `third_party/` は除外
