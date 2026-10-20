# Chrome playbook

Use the Chrome plugin through `node_repl` to control the user's own Chrome, following the plugin's skill and docs. Do not switch to Computer Use, the in-app browser, or another browser.

- Open a new tab for the task and leave the user's existing tabs alone unless the task names one.
- The user's Chrome sessions are signed in. If a site asks for a login, passkey, or two-factor code, stop and report the site and the step.
- Attach files through the file chooser flow in the plugin's file upload doc, with absolute paths.
- Sending a message, posting, submitting a form, deleting, and similar actions need a confirmation right before the action even when the task approves them. Prepare everything, stop just before that action, and report it as a confirmation request.
- Close the tabs you opened when the task is done, unless the task asks to keep them.
