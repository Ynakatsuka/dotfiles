# 別マシンへの引き継ぎ

別マシンの新しいセッションで、前のセッション履歴やローカルファイルに依存せず作業を再開できるプロンプトを作る。

この経路は共有済みの branch / PR を検証し、コピー可能なプロンプトを作る。通常は読み取りだけで完了する。必要なローカルブランチの命名・作成は確認せず行う。commit、push、PR 作成・更新は今回の依頼で許可済みの場合だけ行い、未許可なら共有できない具体的な理由を報告する。公開済みの参照で再開できるなら、引き継ぎ用のブランチを余分に作らない。

## 手順

1. 現在把握している依頼、完了条件、次の作業と会話にしかない判断・制約を短く整理する。会話履歴を再取得したり、要約用のエージェントへ全履歴を渡したりしない。`$ARGUMENTS` が空でなければ追加情報として使う。リポジトリの証拠と矛盾する内容は採用せず、矛盾を報告する。
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

4. 共有 commit に含まれるか不明な完了事項だけ、対象を絞って照合する。引き継ぎのためにコードやログを広く読み直さず、再開先で調査できる内容は参照箇所を渡す。検証結果は対象の状態と実際に確認できたものだけを書く。
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

commit、push、PR 作成で解消する場合は現在の依頼の許可範囲を確認する。既に許可されていれば必要な検証を経て進め、同じ許可やブランチ名を聞き直さない。未許可なら公開が必要な状態を報告する。ブランチの作成・命名の確認と、外部への公開の許可を混同しない。

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
作業用のローカルブランチが必要なら、共有commitを分岐元に、タスクに沿った名前を自動で決めて作成してください。命名・作成だけの確認は不要です。commitやpushは依頼の許可範囲に従ってください。

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
