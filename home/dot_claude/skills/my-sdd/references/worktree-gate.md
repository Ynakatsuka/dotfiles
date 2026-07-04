# Phase 3-0: Worktree Gate

Phase 3 開始時、保護ブランチ（`main` / `master` / `staging` / `develop` / `production` / `release/*`）上にいる場合は worktree を作成して移動してから Phase 3-1 へ進む。パス命名・ベース判定は zsh の `gw` 関数の規約に揃えるが、`gw` には依存せず Bash ツールから git コマンドを直接実行する。

## スキップ条件

以下のいずれかなら作成せず Phase 3-1 へ:

- 既にフィーチャブランチ（保護パターン外）
- 既に worktree 内（`git worktree list --porcelain` 先頭の main repo root と現在の `git rev-parse --show-toplevel` が異なる）
- 引数に `--no-worktree`
- 環境変数 `MY_SDD_WORKTREE=0`

## 判定

```bash
main_root=$(git worktree list --porcelain | awk 'NR == 1 { sub(/^worktree /, ""); print }')
current_root=$(git rev-parse --show-toplevel)
current_branch=$(git branch --show-current)

case "$current_branch" in
  main|master|staging|develop|production|release/*) protected=true ;;
  *) protected=false ;;
esac

# ベースブランチと base ref の解決。候補は優先順に
# origin/staging → origin/main → origin/master のみ。
if git show-ref --verify --quiet refs/remotes/origin/staging; then
  base_branch=staging; base_ref=origin/staging
elif git show-ref --verify --quiet refs/remotes/origin/main; then
  base_branch=main; base_ref=origin/main
elif git show-ref --verify --quiet refs/remotes/origin/master; then
  base_branch=master; base_ref=origin/master
else
  base_branch=""; base_ref=""
fi
```

候補がどれも存在しない（`base_ref` が空の）場合は、推測やローカル ref への代替をせず**停止してユーザーにベースブランチを確認する**。回答が得られるまで worktree 作成へ進まない。

## ユーザー提示

保護ブランチ検出時、一度だけ提示して確定:

```
⚠️ 現在 {current_branch} ブランチにいます。実装は worktree で行います。

  作成先:    {main_root}-worktree/feat-{feature-name}
  ブランチ:  feat-{feature-name} ({base_branch} ベース)
  spec 移送: docs/specs/{feature-name}/ を新 worktree に移送
            （{base_branch} 上に該当 spec のコミットがあれば cherry-pick + 巻き戻し）

進めますか？ [Y/n/別名指定]
```

`n` を選んだ場合は同セッション内で再確認しない。別名指定があればブランチ名・worktree パスをそれに合わせる（`/` は `-` に置換）。

## spec ファイルの移送

`docs/specs/{feature-name}/` の状態に応じて 3 通り。

### 1. 未コミットのみ（保護ブランチに該当 spec の local-only コミットなし）

```bash
[ "${base_ref}" = "origin/${base_branch}" ] && git fetch origin "${base_branch}"
git worktree add -b feat-{feature-name} \
  "{main_root}-worktree/feat-{feature-name}" "${base_ref}"
cp -R "{main_root}/docs/specs/{feature-name}" "{worktree}/docs/specs/"
```

元の保護ブランチに残った未コミット変更（`docs/specs/{feature-name}/` 配下）は **自動で破棄しない**。`git status -- docs/specs/{feature-name}/` の出力と「失われる変更の有無」を提示し、以下の選択肢で明示承認を待つ:

- (a) `git -C {main_root} checkout -- docs/specs/{feature-name}/` で追跡済み変更を破棄
- (b) `git -C {main_root} clean -fd docs/specs/{feature-name}/` で追跡外も削除（移送先にコピー済みである旨を明示）
- (c) 保護ブランチに残したまま続行（次回切替時に再度確認される）

### 2. 保護ブランチに spec 関連の local-only コミットあり

該当範囲の全コミットが `docs/specs/{feature-name}/` のみに閉じているか判定:

```bash
bad=$(git log --format=%H "${base_ref}..HEAD" -- ':!docs/specs/{feature-name}')
```

**`bad` が空（spec 専用コミットのみ）**: 移送と保護ブランチ巻き戻しは **2 段階の承認**に分ける。

段階 1（worktree 作成と cherry-pick）:

```bash
[ "${base_ref}" = "origin/${base_branch}" ] && git fetch origin "${base_branch}"
git worktree add -b feat-{feature-name} \
  "{main_root}-worktree/feat-{feature-name}" "${base_ref}"
git -C "{worktree}" cherry-pick "${base_ref}..{current_branch}"
```

段階 2（保護ブランチの巻き戻し）は破壊的操作のため、実行前に必ず以下を表示してユーザー承認を得る:

1. `git -C {main_root} log --oneline ${base_ref}..HEAD` の出力
2. 実行コマンド（`git -C "{main_root}" reset --keep "${base_ref}"`）
3. 巻き戻しによって失われる commit 一覧と未コミット差分の有無

承認が得られない場合は段階 2 をスキップし、保護ブランチをそのままにする（cherry-pick 済みの worktree 側で実装は継続可）。`--keep` で未コミットの作業ツリー変更は保持される。未コミットの spec 変更が残っていれば 1 と同様に `cp -R` で追加移送。

**`bad` が非空（spec 以外のコミットも混在）**: 自動巻き戻しは行わない。`git log --oneline ${base_ref}..HEAD` を提示し、以下から指示を待つ:

- (a) 手動で別ブランチに切り出してから再実行
- (b) `--no-worktree` で保護ブランチのまま続行
- (c) 中断

### 3. 混在（コミット + 未コミット）

2 を実行後に未コミット差分を `cp -R` で追加移送。

## `.env` / `.envrc` 追従

`{main_root}/.env` `{main_root}/.envrc` が存在し、新 worktree 側に同名ファイルがなければコピー。`direnv` がインストールされていれば新 worktree で `direnv allow` を実行（既存 `gw` 関数の挙動を踏襲）。

## 切替後

worktree 作成後は **以降の Bash 呼び出しの cwd を新 worktree に固定**。Read / Edit など全ての操作も新 worktree のパスで行う。完了したら以下を表示してから Phase 3-1 へ:

```
✅ worktree に移動しました
  📁 {main_root}-worktree/feat-{feature-name}
  🌿 feat-{feature-name} ({base_branch} ベース)
```

PR マージ後の cleanup は zsh の `gwc` 関数で行う（skill 側ではフォローしない）。
