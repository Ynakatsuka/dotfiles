---
name: my-handoff
description: >-
  Hand off a task with only the context needed to continue in a fresh session.
  Use for "handoff", "引き継ぎ", "別セッションへ渡す", or "別マシンで続ける".
  The orca subcommand launches an independent Orca workspace or terminal tab;
  without it, produce a paste-ready prompt backed by a verified remote branch or PR.
  Do not launch sessions for capability questions or design requests.
---

# my-handoff

親は短い依頼文だけを作る。環境確認と起動はスクリプト、コードの調査は引き継ぎ先が担当する。

## サブコマンド

- `/my-handoff orca [引き継ぐ話題]`（Codexでは `$my-handoff orca ...`）: [Orca手順](references/orca.md)だけを読む。新規ワークスペースが既定。「同じワークスペースの別タブ」と指定された場合はタブを作る。
- `/my-handoff [追加事項]`: [別マシン向け手順](references/remote.md)だけを読む。従来どおり、共有済み branch / PR とコピー用プロンプトを返す。
- 自然文でOrcaへの切り出しを依頼された場合も `orca` として扱う。機能の質問や設計だけでは起動しない。

## 親が渡す情報

現在把握している次の情報を、重複せず短くまとめる。目安は日本語で400〜800字。重要な制約は文字数のために省かない。

- 依頼、完了条件、次の作業。
- 会話にしかない決定、その理由、ユーザーの制約と操作の許可範囲。
- 最初に見る関連ファイルと、必要な分岐元・未コミット変更への依存。
- 引き継ぐ担当範囲。元で続ける作業がある場合は、その境界。

会話履歴の再取得、全履歴を読む要約エージェント、差分全文・長いログの収集は行わない。コードから再確認できることは参照箇所を渡す。根拠のない完了報告や「前と同じ」は書かない。依頼自体を確定できない場合だけ不足情報を確認する。

## 自動で決めること

- 引き継ぎに必要なローカルブランチ・worktreeの作成と命名は依頼に含まれる。確認を挟まず、既存規約と話題から短い名前を選ぶ。規約がなければ `handoff-<topic>` とする。
- `orca` の新規ワークスペースはOrcaにブランチを作らせる。現在のブランチは切り替えない。既存の同名セッションを推測で再利用しない。
- commit、push、PR作成の許可は別に扱う。今回の依頼で許可済みなら聞き直さない。引き継ぎだけを理由に許可を追加しない。

## 担当の移動

話題の一部を切り出す場合、渡した範囲だけを元の担当から外し、残した作業を続ける。全体の引き継ぎなら起動・送信の確認後に終了する。通常は結果待ち・監視・自動統合をしない。ユーザーが結果の回収や複数作業の管理も依頼した場合は、通常の引き継ぎとは分けてOrcaの `orchestration` 手順を使う。

秘密情報や無関係な履歴を渡さない。引き継ぎ先にも作業先の `AGENTS.md` の確認を求め、依頼の許可範囲を広げない。
