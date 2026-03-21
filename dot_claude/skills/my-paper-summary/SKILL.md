---
name: my-paper-summary
description: >-
  Analyze academic papers and generate structured Japanese summaries.
  Saves output as markdown to z/paper/ directory.
  Use when summarizing papers, requesting "論文要約", or "paper summary".
argument-hint: "<url-or-filepath>"
---

# Paper Summary — Academic Paper Analyzer

論文・記事の内容を分析し、構造化された日本語要約を生成する。

## 入力

ユーザーから以下のいずれかの形式でコンテンツが提供される:

- ArXiv URL（HTML版を `@https://arxiv.org/html/...` で取得）
- PDF ファイルパス
- テキスト貼り付け

## 分析フレームワーク

1. **基本情報**: タイトル、著者、所属、発表年、会議/ジャーナル
2. **内容分析**: 研究課題、手法、結果、限界
3. **技術分類**: 推薦システム関連ラベルを優先

## 出力

`z/paper/{paper_title_slug}.md` にマークダウンファイルを保存する。

### ファイル構造

```markdown
# {Paper Title}

## 概要
{最大5行の概要}

## 技術的なラベル
{カンマ区切りで最大10個}

## コードリンク
{コードリンクまたは「なし」}

## 詳細な内容

### 1. リサーチクエスチョン
- **問題設定**: 何を解決するか
- **研究の動機**: なぜ重要か
- **仮説**: 何を検証するか

### 2. 技術的側面
- **手法の概要**: 基本概念と原理
- **手法の特徴**: 特徴、利点、適用範囲
- **重要な数式**: 主要な数式（LaTeX: $$formula$$）
- **実装方法**: 具体的な実装アプローチ

### 3. 研究の結果
- **主要な結果**: 研究目的に沿った結果
- **有効性の証明**: 定量的・定性的な結果
- **リサーチクエスチョンへの回答**: 直接的な回答

### 4. 結果の解釈と限界
- **限界と適用範囲**: 結果解釈の限界
- **今後の研究方向**: 将来の研究課題

### 5. 関連研究
- **論文名・著者・発表年**: 引用箇所

### 6. 図表の説明と重要性
- **Figure X**: 説明と重要性
- **Table Y**: 主要な知見
```

## 技術ラベルの優先順位

推薦システム関連を優先:
- **Recommender Systems**: ABtest, Coldstart, Diversity, Debias, Multi-list interface
- **Machine Learning**: Deep Learning, Reinforcement Learning, Transfer Learning
- **Data Mining**: Collaborative Filtering, Matrix Factorization
- **Evaluation**: Metrics, Benchmarking, User Study
- **Others**: Fairness, Privacy, Scalability, Real-time, Multi-modal

## ファイル名の生成

```bash
mkdir -p z/paper
# タイトルからURL-friendly slug を生成（小文字、ハイフン区切り、60文字以内）
```

## 記述ガイドライン

- 日本語で記述（コード・数式・技術用語は英語）
- **太字** で重要語を強調
- 数式は `$$formula$$` 形式
- アルゴリズムは Python コードブロックで記述
- 数式には必ず記法の説明を付ける
