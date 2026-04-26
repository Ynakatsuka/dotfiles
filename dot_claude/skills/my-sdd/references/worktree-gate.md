# Phase 3-0: Worktree Gate

Phase 3 開始時、保護ブランチ（`main` / `master` / `staging` / `develop` / `release/*` / `hotfix/*`）上にいる場合は worktree を作成して移動してから Phase 3-1 へ進む。パス命名・ベース判定は zsh の `gw` 関数の規約に揃えるが、`gw` には依存せず Bash ツールから git コマンドを直接実行する。

## スキップ条件

以下のいずれかなら作成せず Phase 3-1 へ:

- 既にフィーチャブランチ（保護パターン外）
- 既に worktree 内（`git worktree list --porcelain` 先頭の main repo root と現在の `git rev-parse --show-toplevel` が異なる）
- 引数に `--no-worktree`
- 環境変数 `MY_SDD_WORKTREE=0`

## 判定

```bash
main_root=$(git worktree list --porcelain | head -1 | sed 's/^worktree //')
current_root=$(git rev-parse --show-toplevel)
current_branch=$(git branch --show-current)

case "$current_branch" in
  main|master|staging|develop|release/*|hotfix/*) protected=true ;;
  *) protected=false ;;
esac

# ベースブランチ（staging > main）
if git show-ref --verify --quiet refs/heads/staging \
   || git show-ref --verify --quiet refs/remotes/origin/staging; then
  base_branch=staging
else
  base_branch=main
fi
```

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

`docs/specs/{feature-name}/` の状態に応じて 3 通り:

### 1. 未コミットのみ（保護ブランチに該当 spec の local-only コミットなし）

```bash
git fetch origin {base_branch}
git worktree add -b feat-{feature-name} \
  "{main_root}-worktree/feat-{feature-name}" "origin/{base_branch}"
cp -R "{main_root}/docs/specs/{feature-name}" "{worktree}/docs/specs/"
```

元の保護ブランチに残った未コミット変更は `git -C {main_root} checkout -- docs/specs/{feature-name}/` および追跡外があれば `git -C {main_root} clean -fd docs/specs/{feature-name}/` で破棄するか、ユーザーに確認する。

### 2. 保護ブランチに spec 関連の local-only コミットあり

該当範囲の全コミットが `docs/specs/{feature-name}/` のみに閉じているか判定:

```bash
bad=$(git log --format=%H "origin/{base_branch}..HEAD" -- ':!docs/specs/{feature-name}')
```

**`bad` が空（spec 専用コミットのみ）**: 自動で移送して保護ブランチを巻き戻す。

```bash
git fetch origin {base_branch}
git worktree add -b feat-{feature-name} \
  "{main_root}-worktree/feat-{feature-name}" "origin/{base_branch}"
git -C "{worktree}" cherry-pick "origin/{base_branch}..{current_branch}"
git -C "{main_root}" reset --keep "origin/{base_branch}"
```

`--keep` を使うことで未コミットの作業ツリー変更は保持される。未コミットの spec 変更が残っていれば 1 と同様に `cp -R` で追加移送。

**`bad` が非空（spec 以外のコミットも混在）**: 自動巻き戻しは行わない。`git log --oneline origin/{base_branch}..HEAD` を提示し、以下の選択肢を提示してユーザー指示を待つ:

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
