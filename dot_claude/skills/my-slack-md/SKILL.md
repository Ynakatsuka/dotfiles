---
name: my-slack-md
description: >-
  Convert Markdown to Slack mrkdwn format and post to Slack.
  Use when sending Markdown content to Slack, converting reports for Slack,
  or when user asks "Slackに送って", "Slack投稿", "mrkdwn変換", "Slack format".
  Do NOT use for general Markdown editing or non-Slack messaging.
argument-hint: "[FILE_PATH] [#channel]"
---

# Slack Markdown — MD to Slack mrkdwn Converter

Markdown ファイルを Slack mrkdwn 形式に変換し、Slack チャンネルに投稿する。

## Arguments

`$ARGUMENTS` をパースする:

| 引数 | 意味 | デフォルト |
|---|---|---|
| `$0` | 変換元の Markdown ファイルパス | 必須 |
| `$1` | 投稿先 Slack チャンネル（`#` 付き可） | 省略時は変換のみ（投稿しない） |

引数が空の場合はユーザーにファイルパスを確認する。

## Step 1: Convert

変換スクリプトのパスを特定して実行する:

```bash
SCRIPT="$HOME/.claude/skills/my-slack-md/scripts/md2slack.py"
python3 "$SCRIPT" INPUT_FILE /tmp/slack-output.txt
```

変換結果を表示してユーザーに確認を求める（長い場合は先頭と末尾を抜粋）。

## Step 2: Post to Slack (optional)

チャンネルが指定された場合のみ実行する。

### 2a: Get Slack token

プロジェクトの `.env` から読み取る:

```bash
SLACK_TOKEN=$(grep SLACK_TOKEN .env | cut -d= -f2)
```

`.env` が見つからない場合はユーザーに確認する。

### 2b: Post

Slack メッセージの `text` フィールドの上限は 40,000 文字。超える場合は分割する。

```bash
CONTENT=$(cat /tmp/slack-output.txt)
CHANNEL="daily_report"  # #を除去した名前

curl -s -X POST https://slack.com/api/chat.postMessage \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg channel "$CHANNEL" --arg text "$CONTENT" \
    '{channel: $channel, text: $text}')"
```

レスポンスの `ok` フィールドを確認し、結果を報告する。

## Conversion Rules Reference

| Markdown | Slack mrkdwn |
|----------|-------------|
| `## Heading` | `*Heading*` |
| `**bold**` | `*bold*` |
| `*italic*` | `_italic_` |
| `~~strike~~` | `~strike~` |
| `[text](url)` | `<url\|text>` |
| `- item` | `• item` |
| `---` | `────────────────` |
| `` `code` `` | `` `code` `` (unchanged) |
| ` ```block``` ` | ` ```block``` ` (unchanged) |
| `> quote` | `> quote` (unchanged) |

## For CCV Scheduled Jobs

スケジュールジョブのプロンプトで使う場合の推奨パターン:

```
# Slack投稿部分のプロンプト例
レポートファイルを Slack に投稿する前に、
~/.claude/skills/my-slack-md/scripts/md2slack.py で mrkdwn 形式に変換してください。

python3 ~/.claude/skills/my-slack-md/scripts/md2slack.py REPORT.md /tmp/slack-msg.txt
CONTENT=$(cat /tmp/slack-msg.txt)
# then post $CONTENT to Slack
```
