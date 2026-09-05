---
name: my-stop-ai-slop-jp
description: >-
  Edit Japanese drafts to remove formulaic AI phrasing while preserving the author's
  meaning, evidence, and requested voice. Use for explicit AI臭 / AIっぽさ removal,
  polishing a Japanese article or public-facing draft, or explicit skill invocation.
  Do NOT use for ordinary Japanese answers, progress updates, technical explanations,
  code review, or English prose unless Japanese prose editing is explicitly requested.
metadata:
  language: ja
  author: Daichi Nagashima (https://genshi.ai/)
  inspired-by: hardikpandya/stop-slop
---

# 日本語原稿の推敲

> Adapted from iKora128/stop-ai-slop-jp (https://github.com/iKora128/stop-ai-slop-jp), commit e09d327. Licensed under MIT, Copyright (c) 2026 Daichi Nagashima.

## 編集方針

- 原稿の意味、事実の確度、書き手の立場、指定された文体と形式を保つ。具体性を補うために体験、人物、数値、感情を作らない。
- 事実には根拠に合った表現を使う。推測と伝聞は区別し、確認済みの事実を文体のために曖昧にしない。
- 書き手の評価や語り口は残す。語尾の混在、感情の強弱、皮肉、誤字を人間らしさの演出として加えない。
- 一般的な文体は適用中の指示に従う。以下の参照資料は修正候補であり、単語、記号、段落の長さだけを理由に一律に直さない。

## 手順

1. 原稿の目的、読み手、残すべき主張を依頼から確認する。
2. 読みにくい箇所に合わせて必要な参照資料だけを読む。
   - 主体の曖昧さ、過剰な演出、構成の反復: `references/structures.md`
   - 抽象語、翻訳調、不要な装飾: `references/phrases.md`
   - 修正方法を具体例で確認したい場合: `references/examples.md`
3. 根拠のない一般化や意味の薄い反復を優先して直す。表現の調整は、意味と語り口を保てる範囲に限る。
4. 原稿と照合し、主張、確度、指定形式が変わっていないか確認して返す。修正文だけを求められた場合は解説を付けない。
