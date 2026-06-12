---
name: my-sdd
description: >-
  Unified Spec-Driven Development workflow: plan → tasks → implement with test-first approach.
  Automatically detects current phase and routes accordingly.
  Use when the user asks to plan a feature, break down tasks from a spec, implement from
  requirements, or resume work from an existing requirements.md / design.md / tasks.md
  (e.g., "新機能を設計", "タスク分解", "specから実装", "SDD", "spec再開", "docs/specs から続行").
  Do NOT use for simple bug fixes, refactoring, or tasks that don't need a spec-driven approach.
argument-hint: "[feature-name|docs/specs/path|request] [--no-worktree]"
---

# Spec-Driven Development (SDD) Unified Workflow

要件定義から実装までを、現在の状態を自動検出して 1 コマンドで進める統合エージェント。

```
Phase 1 (Plan):  1-0 Investigate → 1-1 Clarify → 1-2 Specify → 1-3 Design → 1-4 External Review
                 ↓ ユーザー承認
Phase 2 (Tasks): タスク分解 → tasks.md
                 ↓ ユーザー承認
Phase 3 (Impl):  3-0 Worktree gate → 3-1 読込 → ┌─→ 3-2 実行 → 3-3 テスト → 3-4 更新 ─┐
                                                  └──── 未完タスクが残る間ループ ─────┘
                 ↓
完了報告 → /my-pr
```

## 参照ファイル

- `references/templates.md` — requirements.md / design.md / tasks.md のテンプレート
- `references/senior-review-checklist.md` — Phase 1-0 調査範囲・1-3 設計観点・1-4 レビュー基準
- `references/external-review.md` — Phase 1-4 起動・反映ルール
- `references/document-review.md` — requirements/design/tasks の内部レビューゲート
- `references/worktree-gate.md` — Phase 3-0 判定・spec 移送
- `../my-subagent/SKILL.md` — Phase 3 の subagent 委譲・レビューゲート

## 共通原則

- **言語**: 仕様書・タスクは日本語、コード・コミットは英語
- **スペックパスを常に明示**: 完了メッセージ・次のステップで `docs/specs/{name}` を必ず含める
- **フェーズ表示**: 現在のフェーズ（1-0 / 1-1 / ... / 3-4）を常に明示
- **tasks.md はファイル出力**: TodoWrite だけでなく `tasks.md` も必ず作成・更新
- **フェーズ間遷移はユーザー承認**: Phase 1→2、2→3 は自動遷移しない（Phase 3 内のタスク境界停止禁止とは別範囲。3-2 参照）

## 引数処理

`$ARGUMENTS` の値で分岐:

| パターン | 例 | 処理 |
|---|---|---|
| パス | `docs/specs/foo` | `spec_dir` に設定 |
| 機能名（kebab） | `foo-bar` | `docs/specs/foo-bar` を `spec_dir` に |
| 自然言語要求 | `「ログ保持期間を…」` | Phase 1 の初期要求として処理。機能名は対話で決定 |
| なし | — | `docs/specs/` を走査し進行中を提示、なければ要求を尋ねる |

フラグ `--no-worktree`（環境変数 `MY_SDD_WORKTREE=0` でも可）で Phase 3-0 をスキップ。

## 状態検出

`spec_dir` が定まったら以下の順で判定:

1. `spec_dir` 不在 → **Phase 1-0**
2. `requirements.md` 不在 → **Phase 1-0 / 1-1**
3. `design.md` 不在 → **Phase 1-3**
4. `tasks.md` 不在: `/tmp/sdd-reviews/{name}/done` の mtime が 7 日以内なら **Phase 2**、それ以外は **Phase 1-4**
5. `tasks.md` 全 `[x]` → **完了報告**
6. `tasks.md` に `[ ]` あり → **Phase 3**

開始時に以下を必ず表示する:

```
🔍 状態検出結果:
  📁 spec_dir: docs/specs/{name}/
  📄 requirements.md: ✅ / ❌
  📄 design.md:       ✅ / ❌
  📄 tasks.md:        ✅ (X/Y 完了) / ❌

▶️ Phase {N} ({phase-name}) を開始します。
```

---

## Phase 1: Plan

### 1-0 Investigation（事前調査）

シニア/スタッフ視点で関連情報を集める前準備。「コードで分かることはユーザーに聞かない」を徹底し、Phase 1-1 の質問削減と Phase 1-3 の設計判断に使う。`Explore` subagent で並列化してよい。**調査範囲は `senior-review-checklist.md`**。自明な決定は質問せず確認のみ（「Y を使う前提でよいか」）。

### 1-1 Clarify（要件明確化）

ユーザー要求を**決定木**として捉え、対話で 1 問ずつ確定する。

- **1 問ずつ**（強関連の決定はまとめて、一度に 3 問以下）
- **推奨回答を必ず添える**（出せないならまず調査）
- **依存の深い枝から下る**
- **決定木はファイル化しない**（頭の中で展開）

下りきったら 5 観点で漏れチェック: スコープ / ユーザー / 成功基準 / 制約 / 優先度。

### 1-2 Specify

`requirements.md` を作成（templates.md 参照）。

### 1-3 Design

調査結果と要件をもとに `design.md` を作成（templates.md 参照）。**設計時に潰す観点の全リストは `senior-review-checklist.md`**。全観点について「触れた／触れない理由がある」状態にし、Risks / Rejected alternatives / Open Questions を必ず記載する。

### 1-4 External Review

まず `document-review.md` の **Spec review** を実行し、実装計画に進める粒度か確認する。

- `Status: Approved` → 外部レビューへ進む
- `Issues Found` かつ挙動・契約変更なし → `requirements.md` / `design.md` に自動反映し、再レビュー
- `Issues Found` かつ挙動・API・schema・config・CLI・error semantics 変更あり → ユーザー承認を得てから反映

`codex` / `gemini` / `claude (subagent)` の **3 並列で自動起動**。詳細手順・プロンプト・反映ルールは `external-review.md`。

**反映ルール（要旨）:**
- 挙動・データモデル不変の指摘 → **自動反映**（用語統一、Open Questions 追記、構造整理など）
- 挙動・API・スキーマ・移行戦略の変更を伴う指摘 → **ユーザー合意の上で反映**
- 不採用 → `decisions.md` に理由記録
- 判断が微妙なら確認側に倒す
- **1 者以上成功で続行可、0 件成功は Blocked**（ユーザー override 必須）

完了で `/tmp/sdd-reviews/{name}/done` を作成（**mtime + 7 日**が有効期限、超過時は次回起動で自動再レビュー）。

---

## Phase 2: Tasks

**前提**: `requirements.md` / `design.md` 揃い。

**分解原則:**

1. 1 タスク = 1 つの明確な成果物（小さく）
2. テストタスクを実装タスクの前に配置（テストファースト）
3. 他タスクへの依存を減らす
4. 独立タスクに `[P]` マーク
5. 各タスクに対象ファイルパスを明記

良い粒度: 「UserRepository.create を実装」 / 悪い粒度: 「ユーザー機能を実装」。

**出力**: `tasks.md`（templates.md 参照）。

作成後、`document-review.md` の **Plan review** を実行する。

- `Status: Approved` → Phase 2 完了としてユーザーに Phase 3 進行確認を出す
- `Issues Found` → `tasks.md` を修正して再レビュー
- `[P]` 指定は write set と依存関係が説明できる場合だけ残す

---

## Phase 3: Impl

**前提**: `requirements.md` / `design.md` / `tasks.md` 揃い。

Phase 3 開始時に `my-subagent` を使う。Skill tool が使える環境では明示的に invoke する。使えない環境では `../my-subagent/SKILL.md` の手順に従う。

**Phase 3 全体は 1 ループ**: 3-1 で全未完タスクを読み込んだら、3-2 → 3-3 → 3-4 を**未完タスクが 0 になるまで自動で繰り返す**。1 タスク完了で skill から抜けない。`tasks.md` に `[ ]` が残っている限り、main は次のタスク（または並列バッチ）の Task tool 起動を**同じターン内**で続ける。

### 3-0 Worktree gate

保護ブランチ（`main` / `master` / `staging` / `develop` / `release/*` / `hotfix/*`）から実装しない。検出時は `feat-{feature-name}` で worktree を作成し `docs/specs/{name}/` を移送（`worktree-gate.md`）。

スキップ: フィーチャブランチ上 / worktree 内 / `--no-worktree` / `MY_SDD_WORKTREE=0`。

### 3-1 タスクの読み込み

`tasks.md` の未完了タスクと依存関係を確認、TodoWrite に登録。

### 3-2 タスク実行

**🔁 連続実行（必須・既定）**: タスク境界で**絶対に停止しない**。次の挙動は**全て禁止**:

- 「次のタスクに進んでよいですか？」と尋ねる
- 1 タスク終了時点で完了報告だけ出して応答を終える
- 「Task N 完了。続行します」と書いた直後にターンを閉じる
- 進捗サマリだけのメッセージで一旦停止する

3-4 で `[x]` を付けたら**同じターン内で**次タスクの Task tool 起動／並列バッチ起動を続行する。停止してよいのは下の「停止条件」に該当するときだけで、それ以外は **`[ ]` が無くなるまでループを抜けない**。

- **Task tool 優先**: 利用できる環境では**実装・テストとも** Task tool（`general-purpose` 等）に委譲。main の役割は (a) 依存と write set の確認、(b) Task 起動と統合、(c) テスト実行とレビュー、(d) `tasks.md` / TodoWrite の更新、(e) **次タスクの起動**
- **並列起動**: `[P]` でも起動前に main が以下 **3 条件をすべて確認** → 1 メッセージ内に複数 Task tool を並べる:
  1. 他タスクと依存関係なし
  2. 編集対象ファイル（write set）が他タスクと衝突しない
  3. 必要な入力（前タスク成果物・design.md 該当節）が揃っている
- **テストファースト**: 同一機能ならテストを先に

サブエージェントには **対象ファイル / 受入基準 / 詳細 / 参考既存実装 / 既存規約遵守** を必ず渡す。

各タスクは `my-subagent` のゲートに従い、**implementer → spec compliance reviewer → code quality reviewer → main 検証** の順で進める。spec compliance が通るまで code quality reviewer に進まない。

**停止条件（これ以外では止まらない・進捗確認・承認待ちでの停止は禁止）:**

1. テスト失敗が 1 度の修正で解消せず原因が即特定できない
2. 設計（design.md）と実装中の事象が矛盾
3. ユーザー判断が必要な未決事項（仕様の曖昧さ、トレードオフ）に直面
4. 破壊的操作・保護ブランチへの書き込みなど CLAUDE.md で承認必須の行為

停止条件に該当した場合のみ、何のタスクで何が起きたか・必要な判断を 1 メッセージで提示して停止する。それ以外（テストが通った／タスク N が完了した／次が `[P]` バッチ etc.）では**停止せず即次の Task tool を起動**する。

### 3-3 レビューとテスト実行

main が subagent レビュー結果を読み、Required 指摘が残っていないことを確認する。その後、main が関連テストを実行（例: `pytest tests/test_{module}.py -v`）。失敗時は修正 → 再実行。**レビュー通過とテスト成功までは tasks.md を `[x]` にしない**。テスト成功後は 3-4 → 次タスク起動まで同ターンで継続する。

### 3-4 tasks.md 更新

3-3 を通ったタスクのみ `[x] 完了 ✅` に更新。更新後、未完タスクが残っていれば**応答を終了せず**に 3-2 に戻り次タスクを起動する。Phase 3 の最後に最終整合チェック（`tasks.md` の `[x]` 数と TodoWrite の `completed` 数が一致するか、未完了タスクが残っていないか）を 1 度だけ行う。

---

## 完了メッセージ

各フェーズ完了で表示。

**Phase 1 完了:**
```
✅ Phase 1 (Plan) が完了しました。

📁 出力:
  - docs/specs/{name}/{requirements.md, design.md}
  - /tmp/sdd-reviews/{name}/{codex,gemini,claude}.md

🔎 外部レビュー: 自動反映 A / 合意反映 B / 不採用 C（decisions.md 参照）
📋 要件: US X件 / AC Y件 / Must Z件

▶️ Phase 2 (Tasks) に進みますか？
   /my-sdd docs/specs/{name} で後から再開できます。
```

**Phase 2 完了:**
```
✅ Phase 2 (Tasks) が完了しました。

📁 出力: docs/specs/{name}/tasks.md
📋 タスク: 総 X / テスト Y / 実装 Z / 並列可 W

▶️ Phase 3 (Impl) に進みますか？
   /my-sdd docs/specs/{name} で後から再開できます。
```

**Phase 3 完了 / 完了報告（全 `[x]`）:**
```
✅ Phase 3 (Impl) が完了しました。   ← 完了報告のときは「🎉 すべてのタスクが完了しています。」

📋 タスク: X/Y 完了（テスト A/B / 実装 C/D）
🧪 テスト: 実行 Z / 成功 Z / 失敗 0
📁 変更ファイル: ...

👉 次のステップ:
  - /my-pr で PR 作成
  - マージ後は gwc で worktree を削除
  - /my-sdd {new-feature} で次の機能を計画
```
