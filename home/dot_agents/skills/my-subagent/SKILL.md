---
name: my-subagent
description: >-
  Delegate subagent-suitable work to subagents and keep the main agent focused
  on orchestration, decisions, integration, and final verification. Use
  automatically whenever a clear, bounded investigation or implementation with
  settled policy can be isolated; also use when the user says "subagent",
  "委譲", or "並列実行". Do NOT use for simple one-shot answers, short work
  where delegation or review overhead is not worthwhile, unresolved decisions
  or work requiring user approval, or final integration and verification.
---

# Subagent Delegation

委譲できる作業は subagent に渡し、main は司令塔として判断・統合・検証に集中する。

## 役割分担

- **main**: 作業分解、依存関係と write set の確認、依存関係の追加・変更判断、subagent 起動、レビュー、検証、統合、ユーザー判断の窓口
- **subagent**: 調査、実装、テスト追加、局所的な修正、自己レビュー
- **subagent の禁止事項**: 自身の作業をさらに subagent へ再委譲しない
- **main が保持する判断**: 依存関係の追加・変更、public contract、DB schema、API、設定キー、破壊的操作、ユーザー承認が必要な変更

## 実行条件

開始時に、main が自動で委譲可否を判定する。ユーザーの明示要求は不要である。ただし、ユーザーが委譲を禁止・制限した場合はその指示を優先し、現在の実行時方針も許す場合だけ委譲する。以下に該当すれば使う。

使う:

- 目的と対象が明確な、bounded な調査
- 方針が確定し、対象と受入基準が明確な実装
- 独立したテスト・レビューがある
- 複数の候補調査やファイル群調査を並列化できる
- main の文脈を汚さずに局所作業を進めたい

使わない:

- 調査も実装もない simple one-shot answer
- 数分で完了する作業
- 委譲・結果確認・レビューの負担に見合わない作業
- ユーザー承認、public contract、実装方針などの判断が未確定
- subagent の結果を統合する作業、最終検証、完了判断
- subagent が使えない環境

委譲条件を満たさない作業まで機械的に委譲せず、main が直接処理する。

## Codex 固有の委譲規則

この節は Codex 実行時だけ適用し、Claude などには適用しない。Codex 実行時には、本スキル内の一般規則、特に「作業ごとのゲート」の二段階 reviewer 手順より優先する。

- 数分で完了する作業、または委譲・結果確認・レビューの負担に見合わない作業は main が直接処理する
- `luna_worker` は、方針、対象ファイル、受入基準、検証方法が明確な、低リスクの実装またはテストの leaf task で第一候補にする。単一機能の実装、局所的な修正、テスト追加、方針が確定した複数ファイルの機械的修正を含む。高リスクまたは判断の重い作業は渡さない
- `explorer` は、特定のコードベース質問を調べる read-only の作業に使う
- `worker` は、複数モジュールの理解や反復的な調査が必要な、範囲の広い実装・修正作業に使う。`luna_worker` と `worker` の両方に該当する場合は `luna_worker` を優先する
- `default` は、上記の specialized な役割に当てはまらない調査または実装作業に使う
- 独立 reviewer は既定で起動しない。重大な不確実性または高リスクがある場合だけ使う
- main は各 subagent の結果と差分を確認し、統合と最終検証を担う

## モデル方針

subagent は設定済みの defaults を使う。ユーザーが明示しない限り、spawn 時に `model` と `reasoning_effort` を指定して上書きしない。

Codex の `spawn_agent` では、full-history fork (`fork_turns: "all"` またはその既定値) が親の model / reasoning effort を継承する。設定済みの subagent defaults を使う場合は `fork_turns: "none"` または必要最小限の positive turn count を明示し、必要な文脈は prompt に含める。

ユーザーが model を明示した場合だけ、その指定を spawn 時に渡してよい。reasoning effort は設定済みの default を下げない。起動ツールが指定をサポートしない場合は、存在しない引数を推測して付けない。

## 手順

### 1. 作業を分解する

1. ユーザー依頼、plan、`tasks.md`、チェックリストから作業単位を抽出する。
2. 各作業について以下を整理する。
   - 依存関係
   - write set（編集予定ファイル）
   - 受入基準
   - 必要な既存コード・規約
   - 検証コマンド
3. TodoWrite が使える環境では、作業単位を登録する。

### 2. 委譲可否を判定する

subagent に委譲する:

- 既存コード調査
- 明確なタスク単位の実装
- テスト追加・修正
- 局所的なバグ修正
- spec compliance review
- code quality review

main が行う:

- タスク分解の変更
- ユーザー確認
- public contract 変更判断
- 複数 subagent の結果統合
- 最終テスト実行
- `tasks.md` / TodoWrite の完了更新

### 3. 並列化を判定する

並列起動は、以下をすべて満たす場合だけ行う。

1. タスク間に依存関係がない
2. write set が衝突しない
3. 必要な入力がすべて揃っている
4. 同時実行でテストや生成物が競合しない

満たさない場合は逐次実行にする。

書き込みを行う worker を並列起動する場合は、各 worker に隔離した worktree と互いに重複しない write set の両方を割り当てる。main は、その worker の実行中に担当ファイルを同時編集しない。

### 4. subagent に渡す情報

各 subagent prompt には必ず含める。

- タスク本文
- 関連する requirements / design / plan の抜粋
- 対象ファイルと変更禁止ファイル
- 受入基準
- 既存規約・参考実装
- 実行すべき検証コマンド
- 失敗時の報告形式
- 「不明点・契約変更・破壊的操作は実装せず BLOCKED で返す」

テンプレートは `references/prompts.md` を使う。

### 5. 作業ごとのゲート

実装・テストを伴う作業では以下を順番に実行する。

1. implementer subagent が実装・自己レビュー
2. main が差分を確認
3. spec reviewer subagent が仕様一致を確認
4. spec 不一致があれば implementer に戻す
5. code quality reviewer subagent が品質を確認
6. 重要な品質指摘があれば implementer に戻す
7. main が関連検証コマンドを実行
8. 検証が通ったタスクだけ完了に更新

仕様一致レビューが通る前に品質レビューへ進まない。

調査のみの作業では、main が調査結果の根拠ファイル・検索条件・未確認範囲を確認してから採用する。

### 6. status の扱い

subagent には以下のいずれかで終了させる。

| status | main の対応 |
|---|---|
| `DONE` | 差分確認とレビューへ進む |
| `DONE_WITH_CONCERNS` | 懸念を読んで、必要なら修正またはユーザー確認 |
| `NEEDS_CONTEXT` | 不足情報を渡して再起動 |
| `BLOCKED` | 原因を分類し、設計矛盾・ユーザー判断・権限不足なら停止 |

同じ条件で無言再試行しない。

## 完了条件

- すべてのタスクが完了済み
- 実装作業では spec compliance review が通過
- 実装作業では code quality review の Required 指摘が解消済み
- main が必要な検証コマンドを実行し成功を確認済み
- TodoWrite や `tasks.md` がある場合は状態が一致

## Red flags

- subagent に依頼を丸投げし、必要な文脈を渡していない
- spec 不一致を「軽微」として次へ進む
- reviewer の指摘を main が読まずに承認する
- write set 衝突のあるタスクを並列起動する
- subagent がユーザー承認事項を勝手に決める
- main が検証せずに完了扱いする
