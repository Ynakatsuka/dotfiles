# Slack playbook

Use the Slack app tools (`mcp__codex_apps__slack_slack_*`). If they are not loaded, search your tools for "slack" once. Do not use a browser, Computer Use, or direct Slack Web API calls except where this playbook says so.

## Target

- Use the channel ID and `thread_ts` from the task. Otherwise find the channel with `slack_search_channels`, or a DM with `slack_list_user_conversations`, and the thread with `slack_read_channel` or `slack_read_thread`. If more than one candidate matches, stop and report the candidates.
- Mention people as `<@USER_ID>`; find IDs with `slack_search_users`.

## Draft or send

- Draft unless the task says to send. A draft stays unsent until the user sends it.
- Draft: `slack_send_message_draft(channel_id, message, thread_ts?)`. If a draft already exists for that channel or thread, stop and report; do not delete or overwrite the user's draft. Drafts have dropped blank lines between paragraphs before, so check the returned text when spacing matters.
- Send: `slack_send_message(channel_id, message, thread_ts?)`. Scheduled send: `slack_schedule_message(channel_id, message, post_at, thread_ts?)`, where `post_at` is Unix seconds.
- Report the channel, `thread_ts`, and the draft ID, message `ts`, or link from the result.

## Images and other files

The draft tool cannot attach files. Uploading a file and sharing it in a channel posts a message immediately, so do it only when the task says to send.

1. Get the byte size: `wc -c < <file> | tr -d ' '`.
2. Call `slack_get_file_upload_url(filename, content_length, alt_txt?)`.
3. Upload the bytes with `curl -sS -F file=@<file> '<upload URL>'` and check that it succeeds. Do not print the upload URL in the report.
4. Call `slack_complete_file_upload(file_id, channel_id, thread_ts?, initial_comment?, title?)`. Put the message text in `initial_comment`, so text and image arrive as one post.
5. Upload several files the same way, one `slack_complete_file_upload` per file, and report each file ID.

When the task wants an unsent draft that includes a file, use Slack in Chrome with the Chrome plugin: open the channel or thread at `https://app.slack.com/client/<team ID>/<channel ID>`, attach the file through the file chooser flow, paste the text, and stop before sending. Report whether the composer kept the attachment.
