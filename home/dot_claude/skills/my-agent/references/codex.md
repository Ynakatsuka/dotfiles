# Codex Reference

Usage for the `codex` provider in `my-agent` beyond `codex exec "<PROMPT>" </dev/null`.

## Invocation

Always use `exec`; the Codex TUI cannot be driven from here.

`codex exec` reads stdin whenever stdin is not a terminal and appends it to the prompt, so an agent shell whose stdin never closes hangs at `Reading additional input from stdin...`. Redirect stdin on every call: `</dev/null`, a pipe, or `-` with the prompt file on stdin. When logging to a file, use a new path or `>|`, because zsh `noclobber` refuses `>` over an existing file.

```bash
codex exec - <prompt.md                                   # long prompt from a file
git diff main... | codex exec "Review this diff."         # piped context replaces </dev/null
codex exec -i path/to/image.png "<PROMPT>" </dev/null     # image input
codex exec resume --last "<PROMPT>" </dev/null            # resume the previous session
codex exec --model <MODEL> "<PROMPT>" </dev/null          # only when the user names a model
```

## Configuration

Defaults such as the model, approval policy, and sandbox come from `~/.codex/config.toml`, managed in this repository as `home/dot_codex/private_config.toml.tmpl`. Read that file instead of assuming values. Check its approval and sandbox settings before relying on either, and state any read-only constraint in the prompt.
