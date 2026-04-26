# External Review (Phase 1-4)

`requirements.md` と `design.md` がそろったあとに、`codex` / `gemini` / `claude (subagent)` の 3 者で並列にシニア/スタッフエンジニア視点の red-team レビューを依頼する。

## 出力先

```
/tmp/sdd-reviews/{feature-name}/
├── _prompt.txt    # レビュー共通プロンプト（再実行用）
├── codex.md       # codex の生レビュー
├── gemini.md      # gemini の生レビュー
├── claude.md      # claude subagent の生レビュー
├── decisions.md   # 採否の記録（採用 / 不採用 + 理由）
└── done           # Phase 1-4 完了マーカー（空ファイル、mtime が有効期限の基準）
```

OS の `/tmp` 配下に作る。リポジトリ外なのでコミットされない。永続性は OS の挙動依存（macOS は `periodic` で 3 日経過のものが消える、Linux は再起動で消えることが多い）。

### 有効期限 (TTL)

`done` の **mtime + 7 日** が有効期限。期限切れ・OS 都合で消えた場合は次回 `/my-sdd` 起動時に自動再レビュー。

判定スクリプト:

```bash
DONE=/tmp/sdd-reviews/{feature-name}/done
if [ -f "$DONE" ] && [ -n "$(find "$DONE" -mtime -7 -print 2>/dev/null)" ]; then
  echo "valid"   # 有効な review あり → Phase 2 へ進める
else
  echo "expired" # レビューやり直し
fi
```

TTL を変えたい場合（例: 14 日）は `-mtime -7` を `-mtime -14` に変更する。

## 起動前の準備

```bash
mkdir -p /tmp/sdd-reviews/{feature-name}
```

## 共通プロンプト

3 者に同じプロンプトを渡す。プロンプトは長いので、毎回ヒアドキュメントで組み立てるよりも一度ファイルに書き出して再利用する:

```bash
cat > /tmp/sdd-reviews/{feature-name}/_prompt.txt <<'EOF'
You are a Staff Software Engineer doing a red-team review of a design spec.

Read these files in full:
- docs/specs/{feature-name}/requirements.md
- docs/specs/{feature-name}/design.md

Review them ruthlessly from a senior/staff perspective. Focus on:

1. Failure modes, edge cases, race conditions, concurrency, idempotency
2. Non-functional requirements (latency p50/p95/p99, throughput, cost, SLO)
3. Security (authn, authz, PII, secrets, injection, least privilege)
4. Operations (rollout, rollback, feature flags, data migration, backfill)
5. Observability (metrics, logs, alerts, tracing, correlation IDs)
6. API / contract design and backward compatibility
7. Blast radius — who calls this, who consumes it, what breaks elsewhere
8. Hidden assumptions and unstated invariants
9. Rejected alternatives — was the chosen approach truly best? What other options exist?
10. What will hurt 1-3 years from now (10x scale, team change, similar features piling on)?

11. **Codebase coherence (project-specific)** — explore the repository before reviewing. Cite file paths.
    - Are there existing implementations that solve the same / similar use case? Should this reuse, extend, or merge with them?
    - Does the design follow existing naming, error handling, log/metric conventions, config layout, feature flag patterns, i18n keys?
    - Are existing helpers / shared modules being modified in a way that breaks other callers? List the callers.
    - Does this respect existing module boundaries (DDD, layers, package visibility, import direction)?
    - Are existing fixtures / factories / mocks / test patterns being reused, or is a parallel test style being introduced?
    - Are deprecated / legacy implementations being left around, or is there a clear removal plan?
    - Does this conflict with in-flight migrations or contradict prior ADRs / postmortems?
    - Are public types / DB schemas / shared libraries being changed in ways that ripple to other modules?
    - Is there copy-paste that will fragment future bug fixes? Or premature abstraction that locks out exceptions?

For each finding, output in this format:

## [CRITICAL | IMPORTANT | SUGGESTION] <short title>
- **Where**: file:section (or file:line if applicable)
- **Why it matters**: <one or two sentences>
- **Suggested fix**: <concrete change to requirements.md / design.md>
- **Behavior or DB impact**: yes / no  (yes if accepting this changes runtime behavior, API contract, schema, or data model)

End with:
## Hidden assumptions to validate
- bullet list

Be specific. Cite exact lines. No fluff. No restating the spec. Only findings.
EOF
```

`{feature-name}` はその場で実値に置換する。

## 並列起動

メインの応答内で、**1 メッセージ内に Bash 2 件 + Agent 1 件**を同時発行する（並列実行）。

### 1. Codex

```bash
codex exec "$(cat /tmp/sdd-reviews/{feature-name}/_prompt.txt)" \
  > /tmp/sdd-reviews/{feature-name}/codex.md 2>&1
```

- Bash の `timeout: 600000` (10 分) を必ず設定する
- モデルは `~/.codex/config.toml` のデフォルトを使う（`--model` を指定しない）

### 2. Gemini

`my-gemini` の preflight を満たすこと（`GEMINI_FORCE_FILE_STORAGE=true` と `~/.gemini/gemini-credentials.json` の存在）。読み取り専用なので `--approval-mode plan` を使う:

```bash
gemini --approval-mode plan -p "$(cat /tmp/sdd-reviews/{feature-name}/_prompt.txt)" \
  > /tmp/sdd-reviews/{feature-name}/gemini.md 2>&1
```

- `timeout: 600000`
- preflight 失敗時は `my-gemini` のガイダンスに従い、本レビューでは gemini をスキップして残り 2 者で続行

### 3. Claude (subagent)

`Agent` ツールを使う。Write が必要なので `subagent_type: general-purpose`:

```
Agent({
  description: "Red-team review of spec (Phase 1-4)",
  subagent_type: "general-purpose",
  prompt: "<共通プロンプトの中身>\n\n結果を /tmp/sdd-reviews/{feature-name}/claude.md に書き出すこと。"
})
```

## 統合（メインが行う）

3 ファイルがそろったら（または失敗を確認したら）、メインの Claude が次を行う:

1. `Read` で 3 ファイルを読み込む
2. 共通指摘 / 個別指摘 / 矛盾を整理
3. 各指摘を **重要度（CRITICAL / IMPORTANT / SUGGESTION）** と **挙動・DB 変更の有無** で分類
4. ユーザーに統合サマリーを提示

## 反映ルール（重要）

| 種別 | 例 | 取り扱い |
|---|---|---|
| 挙動・データモデルが変わらない指摘 | typo 修正、用語統一、Open Questions 追記、Risks 列挙の補完、Rejected alternatives の追記、構造整理 | **自動で `requirements.md` / `design.md` を更新**し、`decisions.md` に記録 |
| 挙動・API 仕様・スキーマ・DB の持ち方・移行戦略が変わる指摘 | エンドポイント追加 / 変更、テーブル設計変更、認証フロー変更、互換性方針の変更 | 変更内容と理由を**ユーザーに提示し、合意を得てから反映**。判断を `decisions.md` に記録 |
| 採用しない指摘 | コスト / スコープ / 方針が合わない | `decisions.md` に「不採用 + 理由」を記録 |

判別が微妙な場合（「自動反映してよいか確信が持てない」）は、確認側に倒す。

## decisions.md のフォーマット

```markdown
# Phase 1-4 Review Decisions

## Auto-applied (no behavior/DB change)
- [codex] <短い指摘> — applied to design.md §<セクション>
- [gemini] ...

## User-confirmed (behavior/DB change)
- [claude] <短い指摘> — user agreed on YYYY-MM-DD; applied to design.md §<セクション>
- [codex] <短い指摘> — user agreed; applied with modification: <差分要旨>

## Rejected
- [gemini] <短い指摘> — 理由: <不採用の根拠>
```

## 完了マーカー

反映が一通り終わったら、空ファイル `/tmp/sdd-reviews/{feature-name}/done` を作成する:

```bash
touch /tmp/sdd-reviews/{feature-name}/done
```

このマーカーが Phase 1-4 完了の合図。**mtime + 7 日** を有効期限とし、期限内なら状態検出ロジックが Phase 2 へ進める。期限切れなら次回起動時に自動再レビューする。

## エラー時の対応

| 失敗 | 対応 |
|---|---|
| codex 失敗 | エラーをユーザーに通知し、残り 2 者で続行 |
| gemini 失敗（preflight 含む） | 同上。preflight は `my-gemini` のガイダンスに従う |
| claude (subagent) 失敗 | 同上 |
| 3 者すべて失敗 | レビュー結果なしを報告し、Phase 2 へ進めるかユーザーに判断を仰ぐ |

## 注意

- 反映による `requirements.md` / `design.md` の編集は、生レビューを別ファイルに保存してから行う。spec を直接書き換えながらレビューを読むと、後で「何が指摘で何が反映済か」が分からなくなる
- 同じ指摘が複数 reviewer から出ている場合は、`decisions.md` で `[codex,gemini]` のように出典をまとめる
- レビューは Phase 1-3 完了直後に **一度だけ** 自動実行する。再実行が必要なら `/tmp/sdd-reviews/{feature-name}/done` を削除する、または mtime + 7 日（TTL）を待つだけで次回起動時に自動再レビューされる
