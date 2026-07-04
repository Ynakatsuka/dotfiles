# CCV App Preview Workflow

CCV アプリ本体の変更を、専用 preview service でブラウザ確認する。
`my-ccv` で「preview」「プレビュー」と言われた場合の第一候補はこの workflow。

## Source of truth

- CCV リポジトリ内で作業していて `.claude/skills/ccv-preview/SKILL.md` が存在する場合は、実行前にそのファイルを読む
- この reference は `Ynakatsuka/claude-code-viewer` の `ccv-preview` workflow を `my-ccv` 用に要約したもの
- repo-local workflow とこの reference が矛盾する場合は、repo-local workflow を優先し、差分をユーザーに報告する

## Service Contract

- Service: set locally as `CCV_PREVIEW_SERVICE`
- Local origin: set locally as `CCV_PREVIEW_LOCAL_ORIGIN`
- Public URL: set locally as `CCV_PREVIEW_PUBLIC_URL`
- Listen check pattern: set locally as `CCV_PREVIEW_LISTEN_PATTERN`
- Environment override directory: set locally as `CCV_PREVIEW_ENV_DIR`
- Environment override file: set locally as `CCV_PREVIEW_ENV_FILE`
- Required workdir override: `CCV_PREVIEW_WORKDIR=/absolute/path/to/worktree`
- Preferred workdir: in-progress changes 用の dedicated git worktree
- Runtime home: service-local runtime home, configured outside this public repository

preview service は production と別 HOME を使う。ただし実セッションを表示するため、shared agent runtime data を参照する場合がある。
preview は agent data に対して read-only ではない。preview UI から session の開始、再開、中断、編集を行うと、shared agent runtime data に書き込む可能性がある。

## Local-only Configuration

公開 repository には実 URL、local port、service 名、runtime path を hard-code しない。
実行前に、private config、shell environment、またはユーザー入力から以下を明示的に設定する。
値が未設定の場合は停止して確認する。別 URL や別 service へ推測で fallback しない。

```bash
: "${CCV_PREVIEW_SERVICE:?Set CCV_PREVIEW_SERVICE locally}"
: "${CCV_PREVIEW_PUBLIC_URL:?Set CCV_PREVIEW_PUBLIC_URL locally}"
: "${CCV_PREVIEW_LOCAL_ORIGIN:?Set CCV_PREVIEW_LOCAL_ORIGIN locally}"
: "${CCV_PREVIEW_LISTEN_PATTERN:?Set CCV_PREVIEW_LISTEN_PATTERN locally}"
: "${CCV_PREVIEW_ENV_DIR:?Set CCV_PREVIEW_ENV_DIR locally}"
: "${CCV_PREVIEW_ENV_FILE:?Set CCV_PREVIEW_ENV_FILE locally}"
```

## Critical Safety Rules

- `pnpm dev` と `pnpm start` は実行しない
- production CCV service と Cloudflare tunnel service は再起動しない
- Cloudflare Tunnel、DNS、Access settings は変更しない
- `cloudflared tunnel --url`、ngrok、localtunnel などの ad-hoc tunnel は使わない
- `systemctl --user start|restart|stop "$CCV_PREVIEW_SERVICE"` の前に、現在のユーザー依頼で明示されていない限り承認を取る
- `CCV_PREVIEW_WORKDIR` を必須にする。main repository を暗黙の fallback として serve しない
- dedicated worktree を優先する。main repository の `dist/` を rebuild すると production service と競合する可能性がある

## Workflow

### 1. Select the preview workdir

ユーザーが worktree path を渡した場合は存在確認する。

```bash
ls -la "$WORKTREE_PATH"
```

worktree path がない場合は、preview 用の dedicated worktree を先に決める。
判断できない場合はユーザーに確認する。main repository への暗黙 fallback はしない。

env file に absolute path を設定する。
既存ファイルに他の intentional override がある場合は保持し、`CCV_PREVIEW_WORKDIR` だけ更新する。

```bash
mkdir -p "$CCV_PREVIEW_ENV_DIR"
cat > "$CCV_PREVIEW_ENV_FILE" <<EOF
CCV_PREVIEW_WORKDIR=/absolute/path/to/preview/worktree
EOF
```

既存 env file に他の intentional override がある場合は、上記の単純な overwrite を使わず、`CCV_PREVIEW_WORKDIR` の行だけを更新する。

### 2. Build the selected workdir

preview workdir で production build を実行する。

```bash
pnpm build
```

build が失敗したら停止して報告する。古い `dist/`、別 worktree、production repository へ fallback しない。

### 3. Verify Cloudflare Access before restart

restart 前に、unauthenticated public request が Cloudflare Access に転送されることを確認する。

```bash
curl -I --max-time 20 "$CCV_PREVIEW_PUBLIC_URL"
```

期待値:

- `HTTP/2 302`
- `location:` に Cloudflare Access login host が含まれる
- `www-authenticate:` に `Cloudflare-Access` が含まれる

public URL が未認証で CCV HTML を返した場合は blocking security issue として停止する。

### 4. Start or restart the preview service

承認後、preview service だけを restart する。

```bash
systemctl --user restart "$CCV_PREVIEW_SERVICE"
```

production service は restart しない。

### 5. Verify local origin

```bash
systemctl --user status "$CCV_PREVIEW_SERVICE" --no-pager --lines=20
curl -i --max-time 15 -H 'Accept: text/html' "$CCV_PREVIEW_LOCAL_ORIGIN" | head
ss -ltnp | grep "$CCV_PREVIEW_LISTEN_PATTERN"
```

期待値:

- service が `active (running)`
- local HTML が `200 OK`
- `CCV_PREVIEW_LISTEN_PATTERN` に一致する local listener が存在する

startup 直後の一時的な listen 待ちだけは、短い bounded interval で一度だけ再確認する。
それでも失敗する場合は logs を読んで報告する。

### 6. Verify Cloudflare Access after restart

restart 後も unauthenticated public request が Cloudflare Access に転送されることを確認する。

```bash
curl -I --max-time 20 "$CCV_PREVIEW_PUBLIC_URL"
```

期待値は Step 3 と同じ。
未認証で CCV HTML を返した場合は blocking security issue として停止する。

### 7. Report

ユーザーに以下を報告する。

- Preview URL
- Preview workdir
- serving 中の branch / commit
- build result
- local origin result
- Cloudflare Access result
- visual QA に影響する warning

## Troubleshooting

### preview が production と同じに見える

```bash
systemctl --user cat "$CCV_PREVIEW_SERVICE"
cat "$CCV_PREVIEW_ENV_FILE"
```

`CCV_PREVIEW_WORKDIR` がない、または main repository を指している場合は成功扱いにしない。
実装 worktree を指定し、build し、承認後に preview service を restart する。

### public URL が 502 を返す

local origin と service logs を確認する。

```bash
systemctl --user status "$CCV_PREVIEW_SERVICE" --no-pager --lines=40
curl -i --max-time 15 -H 'Accept: text/html' "$CCV_PREVIEW_LOCAL_ORIGIN" | head
journalctl --user -u "$CCV_PREVIEW_SERVICE" -n 80 --no-pager
```

### public URL が Access を bypass する

停止して報告する。Cloudflare Access / Tunnel configuration の修正が必要。
app-level workaround や ad-hoc tunnel で補わない。
