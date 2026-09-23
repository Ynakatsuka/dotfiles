# Antigravityによる書き直し

文章推敲ではAntigravity CLI経由のGeminiを既定の書き直し担当にする。意味とトーンの判定は、
呼び出し元のモデルが原文と候補を直接比較して行う。

## 初回の書き直し

原稿を次のJSONとして組み立て、標準入力からスクリプトへ渡す。

```json
{
  "blocks": [
    {
      "id": "p001",
      "original": "書き直す原稿",
      "guidance": "ユーザーが今回指定した条件。なければ省略する"
    }
  ]
}
```

実行する。

```bash
python3 <skill-root>/scripts/rewrite_with_antigravity.py rewrite < job.json
```

`<skill-root>`はこのスキルの`SKILL.md`があるディレクトリの絶対パスへ置き換える。実際には一時
ファイルを使うか、JSONエンコーダーで生成した内容を標準入力へ渡す。原稿をシェル引数や手書きの
エスケープへ埋め込まない。

## 問題箇所の修復

照合で見つかった問題だけを`issues`に入れる。一般的なチェックリストを追加しない。

```json
{
  "blocks": [
    {
      "id": "p001",
      "original": "最初の原稿",
      "candidate": "Geminiの候補",
      "issues": [
        "原文では実施予定だが、候補では実施済みになっている"
      ]
    }
  ]
}
```

```bash
python3 <skill-root>/scripts/rewrite_with_antigravity.py repair < job.json
```

修復は一度だけ行い、最初の原文と再照合する。

## 利用不能とする条件

スクリプトが非ゼロで終了した場合は、Antigravityを利用できないものとして現在のモデルへ切り替える。
対象には次を含む。

- `agy`が見つからない。
- 指定モデル`gemini-3.8-flash-high`を利用できない、または認証に失敗した。
- タイムアウト、拒否、CLIエラーが発生した。
- Geminiがツールを呼び出した。
- 応答がJSONでない、IDが欠落・重複する、本文が空である。
- 実際に使われたモデルを指定値として確認できない。

失敗理由を短く示し、現在のモデルが同じ原稿を自由に書き直す。別の外部モデルへ切り替えず、同じ
Antigravity呼び出しを再試行しない。
