---
name: my-mock
description: >-
  Show UI, screen, and layout design proposals as mock images: build a throwaway HTML mock,
  render it to PNG with a headless browser, and display the image with a one-line trade-off per
  option. Use when proposing or comparing designs, layouts, or screen structures, and when the
  user says "デザイン案", "モック", "UI 案", "画面設計", "レイアウト案", "ワイヤーフレーム",
  "mockup", or "wireframe". Do NOT use for implementing or fixing UI code, bug fixes,
  before-and-after screenshots of a finished change, or charts and dashboards of real data.
compatibility: >-
  Needs agent-browser on PATH (playwright-cli as fallback) and a local Chromium. Works offline.
---

# UI Mock Images

## 1. Decide the options

- Settle the screen, the target viewport, and what the options must differ in. Propose two or
  three options that differ in structure, not only in color. Make one option when the user asked
  for a single design.
- Pick one frame size for all options: desktop `960x600`, mobile `390x844`, or the product's
  real viewport when known.

## 2. Write one HTML file

- Copy `assets/compare.html` as `mock.html` in `/tmp/mock-<topic>/` outside the repository, unless
  the user names a place. Keep one `<section class="option">` per option, title each
  `A: <name>`, and set `--frame-w` and `--frame-h` to the frame size.
- Fill each `.frame` with inline HTML and CSS: realistic labels and sample data in the user's
  language, real controls drawn plainly, no lorem ipsum. Size content relative to the frame, not
  the browser window, so every option is judged at the same viewport.
- Use no network resources: no CDN fonts, scripts, or images. Draw icons with text or inline SVG.
- Keep it fast and disposable. Do not write the mock into the application's code or add packages.

## 3. Render the PNG

Rendering a local file is not website browsing; run the headless CLI directly.

```bash
cd /tmp/mock-<topic>
agent-browser --session mock open "file:///tmp/mock-<topic>/mock.html"
agent-browser --session mock set viewport <sheet-width> 900
agent-browser --session mock screenshot .sheet mock.png
agent-browser --session mock close
```

- Set `<sheet-width>` to all frames in one row plus 100 px, for example `2020` for two 960 px
  frames. For four or more options, use a narrower width so the frames wrap to two rows. The
  element screenshot captures the whole sheet even beyond the viewport height.
- Render a single option with the selector `#option-a`.
- When agent-browser fails after one retry, report the error and use `playwright-cli` instead,
  following its own guide from `playwright-cli --help`.
- Open the PNG and check it yourself before showing it: no clipped text, no missing glyphs, no
  overflow outside a frame. Fix the HTML and render again until it is clean.

## 4. Show the result

- In CCV, when the `ccv-user-question` MCP server is available, call its `preview_image` before
  the final response. It rejects paths outside the current project directory, so first copy the
  PNG into a directory there that `git check-ignore` confirms is ignored, and pass that path.
- Elsewhere, give the absolute PNG path, and the HTML path for interactive viewing.
- Under the image, list the options with the recommended one first, each in one line:
  `A: <name> — 利点: … / 欠点: …`.
- After the user chooses, implement only the chosen option, in the project's own stack.
