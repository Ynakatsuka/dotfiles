---
name: my-handoff
description: >-
  Creates a self-contained prompt for continuing repository work on another
  machine in a fresh session, using an exact remote branch or open GitHub PR as
  the shared state. Its final answer tells the user which branch or PR to share
  and provides one paste-ready prompt without asking the user to run setup
  commands. Use when the user asks for "handoff", "引き継ぎ", "別マシンで続ける",
  "別セッションへ渡す", or sharing the current task with a branch or PR. Do NOT
  use for same-session summaries, committing or pushing changes, PR creation,
  or handoffs that rely on local files or session history.
argument-hint: "[追加の引き継ぎ事項]"
---

# my-handoff

別マシンの新しいセッションで、前のセッション履歴やローカルファイルに依存せず作業を再開できるプロンプトを作る。

このスキルは読み取り専用である。commit、push、PR 作成・更新、ローカルの handoff ファイル作成は行わない。

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

4. 必要に応じて `git log`、`git show`、PR 本文、関連ドキュメントを読み、会話内の説明をリポジトリの状態と照合する。検証コマンドの実行結果は、このセッションで実際に確認できたものだけを書く。
5. 下記の形式で、共有する remote branch または PR と、コピー可能な handoff prompt を返す。内部で実行したコマンド、確認手順、raw output は表示しない。

## 停止条件

script が失敗した場合は handoff prompt を作らず、共有できない状態を具体的に報告して停止する。

- 未コミットまたは未追跡の変更: ローカルにしかない内容は引き継げない
- upstream なし、remote branch なし、SHA 不一致: 現在の commit は別マシンから正確に取得できない
- detached HEAD: 再開先の branch を特定できない
- remote または PR 照会の失敗: 共有参照先を確認できない
- 複数の open PR: 推測で1件を選べない
- Git LFS または submodule: remote object の取得可能性をこのスキルでは検証できない
- 依頼、完了条件、残作業の不足: 新しいセッションだけでは作業内容を確定できない

commit、push、PR 作成で解消できる場合も自動実行しない。細かなコマンドは示さず、remote で共有可能な状態にする必要があることだけを伝える。必要なら、このセッションで commit、push、PR 作成まで依頼できると案内する。

## 出力形式

角括弧の項目を確認済み情報で置き換える。依頼、完了条件、`現在地` の `次` は必須である。現在の会話とリポジトリから自己完結した内容を確定できない場合は、handoff prompt を出力せず不足情報をユーザーへ確認する。

該当事項のない任意項目は削除する。不明な情報は、再開作業に影響する場合だけ `未確認` と理由を記す。説明の重複、実行済みコマンドの詳細、定型的な締めは加えない。

最終回答は次の構造にする。

~~~~markdown
引き継ぎ先: [PR URL、または `remote/branch`] @ `[full SHA]`

```text
[下記の handoff prompt]
```
~~~~

handoff prompt は次の内容にする。

```text
取得元: [credentials を含まない remote URL]
参照先: [PR URL、または remote 名と branch 名]
commit: [full SHA]

共有参照先を取得し、commit の一致とリポジトリ内の指示を確認してから作業を続けてください。不一致なら作業を始めず報告してください。

## 依頼
[元の依頼と最終的に達成することを、自己完結する形でまとめる]

## 完了条件
- [完了を判定できる具体的な条件]

## 現在地
- 完了: [remote commit に含まれる完了事項]
- 次: [次に行う具体的な作業]
- 方針・制約: [採用済みの方針、変更してはいけない契約、安全上の制約]

## 関連箇所
- [remote commit に存在するファイル、関数、issue など]

## 検証
- 成功: [実行済みコマンドと結果]
- 未実施・問題: [まだ必要な検証、失敗、blocker、残るリスク]
```

## 情報管理

- secrets、credentials、`.env` の内容、個人情報を含めない。
- 前のマシンの絶対パス、session ID、一時ファイル、未公開 artifact を参照しない。
- 「前と同じ」「先ほどの内容」のような、過去の会話を必要とする表現を使わない。
- 完了済み作業は remote commit に含まれるものだけを書く。ローカルだけの状態を完了扱いしない。
- PR がある場合も branch 名と full SHA を併記し、PR の更新後に参照先が曖昧にならないようにする。
