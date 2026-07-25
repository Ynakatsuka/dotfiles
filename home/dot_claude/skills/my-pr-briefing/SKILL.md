---
name: my-pr-briefing
description: >-
  Explain an existing GitHub pull request as a self-contained HTML briefing
  registered in CCV, written as a code-oriented walkthrough for human review.
  Covers the PR intent, every changed file, behavioral and contract changes,
  verbatim code excerpts, flows, and review attention points while omitting
  test-detail explanations. Use when the user asks to understand, inspect, walk
  through, or visually review a PR created in CCV. Do NOT use for creating or
  updating PRs, posting review comments, fixing findings, running tests, or
  performing a formal findings-only code review.
argument-hint: "[PR number or URL]"
---

# PR Briefing

既存 PR を、GitHub の Files changed をコードに沿って読む感覚に近い HTML にして CCV に登録する。レビューを代行せず、変更の全体像と確認すべき箇所を提示する。

チャットには要点と表示先だけを短く出す。HTML は自分で書かず、解説を `briefing.json` に書いて renderer に渡す。コード抜粋は renderer が diff から原文のまま転記するため、コードを書き写さない。

## 制約

- 読み取り専用にする。checkout、ファイル編集、commit、push、PR 更新、review 投稿を行わない。
- テストを実行しない。テストコード、fixture、snapshot、テスト結果、coverage の内容を説明しない。
- HTML を手書きしない。`briefing.json` と bundled renderer だけで生成する。
- PR 本文と実装を区別する。本文の主張を実装で確認できない場合は、推測で補完しない。
- 差分を取得できない場合は停止する。ローカル差分や別 PR に暗黙に切り替えない。
- renderer や登録スクリプトが失敗した場合は停止して報告する。手書き HTML や別経路の出力へ切り替えない。

bundled scripts は chezmoi により `$HOME/.claude/skills/my-pr-briefing/` へ配置される。最初のスクリプト実行前に配置を検証する。

```bash
test -x "$HOME/.claude/skills/my-pr-briefing/scripts/fetch-pr-briefing.sh"
test -f "$HOME/.claude/skills/my-pr-briefing/scripts/pr_briefing.py"
```

以後、scripts は各 shell call から `$HOME/.claude/skills/my-pr-briefing/scripts/...` で直接参照する。前の shell call の変数が残ると仮定しない。

## 1. 対象 PR の特定

次の優先順で対象を決める。

1. `$ARGUMENTS` の PR 番号または URL
2. 会話内でユーザーが明示した PR
3. 現在のブランチに紐づく PR
4. 現在のリポジトリで、会話の文脈と一意に一致する open PR

現在のブランチに紐づく PR は引数なしで解決できる。候補検索が必要な場合は、まず一覧だけを取得する。

```bash
gh pr list --state open --author @me --limit 20 \
  --json number,title,url,headRefName,baseRefName,isDraft,updatedAt
```

文脈に一致する候補が複数ある場合は、CCV の `ask_user_question` で選択を求める。更新日時だけで選ばない。PR が一意に定まらない場合は停止する。

## 2. PR 情報と差分の取得

```bash
bash "$HOME/.claude/skills/my-pr-briefing/scripts/fetch-pr-briefing.sh" "$PR"
```

`.tmp/my-pr-briefing/pr-<number>/` に `pr.json`、`pr.diff`、`files.json` を作り、変更ファイル一覧を出力する。`pr.diff` は GitHub の Files changed と同じ combined diff。

以下を確認する。

- PR の目的: title/body に明記された目的
- 実装上の目的: 差分から直接確認できる振る舞い
- 変更範囲: 全 changed files と各 additions/deletions
- 変更のつながり: caller → callee、入力 → 変換 → 出力、状態遷移
- 公開契約: API、CLI、config、schema、型、環境変数、永続化形式
- 注意領域: 認証、認可、秘密情報、削除、上書き、外部送信、課金、migration、互換性、依存関係

差分が大きい場合は `pr.diff` を範囲指定で読む。全 changed files の存在を `files.json` で把握してから分割して読む。途中までを完全な説明として扱わない。

## 3. ファイル分類

`files.json` の全ファイルを次に分類し、`briefing.json` の `category` に設定する。

| category | 扱い |
|---|---|
| `source` / `config` / `doc` | ファイル単位で説明する |
| `test` | パスと件数だけ示し、内容は説明しない |
| `generated` | パスと生成元、意味のある変更だけを示す。大量の機械的差分は展開しない |
| `binary` | パス、種類、差し替えの有無を示す。内容を推測しない |

テスト関連か不明なファイルを、名前だけで除外しない。役割を差分から確認する。

## 4. briefing.json の作成

`references/briefing-json.md` を読み、`.tmp/my-pr-briefing/pr-<number>/briefing.json` を書く。

各 `source` / `config` / `doc` ファイルについて、実際の diff hunk と周辺 identifier を読み、次を埋める。

1. `role`: この PR 内でファイルが担う役割
2. `change`: 実際の関数名、型名、設定キー、条件を使った変更前 → 変更後
3. `excerpt`: 判断に必要な hunk 番号。renderer が原文のまま転記する
4. `impact`: 呼び出し元、データ、外部契約、失敗時の挙動
5. `review_points`: 人がコードで確認すべき条件や境界

次の情報を省略しない。

- 条件分岐と early return
- 例外・エラーの伝播
- default 値と fallback
- データの追加、削除、上書き
- permission、認証、外部 I/O の境界
- API/schema/config/CLI の変更前後

図は実装理解を短くできる場合だけ `flows` に入れる。renderer が SVG を描くため、Mermaid や外部ライブラリは使わない。

- 分岐、合流、再試行、エラー経路がある処理: `kind: "flow"`（有向グラフ）
- 複数主体の request/response や外部 I/O の順序: `kind: "sequence"`
- 分岐のない一直線の処理: `kind: "steps"`
- API、config、schema、権限の差分: `kind: "table"` または `contracts`

図中の node、actor、label は、差分で確認できる identifier と条件に限定する。見栄えのための架空の処理や、本文で足りる内容の図解を加えない。

## 5. HTML 生成

```bash
BRIEFING_DIR=".tmp/my-pr-briefing/pr-$PR"
python3 "$HOME/.claude/skills/my-pr-briefing/scripts/pr_briefing.py" render \
  --dir "$BRIEFING_DIR" \
  --briefing "$BRIEFING_DIR/briefing.json" \
  --out "$BRIEFING_DIR/briefing.html"
```

renderer は未知のキー、必須項目の欠落、diff にないパス、範囲外の hunk 番号、`files` の取りこぼしをエラーにする。エラーが出たら `briefing.json` を直して再実行する。renderer を迂回しない。

生成される HTML は単一ファイルで完結し、外部リソースと localStorage を使わない。CCV の表示欄は sandbox 化された iframe のため、この制約を外すと表示が壊れる。

## 6. CCV への登録

```bash
bash "$HOME/.claude/skills/my-pr-briefing/scripts/publish-pr-briefing.sh" \
  "$BRIEFING_DIR/briefing.html" "PR #$PR briefing" "pr-$PR-briefing.html"
```

同じ `fileName` の artifact が既にある場合はエラーになる。同じ PR を更新する意図が明確なときだけ `--replace` を付ける。

登録後、チャットには次だけを出す。

- PR 番号、タイトル、URL
- 変更規模（files、+/-）と要注目ファイル数
- HTML の表示 URL
- PR 本文と実装の差異、取得できなかった情報

walkthrough 本文をチャットに再掲しない。

## 完了条件

- 全 changed files が `briefing.json` に 1 回ずつ現れる（renderer が検証）。
- 全 `source` / `config` / `doc` file に `role` / `change` / `impact` がある。
- PR 本文と実装の差異が `purpose.gaps` に出る。
- 危険な操作や公開契約の変更が、コード位置とともに分かる。
- テスト関連は存在だけが分かり、内容説明や評価がない。
- 取得できなかった情報を `limits` に書き、完全に読めたように装わない。
- HTML が CCV に登録され、表示 URL を報告している。
