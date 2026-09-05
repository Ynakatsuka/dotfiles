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

## 委譲の判断

現在の実行時方針とユーザー指示が許す場合に、範囲と方針が確定した独立作業を委譲する。
短時間の作業、密接に関係する変更、委譲と結果確認の負担に見合わない作業は main が行う。

- main は作業分解、承認、依存関係・公開契約・設定・破壊的操作の判断、統合、最終検証と完了判断を担う。
- subagent は割り当てられた調査、実装、テスト、自己レビューを行う。さらに subagent へ委譲しない。

## Codex の役割選択

この節は Codex 実行時だけ適用する。

| 役割 | 用途 |
|---|---|
| `explorer` | 特定のコードベース質問を調べる読み取り専用の調査 |
| `luna_worker` | 方針・対象・受入基準・検証が明確な低リスクの実装やテスト。条件が合えば `worker` より優先する |
| `worker` | 複数モジュールの理解や反復調査を要する実装 |
| `reviewer` / `simplifier` | 明示的なレビュー依頼で、それぞれの観点が必要な場合 |
| `default` | 上記に当てはまらない作業 |

設定済みの subagent defaults を使い、ユーザーが指定しない限り `model` と `reasoning_effort` を上書きしない。指定がある場合も設定済みの reasoning effort を下げない。
Codex の full-history fork は親の model と reasoning effort を継承するため、役割別の設定を使う場合は `fork_turns: "none"` または必要最小限の正のターン数を指定し、残りの文脈を依頼文に含める。
他の実行環境でも設定済みの defaults を使い、起動ツールが扱えない引数を推測して付けない。

## 依頼と並列化

`references/prompts.md` を使い、各依頼に次を含める。

- タスクと必要な要件・設計・既存規約の抜粋
- 担当ファイル、変更禁止範囲、最初に読む参考実装
- 受入基準、検証コマンド、失敗や不明点の報告方法

並列起動は、依存関係がなく、必要な入力が揃い、編集・テスト・生成物が競合しない場合に限る。
書き込みを行う worker を並列起動する場合は、隔離した worktree と重複しない担当ファイルを割り当てる。
main は実行中の worker の担当ファイルを編集しない。worker には他の作業者がいることと、他者の変更を戻さず取り込むことを伝える。

## 結果の確認

main は調査結果の根拠と未確認範囲、実装の差分と受入基準への適合を確認する。
独立 reviewer は、重大な不確実性、高リスク、または明示的なレビュー要件がある場合に起動する。
レビューが必要なら、仕様と品質の両方を一つの依頼で確認する。観点を分ける必要がある場合だけ複数に分担する。

| status | main の対応 |
|---|---|
| `DONE` | 結果と差分を確認する |
| `DONE_WITH_CONCERNS` | 懸念を確認し、必要な修正や判断へ進む |
| `NEEDS_CONTEXT` | 不足情報を渡す |
| `BLOCKED` | 原因を分類し、権限やユーザー判断が必要なら該当作業を止める |

同じ条件で無言再試行しない。仕様不一致と重要な指摘を解消し、main が必要な検証を通した作業だけ完了にする。
`tasks.md` などで進捗を管理している場合は、確認した結果に合わせて更新する。
