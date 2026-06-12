---
name: my-subagent
description: >-
  Delegate subagent-suitable work to subagents and keep the main agent focused
  on orchestration, decisions, integration, and final verification. Use
  automatically before non-trivial work when any part can be isolated as
  independent research, implementation, testing, review, or multi-step worker
  work; also use when the user says "subagent", "委譲", "並列実行", or asks to
  use lighter models for worker tasks. Do NOT use for simple one-shot answers,
  tiny one-file edits, irreversible actions, or decisions that require user
  approval.
argument-hint: "[task-or-plan]"
---

# Subagent Delegation

委譲できる作業は subagent に渡し、main は司令塔として判断・統合・検証に集中する。

## 役割分担

- **main**: 作業分解、依存関係と write set の確認、subagent 起動、レビュー、検証、統合、ユーザー判断の窓口
- **subagent**: 調査、実装、テスト追加、局所的な修正、自己レビュー
- **main が保持する判断**: public contract、DB schema、API、設定キー、破壊的操作、ユーザー承認が必要な変更

## 実行条件

開始時に、main が自動で委譲可否を判定する。ユーザーが明示的に「subagent を使う」と言っていなくても、以下に該当すれば使う。

使う:

- 独立した調査・実装・テスト・レビューがある
- タスクが明確な入力、出力、対象ファイル、受入基準を持つ
- 複数の候補調査やファイル群調査を並列化できる
- main の文脈を汚さずに局所作業を進めたい

使わない:

- 1 ファイルの小さな編集で、委譲コストの方が高い
- public contract 変更の可否が未決
- ユーザー承認が必要な判断が中心
- subagent が使えない環境

## モデル選択

subagent には、作業に足りる範囲で最も軽量なモデルを使う。

| 作業 | モデル方針 |
|---|---|
| grep・ファイル列挙・単純調査 | 軽量・高速モデル |
| 明確な単一ファイル実装 | 軽量・高速モデル |
| 複数ファイル実装・テスト修正 | 標準モデル |
| 設計判断・仕様一致レビュー・セキュリティレビュー | 高性能モデル |

subagent 起動ツールが model 指定をサポートする場合だけ指定する。サポート有無が不明な場合は、存在しない引数を推測して付けない。

## 手順

### 1. 作業を分解する

1. ユーザー依頼、plan、`tasks.md`、チェックリストから作業単位を抽出する。
2. 各作業について以下を整理する。
   - 依存関係
   - write set（編集予定ファイル）
   - 受入基準
   - 必要な既存コード・規約
   - 検証コマンド
   - 推奨モデル方針
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
- モデル選択方針の決定

### 3. 並列化を判定する

並列起動は、以下をすべて満たす場合だけ行う。

1. タスク間に依存関係がない
2. write set が衝突しない
3. 必要な入力がすべて揃っている
4. 同時実行でテストや生成物が競合しない

満たさない場合は逐次実行にする。

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
- 重要な設計判断を軽量モデルに任せる
