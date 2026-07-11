---
name: my-pr-briefing
description: >-
  Explain an existing GitHub pull request in the CCV chat as a code-oriented
  walkthrough for human review. Covers the PR intent, every changed file,
  behavioral and contract changes, faithful code excerpts, flows, and review
  attention points while omitting test-detail explanations. Use when the user
  asks to understand, inspect, walk through, or visually review a PR created in
  CCV. Do NOT use for creating or updating PRs, posting review comments, fixing
  findings, running tests, or performing a formal findings-only code review.
argument-hint: "[PR number or URL]"
---

# PR Briefing

既存 PR を、GitHub の Files changed をコードに沿って読む感覚に近い形で説明する。レビューを代行せず、変更の全体像と確認すべき箇所を CCV チャット内に提示する。

## 制約

- 読み取り専用にする。checkout、ファイル編集、commit、push、PR 更新、review 投稿を行わない。
- テストを実行しない。テストコード、fixture、snapshot、テスト結果、coverage の内容を説明しない。
- HTML artifact を作らない。Markdown、コードブロック、表、Mermaid をチャットへ直接出力する。
- PR 本文と実装を区別する。本文の主張を実装で確認できない場合は、推測で補完しない。
- 差分を取得できない場合は停止する。ローカル差分や別 PR に暗黙に切り替えない。

## 1. 対象 PR の特定

次の優先順で対象を決める。

1. `$ARGUMENTS` の PR 番号または URL
2. 会話内でユーザーが明示した PR
3. 現在のブランチに紐づく PR
4. 現在のリポジトリで、会話の文脈と一意に一致する open PR

現在のブランチに紐づく PR は `gh pr view` で確認する。候補検索が必要な場合は、まず一覧だけを取得する。

```bash
gh pr list --state open --author @me --limit 20 \
  --json number,title,url,headRefName,baseRefName,isDraft,updatedAt
```

文脈に一致する候補が複数ある場合は、CCV の `ask_user_question` で選択を求める。更新日時だけで選ばない。PR が一意に定まらない場合は停止する。

## 2. PR 情報と差分の取得

対象を `PR` に保持し、PR 本文、変更ファイル、commit、差分を取得する。

```bash
gh pr view "$PR" --json \
  number,title,body,url,state,isDraft,baseRefName,headRefName,author,commits,files,additions,deletions
gh pr diff "$PR" --patch
```

以下を確認する。

- PR の目的: title/body に明記された目的
- 実装上の目的: 差分から直接確認できる振る舞い
- 変更範囲: 全 changed files と各 additions/deletions
- 変更のつながり: caller → callee、入力 → 変換 → 出力、状態遷移
- 公開契約: API、CLI、config、schema、型、環境変数、永続化形式
- 注意領域: 認証、認可、秘密情報、削除、上書き、外部送信、課金、migration、互換性、依存関係

差分が大きい場合も、全 changed files の存在を把握してから説明を分割する。途中までを完全な説明として扱わない。

## 3. ファイル分類

全 changed files を次に分類する。

| 分類 | 扱い |
|---|---|
| 実装・設定・文書 | ファイル単位で説明する |
| テスト、fixture、snapshot | パスと件数だけ示し、内容は説明しない |
| lockfile・生成物 | パスと生成元、意味のある変更だけを示す。大量の機械的差分は展開しない |
| binary | パス、種類、差し替えの有無を示す。内容を推測しない |

テスト関連か不明なファイルを、名前だけで除外しない。役割を差分から確認する。

## 4. コードに近い説明

各 non-test file について、実際の diff hunk と周辺 identifier を読み、次の順で記述する。

1. **役割**: この PR 内でファイルが担う役割
2. **変更前 → 変更後**: 実際の関数名、型名、設定キー、条件を使った短い説明
3. **コード抜粋**: 判断に必要な短い diff または変更後コード
4. **影響**: 呼び出し元、データ、外部契約、失敗時の挙動
5. **レビュー注目点**: 人がコードで確認すべき条件や境界

コード抜粋は原則として実際のコードを使う。長い定型部分は `...` で省略する。再構成したコードを実コードのように見せない。疑似コードが必要な場合はコードブロックを `text` にし、直前に「疑似コード」と明記する。

次の情報を省略しない。

- 条件分岐と early return
- 例外・エラーの伝播
- default 値と fallback
- データの追加、削除、上書き
- permission、認証、外部 I/O の境界
- API/schema/config/CLI の変更前後

## 5. 図と表の選択

図は実装理解を短くできる場合だけ使う。

- 3 段階以上の呼び出しやデータ処理: Mermaid `flowchart`
- 複数主体の request/response: Mermaid `sequenceDiagram`
- 状態と遷移条件の変更: Mermaid `stateDiagram-v2`
- API、config、schema、権限の差分: 変更前後の比較表

図中の node と edge は差分で確認できる identifier と条件に限定する。見栄えのための架空の処理を加えない。

## 6. 出力形式

以下の順で出力する。該当しない節は省略する。

````markdown
# PR #<number>: <title>

## 目的
- PR本文の説明: ...
- 実装から確認できる内容: ...
- 差異・不明点: ...

## 変更マップ
| ファイル | 役割 | 変更の要点 | 注目度 |
|---|---|---|---|

テスト関連: <N> files（内容説明は省略）

## 処理の流れ
<必要な場合だけ Mermaid または比較表>

## ファイル別 walkthrough
### `path/to/file`
**役割**: ...
**変更前 → 変更後**: ...
```diff
- old behavior
+ new behavior
```
**影響**: ...
**レビュー注目点**: ...

## 公開契約の変更
<API/config/schema/CLI などの比較表>

## レビュー時に優先して見る箇所
1. `file:identifier` — 確認する条件と理由

## 取得上の制約
- 読めなかった diff、binary、truncation など
````

## 完了条件

- 全 changed files が変更マップに現れる。
- 全 non-test source/config/document file に説明がある。
- PR 本文と実装の差異が明示される。
- 危険な操作や公開契約の変更が、コード位置とともに分かる。
- テスト関連は存在だけが分かり、内容説明や評価がない。
- 取得できなかった情報を明記し、完全に読めたように装わない。
