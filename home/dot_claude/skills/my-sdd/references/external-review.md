# Codex Review (Phase 1-4)

`requirements.md` と `design.md` がそろったあと、`codex` で red-team review を依頼する。

## 出力先と TTL

一時成果物（プロンプト・生レビュー・完了マーカー）は `/tmp`、採否の記録は spec と同じ場所に永続化する。

```
/tmp/sdd-reviews/{feature-name}/
├── _prompt.txt    # 共通プロンプト（再実行用）
├── codex.md       # codex 生レビュー
└── done           # 完了マーカー（mtime が TTL の基準）

docs/specs/{feature-name}/
└── decisions.md   # 採否の記録（requirements/design/tasks と並ぶ永続ファイル・コミット対象）
```

- `/tmp` 配下は一時成果物のみ。コミットされず、永続性は OS 依存（macOS は 3 日経過で消去、Linux は再起動で消失）
- `decisions.md` は後から参照する記録のため `/tmp` に置かない。必ず `docs/specs/{feature-name}/decisions.md` に書く
- `done` の **mtime + 7 日** が有効期限。期限切れ・OS 都合で消えた場合は次回 `/my-sdd` 起動時に自動再レビュー
- TTL を変えたい場合は判定の `-mtime -7` を `-mtime -14` 等に変更

判定スクリプト:

```bash
DONE=/tmp/sdd-reviews/{feature-name}/done
if [ -f "$DONE" ] && [ -n "$(find "$DONE" -mtime -7 -print 2>/dev/null)" ]; then
  echo "valid"   # Phase 2 へ進める
else
  echo "expired" # 再レビュー
fi
```

## 起動前の準備

```bash
mkdir -p /tmp/sdd-reviews/{feature-name}
```

## 共通プロンプト

長いので一度ファイルに書き出して再利用する:

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

## 起動

Bash は `timeout: 600000`（10 分）必須。

```bash
codex exec "$(cat /tmp/sdd-reviews/{feature-name}/_prompt.txt)" \
  > /tmp/sdd-reviews/{feature-name}/codex.md 2>&1
```

モデルは `~/.codex/config.toml` のデフォルト（`--model` 指定しない）。

## 統合（メインが行う）

`codex.md` が生成されたら main の Claude が:

1. `Read` で `codex.md` を読み込む
2. 指摘内容を整理
3. 各指摘を **重要度（CRITICAL / IMPORTANT / SUGGESTION）** と **挙動・DB 変更の有無** で分類
4. ユーザーに統合サマリーを提示

**spec の編集は生レビューを別ファイルに保存してから行う**（書き換えながら読むと「何が指摘で何が反映済か」が分からなくなる）。

## 反映ルール

| 種別 | 例 | 取り扱い |
|---|---|---|
| 挙動・データモデル不変 | typo 修正、用語統一、Open Questions 追記、Risks 補完、Rejected alternatives 追記、構造整理 | **自動で `requirements.md` / `design.md` を更新**し、`decisions.md` に記録 |
| 挙動・API・スキーマ・移行戦略の変更 | エンドポイント変更、テーブル設計変更、認証フロー変更、互換性方針の変更 | 変更内容と理由を**ユーザーに提示し合意を得てから反映**。判断を `decisions.md` に記録 |
| 採用しない | コスト・スコープ・方針が合わない | `decisions.md` に「不採用 + 理由」を記録 |

判別が微妙な場合は確認側に倒す。

### decisions.md フォーマット

`docs/specs/{feature-name}/decisions.md` に書く。

```markdown
# Phase 1-4 Review Decisions

## Auto-applied (no behavior/DB change)
- [codex] <短い指摘> — applied to design.md §<セクション>

## User-confirmed (behavior/DB change)
- [codex] <短い指摘> — user agreed; applied with modification: <差分要旨>

## Rejected
- [codex] <短い指摘> — 理由: <不採用の根拠>
```

## 完了マーカー

反映が一通り終わったら空ファイルを作成:

```bash
touch /tmp/sdd-reviews/{feature-name}/done
```

レビューは Phase 1-3 完了直後に**一度だけ**自動実行。再実行が必要なら `done` を削除する、または TTL（mtime + 7 日）切れを待つだけで次回起動時に自動再レビュー。

## エラー時の対応

Codex review が失敗した場合は Phase 1-4 を **Blocked** とし `done` を作成しない。共通ルール「Codex review を必ず通す」と整合させるため、Phase 2 への進行はユーザーが明示 override（「レビューなしで進める」と発話）した場合のみ許可し、判断を `docs/specs/{feature-name}/decisions.md` の `User-confirmed` に「Phase 1-4 skipped per user request on YYYY-MM-DD」として記録する。

| 失敗 | 対応 |
|---|---|
| Codex review 失敗 | **Blocked**。原因（quota / network 等）と再実行手段をユーザーに報告。override しない限り Phase 2 へ進まない |
