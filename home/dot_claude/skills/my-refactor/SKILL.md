---
name: my-refactor
description: >-
  Scan a codebase for refactoring opportunities, write a SARIF-compatible report, and register
  each finding as a GitHub issue labelled by severity, effort, and Fowler category. After issue
  creation, users are directed to `/my-sdd <feature-name>` to plan and implement each refactor
  (one issue = one spec = one PR).
  Use when the user asks to "リファクタリング候補洗い出し", "技術的負債リスト化", "refactor scan",
  "refactoring issues", or requests surveying a repo for refactor work.
  Do NOT use for applying refactors (delegate to `/my-sdd`), code review of a specific PR
  (use `my-pr review`), or for fixing a specific bug.
argument-hint: "[scan] [path] [--dry-run] [--max=N]"
---

# Refactor — 検出と issue 登録

コードベースをスキャンしてリファクタリング候補を検出し、**1候補=1 GitHub issue** として登録する。登録済みの issue は `/my-sdd` で spec 駆動に消化する（1 issue = 1 spec = 1 PR）。

## サブコマンド

先頭トークンで分岐する。現時点では `scan` のみ。

| 先頭トークン | 動作 |
|---|---|
| 省略 or `scan` | scan フロー（Phase S-1 〜 S-5） |
| その他の文字列 | scan の引数（パス）として扱い、scan を実行 |

issue を消化する apply 相当は **`/my-sdd` に委譲**する。検出〜起票はこのスキル、計画〜実装は SDD スキル、という責務分離。

---

# SCAN: 検出と issue 登録

## scan の引数

先頭が `scan` のときは 1 トークン消費し、残りを以下で解釈する。先頭が `scan` でない場合は `$ARGUMENTS` 全体を以下で解釈する:

| 引数 | 動作 |
|---|---|
| （省略） | リポジトリ全体をスキャン、検出したら即 issue 作成 |
| パス（例 `src/api/`） | 指定パス配下のみスキャン |
| `--dry-run` | issue を作成せずレポートのみ出力（プレビュー） |
| `--max=N` | 1回のスキャンで作成する issue 数の上限（既定 10） |

デフォルトは **即作成**。プレビューしたいときは `--dry-run` を明示する。

## Phase S-1: 前提条件の確認

### S-1-1: リポジトリと gh 認証を確認

```bash
git rev-parse --show-toplevel >/dev/null || { echo "Not a git repo"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "gh not authenticated"; exit 1; }
REPO_ROOT=$(git rev-parse --show-toplevel)
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
SCAN_OUT_DIR="$REPO_ROOT/.tmp/refactor"
mkdir -p "$SCAN_OUT_DIR"
```

### S-1-2: スコープを決める

- 引数にパスが渡されている → そのパス配下を対象にする（存在しない場合はエラー）
- 引数にパスがない → `$REPO_ROOT` 全体を対象にする

巨大リポの場合は `git ls-files | wc -l` でファイル数を把握し、10,000 を超えるときはユーザーに「対象を絞ることを推奨」と警告する。

### S-1-3: ラベルの準備

以下 3 系統のラベルを使う。未作成なら `gh label create` で作成する（既存ならスキップ）。

| ラベル | 値の例 |
|---|---|
| 固定 | `refactor` |
| severity | `severity/critical`, `severity/high`, `severity/medium`, `severity/low` |
| category | `category/extract-function`, `category/remove-duplication`, `category/rename`, `category/move`, `category/simplify-conditional`, `category/dead-code`, `category/encapsulate`, `category/replace-primitive`, `category/other` |

category は `references/catalog.md` の一覧から選ぶ。該当なしのときだけ `category/other`。

### S-1-4: 既存 issue を取得（重複回避）

```bash
gh issue list --label refactor --state all --limit 500 \
  --json number,title,body,labels,state \
  > "$SCAN_OUT_DIR/existing-issues.json"
```

`state all` にするのは、closed 済み issue の fingerprint と照合して「一度 close した指摘を再提案しない」ためでもある。

## Phase S-2: スキャン

読み取り専用で context を汚さないため、**Agent ツールで subagent_type=Explore を起動する**ことを推奨する。プロンプトには以下を含める: 対象ディレクトリ、`references/catalog.md` を読むよう指示、下記の findings フォーマット。

### 検出の判断基準

`references/catalog.md` を読み、以下に該当するものを列挙する:

- 重複（同一ロジックの複数実装）
- 長い関数（行数やネストが深い）
- 巨大クラス・巨大ファイル（責務が混在）
- 命名の不整合（古い名前、誤解を招く名前）
- 不要コード（未使用の関数・import・変数、到達不能分岐）
- 複雑な条件式（深いネスト、否定の否定、マジックナンバー）
- 配置ずれ（使われる場所から遠いモジュールにある）
- プリミティブの乱用（意味を持たない string/int が API に露出）
- 隠れたカップリング（副作用、グローバル状態）

**除外**: 投機的リファクタ（「将来必要かも」系）、スタイル・フォーマットだけの指摘、LLM 生成コードの重複を無自覚に提案する類のもの。

### SARIF 互換の出力

scan 結果は **SARIF 2.1.0 互換のサブセット**として `"$SCAN_OUT_DIR/findings.sarif.json"` に保存する。これで Semgrep / Code Scanning / その他ツールに渡せる。

ランタイムが出力する最低限の形:

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
          "refactorFingerprint/v1": "<sha1 of category + normalized_code_of_each_location>"
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

マッピングの決まり:

- `ruleId` = catalog category（ハイフン形式、`category/` プレフィクスなし）
- `level`: `critical`/`high` → `"error"`, `medium` → `"warning"`, `low` → `"note"`
- `partialFingerprints["refactorFingerprint/v1"]`: `sha1(ruleId + "\n" + 各 location の正規化コード)`。空白の潰しと変数名の `$var` 化など軽い正規化を行う。行番号は含めない（shift 耐性のため）
- `properties.severity`, `properties.effort_minutes`: my-refactor 固有の拡張プロパティ
- `properties.suggested_title`, `properties.suggested_approach`, `properties.risks`: issue 本文の生成に使う

findings.sarif.json は scan ごとに**上書き**する（run history は Git で追う）。

**severity の基準**:
- `critical`: バグ温床、セキュリティ、データ不整合に直結
- `high`: 明確な重複・破綻した設計。放置で負債が急速に増える
- `medium`: 可読性・保守性の低下。機能追加のたびに痛い
- `low`: 軽微な整理。ただし Nice-to-have は **skip**

**effort_minutes の基準**: 実装 + テスト修正 + レビュー反映までのざっくり見積（`< 30`, `30-120`, `120-480`, `> 480` の刻み）。480 超は issue を分割するようユーザーに相談する。

## Phase S-3: 重複排除と絞り込み

1. `findings.sarif.json` の各 `results[]` について、`partialFingerprints["refactorFingerprint/v1"]` を取り出す
2. `existing-issues.json` の各 issue 本文から `RefactorFingerprint:` 行（Phase S-5 で埋め込む）を抽出
3. fingerprint が一致する既存 issue（open/closed 問わず）があれば、新規スキャンから除外
4. fingerprint が見つからない既存 issue については **location + ruleId の一致**でフォールバック判定
5. `level` 優先（error → warning → note）でソート → `--max=N` で上位のみ残す（既定 10 件）
6. `level=error` かつ `properties.severity=critical` は `--max` を超えても残す

## Phase S-4: レポート出力

issue を作る前に、**必ず標準出力に人間可読なサマリを出す**。`--dry-run` のときはここで終了。

```markdown
# Refactor Scan Report

**Scope:** <path or entire repo>
**SARIF output:** `.tmp/refactor/findings.sarif.json` (N results)
**Detected:** N 件 (critical: X, high: Y, medium: Z, low: W)
**Skipped as duplicates:** M 件（fingerprint 一致 a / location 一致 b）

## 作成予定の issue

### 🔴 critical
1. [remove-duplication] タイトル — locations, effort

### 🟠 high
...
```

`--dry-run` がない場合は Phase S-5 に進む（ユーザー対話は挟まない）。

## Phase S-5: issue 作成

各 SARIF `result` について `gh issue create` を 1 回ずつ実行する。

### issue 本文テンプレート

```markdown
## 概要

<message.text>

## 対象

- `src/api/user.ts:42-58`
- `src/api/admin.ts:61-77`

## 提案するアプローチ

<properties.suggested_approach>

## 想定リスク

- <properties.risks>

## メタ

- Category: remove-duplication
- Severity: high
- Effort estimate: ~30 min

<!-- machine-readable footer — DO NOT EDIT -->
RefactorFingerprint: <sha1>
RefactorRuleId: remove-duplication
RefactorSource: my-refactor/scan@YYYY-MM-DD

---

*Generated by `/my-refactor scan`. SARIF: `.tmp/refactor/findings.sarif.json` result index N.*
```

`RefactorFingerprint:` を必ず入れる。次回 scan がこの行を読み、重複起票を避ける。

### 作成コマンド

```bash
gh issue create \
  --title "<properties.suggested_title>" \
  --body-file "$SCAN_OUT_DIR/issue-body-<idx>.md" \
  --label "refactor" \
  --label "severity/<properties.severity>" \
  --label "category/<ruleId>"
```

- `--assignee` は付けない（誰が取るか未定。ユーザー希望があれば `@me`）
- rate limit 回避のため、作成ごとに `sleep 1` を挟む
- 作成失敗で以降を中断し、作成済み番号をユーザーに報告する

### 作成後のサマリ（`/my-sdd` への引き継ぎ）

issue を作ったら必ず次の形式で出力し、**ユーザーを `/my-sdd` に誘導する**。実装はこのスキルではなく SDD スキルに任せる。

```markdown
# Created N refactor issues

- #123 🔴 [remove-duplication] タイトル — `refactor/issue-123-extract-auth-header`
- #124 🟠 [extract-function] タイトル — `refactor/issue-124-...`

SARIF: `.tmp/refactor/findings.sarif.json`

## 次のステップ: `/my-sdd` で消化

各 issue を計画→実装するには、issue ごとに次のコマンドを実行してください:

    /my-sdd refactor-issue-123-extract-auth-header

もしくは自然言語でも OK:

    /my-sdd Issue #123 のリファクタを設計して実装して

SDD は requirements.md / design.md / tasks.md をスペックディレクトリに書き出し、テストファーストで実装します。
Issue 本文の「提案するアプローチ」「想定リスク」「RefactorFingerprint」をそのまま参照材料にすると効率的です。
```

各 issue について、**ケバブケースの feature-name を 1 つ提案する**こと（`refactor-issue-<num>-<short-slug>` 形式）。ユーザーがそのままコピペできる。

---

## 注意事項

### SARIF 出力

- scan の出力は `SCAN_OUT_DIR/findings.sarif.json`。SARIF 2.1.0 サブセットとして他ツールに渡せる
- fingerprint は行番号を含めない。空白正規化・変数名抽象化を行い、リネーム耐性を持たせる

### issue と fingerprint

- scan が作る issue には `RefactorFingerprint:` / `RefactorRuleId:` 行が埋め込まれる。**この 2 行は手編集しない**
- 次回 scan はこの行を読み、同じ所見の重複起票を避ける
- 手動で issue を書いた場合は fingerprint 判定対象外（location + ruleId フォールバックのみ）

### その他

- すべての issue タイトル・本文は日本語。ラベル・ファイル名は英語
- `references/catalog.md` を **必ず読んで** category 分類の根拠にする。category/other の濫用を避ける
- 480 分を超える effort の issue を提示する前に、ユーザーへ分割を提案する
- このスキルは issue 起票までで止まる。実装フローは `/my-sdd` に委譲する（重複させない）
