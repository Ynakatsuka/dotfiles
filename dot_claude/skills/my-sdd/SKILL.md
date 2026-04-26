---
name: my-sdd
description: >-
  Unified Spec-Driven Development workflow: plan → tasks → implement with test-first approach.
  Automatically detects current phase and routes accordingly.
  Use when the user asks to plan a feature, break down tasks from a spec, or implement from
  requirements (e.g., "新機能を設計", "タスク分解", "specから実装", "SDD").
  Do NOT use for simple bug fixes, refactoring, or tasks that don't need a spec-driven approach.
argument-hint: "[feature-name]"
---

# Spec-Driven Development (SDD) Unified Workflow

要件定義から実装までの全フェーズを、現在の状態を自動検出して実行する統合エージェント。

- **Phase 1 (Plan)**: 事前調査 → 要件明確化 → requirements.md → design.md → 外部レビュー
- **Phase 2 (Tasks)**: タスク分解 → tasks.md
- **Phase 3 (Impl)**: worktree gate → 実装 + テスト → tasks.md 更新

```
Phase 1: 1-0 Investigation → 1-1 Clarify → 1-2 Specify → 1-3 Design → 1-4 External Review
   ↓ (ユーザー承認)
Phase 2: タスク分解 → tasks.md
   ↓ (ユーザー承認)
Phase 3: 3-0 Worktree gate → 3-1 読込 → 3-2 実行 → 3-3 テスト → 3-4 更新
   ↓
完了報告 → /pull-request
```

## 参照ファイル

- `references/templates.md` — requirements.md / design.md / tasks.md のテンプレート
- `references/senior-review-checklist.md` — Phase 1-0 の調査範囲、1-3 の設計観点、1-4 のレビュー基準
- `references/external-review.md` — Phase 1-4 の起動手順・反映ルール
- `references/worktree-gate.md` — Phase 3-0 の判定・spec 移送スクリプト

## 引数処理

`$ARGUMENTS` の値で分岐:

1. **パス指定** (`docs/specs/` を含む): そのパスを `spec_dir` に
2. **機能名指定** (ケバブケース): `docs/specs/{value}` を `spec_dir` に
3. **要求説明** (自然言語): Phase 1 の初期要求として処理。機能名は対話で決定
4. **指定なし**: `docs/specs/` を走査し、進行中があれば候補表示、なければ要求を尋ねる

### フラグ

- `--no-worktree`: Phase 3-0 をスキップ（環境変数 `MY_SDD_WORKTREE=0` でも可）

## 状態検出

`spec_dir` が定まったら以下の順で判定:

1. `spec_dir` 不在 → **Phase 1-0**
2. `requirements.md` 不在 → **Phase 1-0 / 1-1**
3. `design.md` 不在 → **Phase 1-3**
4. `design.md` あり / `tasks.md` 不在:
   - `/tmp/sdd-reviews/{name}/done` がない、または mtime > 7 日 → **Phase 1-4**
   - 有効な `done` あり → ユーザー確認の上 **Phase 2**
5. `tasks.md` の全タスクが `[x]` → **完了報告**
6. `tasks.md` に `[ ]` あり → **Phase 3**

フェーズ開始時は必ず以下を表示する:

```
🔍 状態検出結果:
  📁 spec_dir: docs/specs/{feature-name}/
  📄 requirements.md: ✅ / ❌
  📄 design.md:       ✅ / ❌
  📄 tasks.md:        ✅ (X/Y 完了) / ❌

▶️ Phase {N} ({phase-name}) を開始します。
```

---

## Phase 1: Plan

### 1-0 Investigation（事前調査）

要件明確化に入る前に、シニア/スタッフ視点で関連情報を集める。**「コードで分かることはユーザーに聞かない」**を徹底するための前準備。調査範囲は `senior-review-checklist.md` 参照。`Explore` subagent で並列化してよい。自明な決定は質問せず確認のみ（「Y を使う前提でよいか」）。

### 1-1 Clarify（要件明確化）

ユーザー要求をルートとした**決定木**として捉え、対話で枝を1つずつ確定する。

- **1問ずつ**（強関連の決定はまとめて、一度に3問以下）
- **推奨回答を必ず添える**（出せないならまず調査）
- **コードで分かることは聞かない**
- **依存の深い枝から下る**
- **決定木はファイル化しない**（頭の中で展開）

下りきったら 5 観点で漏れチェック: スコープ / ユーザー / 成功基準 / 制約 / 優先度。

### 1-2 Specify

`requirements.md` を作成。テンプレートは `templates.md` 参照。

### 1-3 Design

Phase 1-0 の調査結果と要件をもとに `design.md` を作成。**設計時に潰す観点の全リストは `senior-review-checklist.md`**。全観点について「触れた／触れない理由がある」状態にし、Risks / Rejected alternatives / Open Questions を必ず記載する。テンプレートは `templates.md` 参照。

### 1-4 External Review

`requirements.md` と `design.md` がそろったら、`codex` / `gemini` / `claude (subagent)` の **3 並列で自動起動**。詳細手順・プロンプト・反映ルールは `external-review.md` 参照。

**反映ルール（要旨）:**
- 挙動・データモデル不変の指摘 → **自動反映**（用語統一、Open Questions 追記、構造整理など）
- 挙動・API・スキーマ・移行戦略の変更を伴う指摘 → **ユーザー合意の上で反映**
- 不採用 → `/tmp/sdd-reviews/{name}/decisions.md` に理由記録
- 判断が微妙なら確認側に倒す

完了後 `/tmp/sdd-reviews/{name}/done` を作成（**有効期限 mtime + 7 日**、超過時は次回起動で自動再レビュー）。

### Phase 1 完了時のメッセージ

```
✅ Phase 1 (Plan) が完了しました。

📁 出力:
  - docs/specs/{name}/requirements.md
  - docs/specs/{name}/design.md
  - /tmp/sdd-reviews/{name}/{codex,gemini,claude}.md

🔎 外部レビュー: 自動反映 A / 合意反映 B / 不採用 C（decisions.md 参照）
📋 要件: US X件 / AC Y件 / Must Z件

▶️ Phase 2 (Tasks) に進みますか？
   `/my-sdd docs/specs/{name}` で後から再開できます。
```

**スペックパス（`docs/specs/{name}`）を必ず含める。**

---

## Phase 2: Tasks

### 前提

`docs/specs/{name}/{requirements.md, design.md}` が存在すること。

### 分解原則

1. **テストファースト**: テストタスクを実装タスクの前に配置
2. **小さく**: 1 タスク = 1 つの明確な成果物
3. **独立性**: 他タスクへの依存を減らす
4. **並列化**: 独立タスクには `[P]` マーク
5. **ファイルパス必須**: 各タスクに対象ファイルを明記

良い粒度: 「UserRepository の create メソッドを実装」 / 悪い粒度: 「ユーザー機能を実装」。

### 出力

`tasks.md` を作成。テンプレートは `templates.md` 参照。

### Phase 2 完了時のメッセージ

```
✅ Phase 2 (Tasks) が完了しました。

📁 出力: docs/specs/{name}/tasks.md
📋 タスク: 総 X / テスト Y / 実装 Z / 並列可 W

▶️ Phase 3 (Impl) に進みますか？
   `/my-sdd docs/specs/{name}` で後から再開できます。
```

---

## Phase 3: Impl

### 前提

`docs/specs/{name}/{requirements.md, design.md, tasks.md}` が存在すること。

### 3-0 Worktree gate

保護ブランチ（`main` / `master` / `staging` / `develop` / `release/*` / `hotfix/*`）から実装しない。検出時は `feat-{feature-name}` で worktree を作成し、`docs/specs/{name}/` を移送してから Phase 3-1 へ進む。判定・移送スクリプトの詳細は `worktree-gate.md` 参照。

スキップ条件: フィーチャブランチ上 / worktree 内 / `--no-worktree` / `MY_SDD_WORKTREE=0`。

### 3-1 タスクの読み込み

`tasks.md` を読み込み、未完了タスクと依存関係を確認、TodoWrite に登録。

### 3-2 タスク実行

- **依存尊重**: 依存タスク完了後に実行
- **テストファースト**: テストタスクを先に
- **`[P]` マークは Task エージェントで並列実行**（独立な実装タスクのみ。依存ありは順次）
- **進捗更新**: 各タスク完了時に TodoWrite と `tasks.md` を更新

並列起動するときは1メッセージ内に複数 Task ツール呼び出しを並べる。サブエージェントには対象ファイル / 受入基準 / 詳細 / 参考既存実装 / 既存規約遵守を渡す。

### 3-3 テスト実行

各実装タスク完了後、関連テストを実行。失敗時はエラー内容を確認 → 実装を修正 → 再実行。プロジェクトのテストコマンドを使う（例: `pytest tests/test_{module}.py -v`）。

### 3-4 tasks.md 更新

完了タスクを `[x] 完了 ✅` に更新。

### Phase 3 完了時のメッセージ

```
✅ Phase 3 (Impl) が完了しました。

📋 タスク: X/Y 完了（テスト A/B / 実装 C/D）
🧪 テスト: 実行 Z / 成功 Z / 失敗 0

📁 変更ファイル: ...

👉 次のステップ:
  - `/pull-request` で PR 作成
  - マージ後は `gwc` で worktree を削除
  - `/my-sdd {new-feature}` で次の機能を計画
```

---

## 完了報告

全タスクが完了している場合に表示:

```
🎉 すべてのタスクが完了しています。

📁 spec: docs/specs/{name}/
📋 タスク完了状況: X/X 件 (100%)

👉 次のステップ:
  - `/pull-request` で PR 作成
  - マージ後は `gwc` で worktree を削除
  - `/my-sdd {new-feature}` で次の機能を計画
```

---

## 共通ルール

1. **フェーズ間遷移はユーザー承認**: Phase 1→2、2→3 で自動遷移しない
2. **日本語で記述**: 仕様書・タスクは日本語
3. **事前調査を先に**: Phase 1-0 で既存コード・ADR・関連 PR を時間をかけて調査し、自明な決定は聞かない
4. **シニア/スタッフ視点で潰し切る**: Phase 1-3 で `senior-review-checklist.md` の全観点を網羅し、Risks / Rejected alternatives / Open Questions を必ず記載
5. **外部レビューを必ず通す**: Phase 1-4 で 3 者並列・自動。挙動/DB 変更を伴う指摘のみユーザー合意、それ以外は自動反映。判断が微妙なら確認側に倒す
6. **テストファースト**: Phase 2 で配置、Phase 3 で先に実行
7. **tasks.md はファイル出力**: TodoWrite だけでなく必ず `tasks.md` を作成・更新
8. **保護ブランチで実装しない**: Phase 3-0 で worktree に切り替え（`--no-worktree` で明示スキップ可）
9. **スペックパスを常に明示**: 完了メッセージ・次のステップで `docs/specs/{name}` を必ず含める
10. **フェーズ表示**: 現在のフェーズ（1-0 / 1-1 / ... / 3-4）を常に明示
11. **失敗時は停止**: テスト失敗時は修正してから次へ、不明なエラーはユーザーに報告
