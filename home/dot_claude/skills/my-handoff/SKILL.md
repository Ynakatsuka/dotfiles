---
name: my-handoff
description: >-
  Creates a self-contained prompt for continuing repository work on another
  machine in a fresh session, using an exact remote branch or open GitHub PR as
  the shared state. When local work is not remotely shareable, it may stage,
  commit, push, or create or update a GitHub PR only after the user approves the
  exact mutations. Its final answer provides one paste-ready prompt without
  asking the user to run setup commands. Use when the user asks for "handoff",
  "引き継ぎ", "別マシンで続ける", "別セッションへ渡す", or sharing the current
  task with a branch or PR. Do NOT use for same-session summaries,
  general-purpose Git publishing or PR work, or handoffs that rely on local
  files or session history.
argument-hint: "[追加の引き継ぎ事項]"
---

# my-handoff

別マシンの新しいセッションで、前のセッション履歴やローカルファイルに依存せず作業を再開できるプロンプトを作る。

共有可能性の調査は読み取り専用で進める。stage、commit、push、branch 作成、PR 作成・更新などの変更が必要な場合は、変更内容を具体化し、現在の会話でユーザーの明示的な承認を得てから実行する。ローカルの handoff ファイルは作成しない。

## 手順

1. 現在の会話から、依頼、完了済み作業、残作業、判断事項、制約、検証結果を整理する。`$ARGUMENTS` が空でなければ追加情報として使う。リポジトリの証拠と矛盾する内容は採用せず、矛盾を報告する。
2. bundled script の配置を確認する。

   ```bash
   test -f "$HOME/.claude/skills/my-handoff/SKILL.md"
   test -x "$HOME/.claude/skills/my-handoff/scripts/collect-handoff-context.sh"
   ```

3. リポジトリ内で次を実行する。

   ```bash
   bash "$HOME/.claude/skills/my-handoff/scripts/collect-handoff-context.sh"
   ```

   script は以下を検証し、成功時だけ共有可能な参照先を出力する。

   - working tree が clean である
   - current branch に upstream がある
   - `HEAD` と remote branch の commit が完全に一致する
   - remote URL が別マシンから取得可能な許可済み形式であり、credentials や query を含まない
   - GitHub CLI が利用可能な GitHub repository では、open PR の照会が成功する
   - 検証対象外の Git LFS と submodule が使われていない

   検証済み remote repository の open PR が1件あれば PR を優先する。なければ remote branch を使う。どちらの場合も remote branch 名と完全な commit SHA を含める。

4. script が成功した場合は、必要に応じて `git log`、`git show`、PR 本文、関連ドキュメントを読み、会話内の説明をリポジトリの状態と照合する。手順6へ進む。
5. script が失敗した場合は「共有準備」に従う。承認された操作が完了したら script を再実行する。再実行が成功するまで handoff prompt は作らない。
6. 下記の形式で、共有する remote branch または PR と、コピー可能な handoff prompt を返す。検証コマンドの実行結果は、このセッションで実際に確認できたものだけを書く。内部で実行した確認手順と raw output は表示しない。

## 共有準備

script の失敗原因が、現在の作業を remote で共有するための stage、commit、branch 作成、push、PR 作成・更新で解消できる場合だけ、次を行う。このスキルを実装作業や一般的な Git 公開作業へ広げない。

1. 変更前に、リポジトリの指示、`git status`、staged と unstaged の差分、未追跡ファイル、現在の branch、upstream、remote、送信先 remote branch の有無と commit、同じ head branch の open PR、最近の commit メッセージを読み取り専用で確認する。
2. 引き継ぐ作業に必要な変更と無関係な変更を分ける。区別できない場合は推測で stage せず、対象範囲をユーザーへ確認する。
3. commit 対象に必要な最小限の検証を、外部変更より先に実行する。検証が失敗した場合は、失敗内容を報告して停止する。修正、再試行、別の検証への置き換えは行わない。
4. 実行前に、次のうち該当する項目を示して一度だけ承認を求める。対象や宛先を省略した包括的な承認は求めない。

   - stage と commit: 対象ファイル、除外する dirty file、commit メッセージ
   - branch: 作成する branch 名と起点
   - push: remote 名、送信元 commit、送信先 branch、upstream 設定の有無
   - PR: 作成または更新、repository、base branch、head branch、title、本文の要点、draft 状態

5. 承認を得るまでは、上記の変更を一つも実行しない。最初の handoff 依頼は承認とみなさない。拒否された場合は handoff prompt を作らず、remote で共有可能な状態ではないことを報告して停止する。
6. 承認後に状態を再確認する。承認時から差分、HEAD、remote、PR の状態が変わっていれば実行せず、新しい状態に基づく承認を取り直す。
7. 承認された対象だけを明示的に stage する。staged diff を読み、対象外の変更、secret、credential、環境ファイルが含まれていないことを確認してから commit する。
8. push は承認された remote と branch への明示的な refspec で実行する。protected branch が送信先なら、その branch への push が承認内容に明記されている場合だけ続行する。force push、commit の amend、rebase などの履歴書き換えは行わない。
9. PR は承認に含まれる場合だけ、push の成功後に作成または更新する。open PR が存在しないことだけを理由に作成しない。branch を共有参照先にできる場合、PR は必須ではない。
10. 途中で失敗した場合は、その時点の外部変更と失敗を報告して停止する。暗黙の再試行、別 remote・branch・コマンドへの切り替え、部分的な成功の完了扱いは行わない。

## 停止条件

次の状態は共有準備で推測や回避をせず、handoff prompt を作らない。共有できない理由を具体的に報告して停止する。

- remote または PR 照会の失敗: 共有参照先を確認できない
- 複数の open PR: 推測で1件を選べない
- Git LFS または submodule: remote object の取得可能性をこのスキルでは検証できない
- 目的、受入条件、元の依頼、残作業の不足: 新しいセッションだけでは作業内容を確定できない
- 引き継ぐ変更と無関係な dirty file を安全に分離できない: commit 対象を確定できない
- 承認前の検証失敗: 検証済みの共有状態を作れない
- 承認後の操作失敗: 共有参照先の作成が完了していない
- 履歴書き換えが必要な状態: handoff の共有準備の範囲を超える

未コミットまたは未追跡の変更、upstream なし、remote branch なし、SHA 不一致、detached HEAD は、共有準備で安全に解消できる場合がある。自動実行せず、必要な変更を特定して承認を求める。安全な解消方法を特定できなければ停止する。

## 出力形式

角括弧の項目を確認済み情報で置き換える。目的、受入条件、元の依頼、残作業は必須である。現在の会話とリポジトリから自己完結した内容を確定できない場合は、handoff prompt を出力せず不足情報をユーザーへ確認する。

完了済み作業、判断・制約、関連箇所、検証結果に該当事項がなければ `なし` または `未実施` と明記する。不明な任意情報は、再開作業への影響を添えて `未確認` とする。空の節は削除しない。

最終回答は次の構造にする。ユーザーが行うことは、code block 全体を新しいセッションへ貼ることだけである。

~~~~markdown
引き継ぎ先: `[remote branch]`
PR: [PR URL。ない場合は「なし」]

新しいセッションへ、次をそのまま貼ってください。

```text
[下記の handoff prompt]
```
~~~~

handoff prompt は次の内容にする。

```text
別マシンの新しいセッションで、次の作業を引き継いでください。前のセッション履歴と前のマシンのローカルファイルは参照できません。このプロンプトとリモートリポジトリだけを情報源として扱ってください。リポジトリの取得、branch の checkout、commit の照合など、再開に必要な操作はあなたが実行してください。ユーザーに細かなコマンド実行を依頼しないでください。

## 取得元
- リポジトリ: [credentials を含まない remote URL]
- 共有参照先: [PR URL、または remote 名と branch 名]
- ブランチ: [branch]
- 確認済み commit: [full SHA]

## 再開時の確認
- 共有された PR または branch を取得し、確認済み commit と一致することを確認してください。不一致なら作業を始めず報告してください。
- リポジトリ内の `AGENTS.md`、`CLAUDE.md`、関連ドキュメント、差分、関連テストを確認してから残作業を続けてください。

## 目的
[最終的に達成すること]

## 受入条件
- [完了を判定できる具体的な条件]

## 元の依頼
[ユーザーの依頼を、新しいセッションだけで意味が通る形に言い換えた内容]

## 完了済み
- [remote commit に含まれる完了事項]

## 残作業
- [次に行う具体的な作業]

## 判断・制約
- [採用済みの方針、変更してはいけない契約、安全上の制約]

## 関連箇所
- [remote commit に存在するファイル、関数、issue など]

## 検証状況
- 成功: [実行済みコマンドと結果]
- 未実施: [まだ必要な検証]
- 既知の問題: [失敗、blocker、残るリスク。なければ「なし」]

## 完了時の報告
- 実施した変更、検証コマンドと結果、残る問題を簡潔に報告してください。
```

## 情報管理

- secrets、credentials、`.env` の内容、個人情報を含めない。
- 前のマシンの絶対パス、session ID、一時ファイル、未公開 artifact を参照しない。
- 「前と同じ」「先ほどの内容」のような、過去の会話を必要とする表現を使わない。
- 完了済み作業は remote commit に含まれるものだけを書く。ローカルだけの状態を完了扱いしない。
- PR がある場合も branch 名と full SHA を併記し、PR の更新後に参照先が曖昧にならないようにする。
