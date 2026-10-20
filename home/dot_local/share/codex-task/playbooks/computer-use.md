# Computer Use playbook

Use the Computer Use plugin through `node_repl`, following its `computer-use` skill.

- Bootstrap once per `node_repl` session: `globalThis.sky = (await import("@oai/sky")).sky;`
- Start with `sky.get_app_state({ app })`, which also launches the app. Pass the display name or bundle ID, for example Slack `com.tinyspeck.slackmacgap`, Chrome `com.google.Chrome`, Finder `com.apple.finder`, or Notes `com.apple.Notes`. Call `sky.list_apps()` only when the name does not resolve.
- After every action, read the app state again and use fresh `element_index` values. Prefer the accessibility text; read the screenshot when the text is incomplete.
- Enter multiline text with `sky.paste({ app, text, format: "text" })`. `type_text` turns newlines into Return, which sends messages in chat apps.
- If macOS denies Accessibility or Screen Recording access, stop and report which permission to grant in System Settings > Privacy & Security.
- Sending a message, posting, deleting, and similar actions need a confirmation right before the action even when the task approves them. Prepare everything, stop just before that action, and report it as a confirmation request.
- Uploading a file is approved when the task names the file and the destination.
