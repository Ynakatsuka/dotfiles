---
name: my-bullets
description: >-
  Formats notes, findings, decisions, and drafts as concise, undecorated bullet lists
  for internal team sharing. Use when the user asks for "箇条書き", "箇条書きにして",
  "bullet", or "bullet points", or asks to prepare, rewrite, or organize a team update,
  internal announcement, handoff, Slack or Teams post, decision note, or content they
  plan to share with colleagues. Do NOT use for ordinary answers, private analysis,
  public or customer-facing messages, or an explicitly requested incompatible format.
---

# Structured Bullets

Create a draft that the user can paste into an internal team channel or document.

## Structure

- When the source contains a consultation item or a decision the team should make now, start with a Discussion points section. State what needs consultation or decision, not just the topic. Do not invent a discussion point.
- Otherwise, lead with the main point or requested action.
- Use a short labeled top-level bullet for each useful section.
- Put supporting facts in nested bullets.
- Use plain text only. Do not add Markdown decoration such as bold, italics, headings, blockquotes, inline code, or horizontal rules.
- Use hyphens only as bullet markers. Keep section labels as undecorated text.
- Remove existing Markdown decoration when rewriting source text unless the user explicitly asks to preserve the original formatting.
- Include only sections that contain useful information. Choose labels such as:
  - Discussion points
  - Summary
  - Background
  - Decision
  - Action items
  - Requests
  - Open questions
  - References
- Match the language and terminology of the source material. Localize section labels.
- Follow headings or field names supplied by the user instead of the defaults.

Use this default shape when the user does not specify one:

```markdown
- Discussion points
  - [What the team should discuss or decide now]
- Summary
  - [The main point]
- Background
  - [Facts needed to understand it]
- Action items
  - [Action]
    - Owner: [Use only when supplied]
    - Due: [Use only when supplied]
- Open questions
  - [An unresolved fact or follow-up that does not need a decision now]
```

## Writing Rules

- For Japanese bullet lists, default to concise plain forms, fragments, and noun phrases. Do not force `です・ます` endings. Use polite forms only when the user or communication context requires them.
- Keep one idea in each bullet.
- Keep labels and bullets short enough to scan quickly.
- Put decisions, requests, owners, and deadlines in explicit fields when known.
- Preserve the source facts and level of certainty.
- Do not invent missing owners, deadlines, decisions, status, or evidence.
- Use Discussion points for consultation items and decisions needed now. Use Open questions for later follow-up.
- Remove empty sections, repeated conclusions, greetings, and filler.
- Do not send or publish the draft unless the user separately asks for that action.

## Example

Input: "検索基盤のリリースはエラーが出たので延期。佐藤さんが明日11時までに原因を調べる。それまでは再実行しないでほしい。再リリースを明日午後と来週月曜のどちらにするか、今回決めたい。"

Output:

```markdown
- 論点
  - 再リリース日を明日午後と来週月曜のどちらにするか
- 要点
  - 検索基盤のリリースを延期
- 理由
  - リリース時にエラー発生
- 対応
  - 原因を調査
    - 担当: 佐藤さん
    - 期限: 明日11時
- 依頼
  - 調査完了まで再実行しない
```
