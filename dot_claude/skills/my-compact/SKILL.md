---
name: my-compact
description: >-
  Build, debug, and tune OpenAI Responses API code that uses compaction for
  long-running, multi-turn conversations. Covers server-side automatic
  compaction (`context_management` with `compact_threshold`) and the explicit
  `/responses/compact` endpoint, plus opaque-item handling, `previous_response_id`
  pruning pitfalls, and ZDR (`store=False`) integration.
  TRIGGER when: code calls `client.responses.create` / `client.responses.compact`
  with long inputs; user asks about OpenAI compaction, Responses API context
  management, long-conversation cost/latency, or ZDR-compliant Responses
  pipelines; Japanese phrases like "コンパクション", "OpenAI 長い会話",
  "Responses API のコンテキスト管理", "compact_threshold".
  Do NOT use for Claude / Anthropic SDK work (use `claude-api` instead),
  Claude Code's built-in `/compact` slash command, OpenAI Chat Completions
  (no compaction support), or generic OpenAI questions unrelated to Responses
  or compaction.
---

# OpenAI Responses API Compaction

Compaction reduces tokens in long Responses API conversations by replacing
prior turns with an opaque "compaction item" that carries forward key state
and reasoning. Use it for cost, latency, and ZDR-friendly long workflows.

Primary source: https://developers.openai.com/api/docs/guides/compaction

## Decision: which mode

- **Server-side automatic** (default recommendation): pass
  `context_management=[{"type": "compaction", "compact_threshold": N}]` to
  `client.responses.create`. The model compacts inline once the running
  conversation exceeds `N` tokens.
- **Explicit / standalone**: call `client.responses.compact(...)` to compact
  a window on demand, then feed the returned items into the next
  `responses.create`. Pick this when you need manual control, batched
  pre-compaction, or fully stateless ZDR pipelines.

Default to server-side unless the user has a specific reason to compact
manually.

## `compact_threshold` sizing

- Set near **~80% of the model's context window** so a full prompt + the
  largest expected tool output still fits before compaction triggers.
- Confirm the target model's window before suggesting a number; do not
  hardcode `200000` blindly. The 200k value in the official docs is an
  example, not a recommendation.
- A threshold larger than the model's context window is a bug — compaction
  cannot rescue an over-limit request.
- Too low a threshold causes thrashing (compaction every turn). Pick a
  threshold that compacts a few times per long session, not constantly.

## Handling compaction items

- Compaction items are **opaque**. Never parse, edit, hand-craft, or log
  their internals. Treat them like model-managed tokens.
- **Stateless chaining (`store=False`, no `previous_response_id`)**: append
  every item from `response.output` (compaction items included) to the next
  `input` array. You MAY drop items that precede the most recent compaction
  item to shrink the request.
- **`previous_response_id` chaining**: do NOT manually prune. The server
  resolves history from the prior response id; client-side trimming desyncs
  state and silently corrupts context.
- For the standalone endpoint, pass the returned `compacted.output` into the
  next `input` unchanged — no further pruning.

## ZDR (zero-data-retention) pipelines

- Set `store=False` on every `responses.create` call.
- Prefer the standalone `/responses/compact` endpoint or server-side
  compaction with stateless chaining; both are ZDR-compatible.
- Avoid `previous_response_id` under ZDR — it implies server-side history.

## Code patterns

### Server-side automatic

```python
conversation = [
    {"type": "message", "role": "user", "content": "Let's begin a long task."}
]

while keep_going:
    response = client.responses.create(
        model="gpt-5.3-codex",
        input=conversation,
        store=False,
        context_management=[
            {"type": "compaction", "compact_threshold": 200_000}
        ],
    )
    conversation.extend(response.output)  # includes any compaction item
    conversation.append(
        {"type": "message", "role": "user", "content": next_user_input()}
    )
```

### Standalone explicit

```python
compacted = client.responses.compact(
    model="gpt-5.5",
    input=long_input_items,
)

next_input = [
    *compacted.output,
    {"type": "message", "role": "user", "content": next_user_input()},
]

next_response = client.responses.create(
    model="gpt-5.5",
    input=next_input,
    store=False,
)
```

## Common pitfalls to flag

- Manually pruning history while using `previous_response_id`.
- Inspecting or mutating the opaque compaction item.
- Treating compaction as a way to exceed the model's hard context window.
- Forgetting `store=False` in a ZDR-required deployment.
- Picking `compact_threshold` higher than the model context window, or so
  low that compaction fires after every turn (thrashing).
- Using compaction on Chat Completions endpoints — it is Responses-only.

## When in doubt

- Cite the official guide above as the source of truth.
- If the user is on Anthropic / Claude SDK, hand off to the `claude-api`
  skill — that surface uses prompt caching and a different context model.
