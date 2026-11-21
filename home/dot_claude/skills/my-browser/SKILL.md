---
name: my-browser
description: >-
  Choose and drive the browser for a web task: the user's Chrome with their sign-ins on the local
  machine, or a token-efficient headless CLI (agent-browser, Playwright CLI as fallback); Claude
  hands the work to Codex. Use before any browser work: opening or operating a
  website, signing in, filling forms, scraping rendered pages, taking screenshots, or checking a
  web app in a browser, and when the user says "ブラウザで", "サイトを開いて", "ログインして",
  "スクショ", "browser", or "headless". Do NOT use for public read-only research that web search or
  a connector answers, or for desktop apps outside a browser.
compatibility: >-
  Local machine is macOS with Google Chrome; the server is Linux. Needs agent-browser and
  playwright-cli on PATH, and the 1Password CLI `op` for stored credentials.
---

# Browser Routing

## 0. Claude delegates browser work to Codex

When running as Claude, do not drive a browser yourself. Write the task to a file and run
`codex-task --prompt-file <file>`; Codex then follows this skill from section 1.

- Add `--use chrome` when the work needs the user's Chrome state (section 2).
- Give the exact URLs, steps, data to enter, approved actions, and absolute paths of files to
  attach or of where to save screenshots and extracted data.
- Run tasks that may exceed the Bash timeout in the background. Confirm the outcome from the tool
  calls it reports; when Codex asks for confirmation, ask the user and continue with the printed
  `--resume` command.
- Run a project's own Playwright test suite directly; it is a test command, not browser work.
- When `codex-task` fails, report the failure, then follow sections 1–4 yourself, using Claude in
  Chrome through the `chrome-browser` skill where section 2 names Codex's Chrome plugin. First
  check the tool calls it reported and the page itself, and continue only the steps not yet done;
  ask the user before repeating a send, post, or submit whose outcome is unknown.

## 1. Identify the environment

- **Local machine**: `uname -s` prints `Darwin`. The user sits at it and their Chrome holds their
  sign-ins.
- **Server**: Linux, with no user at the machine.

## 2. Choose the browser

Answer public read-only questions with web search or a connector, without a browser.

Local machine:

| Need | Browser |
|---|---|
| Default, and anything that needs the user's Chrome state: sign-ins, passkeys, password manager, extensions, open tabs, or the user watching | Codex's Chrome plugin |
| No user state is needed: scripted checks, rendered-page extraction, or a login whose credentials are in 1Password | Headless (section 3), with `op` for credentials (section 4) |

Server:

| Need | Browser |
|---|---|
| Default | Headless (section 3) |
| A step needs the user: sign-in without stored credentials, one-time codes, passkeys, CAPTCHA, payment or other confirmation | A browser tool of the session that hands steps to the user, used as its description says; without one, stop and report the site and the step |

Check, test, or screenshot an app under development in a fresh headless profile: the project's
own Playwright setup when it has one, otherwise section 3. Never use a browser that keeps the user's
logins for it.

When the chosen browser fails, report the failure and the browser you switch to; do not switch
silently.

## 3. Headless browsing

Use `agent-browser`. Before the first use in a session, read its version-matched guide with
`agent-browser skills get core` instead of guessing commands. Work from `snapshot -i` refs, give
parallel tasks their own `--session <name>`, and run `agent-browser close` when done.

Switch to `playwright-cli` when agent-browser cannot drive the page after one retry, for example
with nested iframes, shadow DOM, or custom widgets. `playwright-cli --help` prints the path of its
own agent guide; read it before the first use. It writes snapshots and screenshots to
`.playwright-cli/` in the working directory, so run it from a temporary directory rather than a
repository, and read only the part of a snapshot you need.

Pass persistent state only from files the task names, such as `--state <file>` or
`state-load <file>`. Treat those files as credentials: keep them outside repositories and never
print their contents.

## 4. Credentials with 1Password

- Never print, echo, or write a secret, and never ask the user to paste one into the chat.
- Pipe the secret into the browser's stdin, and log in only when both steps succeed, for example:

  ```bash
  set -o pipefail
  op read "op://<vault>/<item>/password" \
    | agent-browser auth save <name> --url <login-url> --username <user> --password-stdin \
    && agent-browser auth login <name>
  ```

  `auth save` keeps the password in agent-browser's encrypted vault; run
  `agent-browser auth delete <name>` after a one-off login.

- If `op` is not signed in or the item does not exist, stop and ask the user. Do not search
  vaults for a likely item.
- Route one-time codes and passkeys to the user as section 2 describes.
