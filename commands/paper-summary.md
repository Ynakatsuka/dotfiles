# Paper Summary Command

## Your task

Analyze the provided paper/article content and generate a comprehensive Japanese summary following the structured format below.

### Analysis Framework

Carefully read through the provided content and extract the following information:

1. **Title and Basic Information**
   - Paper/article title
   - Authors and affiliation (if available)
   - Publication venue and year (if available)

2. **Content Analysis**
   - Main research question or problem statement
   - Technical approaches and methodologies
   - Key findings and results
   - Limitations and future work

3. **Technical Categorization**
   - Identify relevant technical labels (especially recommender system related)
   - Extract methodology keywords
   - Note domain-specific terminology

### Output Structure

Generate the summary as a Markdown file and save it to `z/paper/{paper_title_slug}.md` where `{paper_title_slug}` is a URL-friendly version of the paper title.

The Markdown file should follow this structure:

```markdown
# {Paper Title}

## 概要
{最大5行の概要}

## 技術的なラベル
{カンマ区切りで最大10個のラベル}

## コードリンク
{コードリンク（存在する場合、なければ「なし」）}

## 詳細な内容
{詳細なMarkdown形式の内容}
```

### Summary Guidelines (最大5行)

Write a concise summary that captures:
- Research objective and motivation
- Main contribution or novelty
- Key methodology used
- Primary results or findings
- Significance or impact

### Technical Labels (最大10個、カンマ区切り)

Prioritize recommender system related labels when applicable:
- **Recommender Systems**: ABtest, Coldstart, Diversity, Serendipity, Debias, Multi-list interface
- **Machine Learning**: Deep Learning, Neural Networks, Reinforcement Learning, Transfer Learning
- **Data Mining**: Collaborative Filtering, Content-based Filtering, Matrix Factorization
- **Evaluation**: Metrics, Benchmarking, User Study, Online Evaluation
- **Others**: Fairness, Privacy, Scalability, Real-time, Multi-modal

### Detailed Description (Markdown形式)

Structure the detailed content with the following sections:

#### 1. リサーチクエスチョン
- **問題設定**: What problem does this research address?
- **研究の動機**: Why is this problem important?
- **仮説**: What hypotheses does the research test?

#### 2. 技術的側面
- **手法の概要**: Basic concepts and principles of each method
- **手法の特徴**: Features, advantages, and applicable scope
- **選択理由**: Why these methods were chosen and their role
- **実装方法**: Specific application and implementation approaches
- **重要な数式**: Key mathematical formulations and algorithms (use LaTeX: $$formula$$)
- **パラメータ設定**: Parameter settings and learning processes

#### 3. 研究の結果
- **主要な結果**: Results aligned with research objectives
- **有効性の証明**: Quantitative and qualitative results showing method effectiveness
- **新規性の裏付け**: Results supporting novelty and importance
- **リサーチクエスチョンへの回答**: Direct answers to research questions

#### 4. 結果の解釈と限界
- **エビデンスの強さ**: Strength of evidence supporting authors' interpretations
- **仮定と前提条件**: Assumptions and prerequisites in result interpretation
- **限界と適用範囲**: Limitations and scope of result interpretation
- **今後の研究方向**: Future research directions and challenges

#### 5. 関連研究
List related works in the format:
- **論文名・著者・所属・発表年**: 引用箇所（例: 緒言, 方法, 結果, 考察）

#### 6. 問題・タスクの定義
- **解決する問題**: Specific problems or tasks being addressed
- **問題の重要性**: Why these problems matter
- **従来手法との比較**: How this differs from existing approaches

#### 7. 図表の説明と重要性
- **Figure X**: Description and significance
- **Table Y**: Key findings and implications
- **Algorithm Z**: Step-by-step explanation

### Writing Guidelines

- **太文字強調**: Use **bold** for important parts and keywords
- **読みやすさ**: Ensure clear structure with proper paragraphs and logical flow
- **専門用語**: Provide explanations for technical terms
- **数式記法**: Always include notation explanations for mathematical expressions
- **LaTeX数式**: Use $$formula$$ format for mathematical expressions
- **コードブロック**: Use Python code blocks for algorithms when applicable
- **手法の比較**: When multiple methods are used, explain:
  - Relationships and interactions between methods
  - Comparisons with similar approaches
  - Advantages and characteristics of chosen methods

### Example Algorithm Format

When describing algorithms, use Python code format:

```python
def example_algorithm(input_data):
    """
    Algorithm description
    
    Args:
        input_data: Description of input
    
    Returns:
        result: Description of output
    """
    # Step 1: Preprocessing
    processed_data = preprocess(input_data)
    
    # Step 2: Main computation
    result = compute(processed_data)
    
    return result
```

### Mathematical Notation Example

Use LaTeX format for mathematical expressions:

$$\text{Loss} = \sum_{i=1}^{n} \ell(f(x_i), y_i) + \lambda \|w\|_2^2$$

Where:
- $\ell$: loss function
- $f(x_i)$: model prediction for input $x_i$
- $y_i$: true label
- $\lambda$: regularization parameter
- $w$: model parameters

## Processing Instructions

1. **Input Analysis**: Carefully read and understand the provided content
2. **Information Extraction**: Extract all relevant information following the framework
3. **Categorization**: Identify appropriate technical labels with recommender system priority
4. **File Name Generation**: Create a URL-friendly slug from the paper title:
   - Convert to lowercase
   - Replace spaces with hyphens
   - Remove special characters
   - Limit to reasonable length (e.g., max 60 characters)
5. **Directory Setup**: Ensure the `z/paper/` directory exists
6. **File Creation**: Generate the Markdown file following the specified structure
7. **Quality Check**: Ensure all sections are comprehensive and accurate

### File Creation Workflow

```bash
# 1. Create directory if it doesn't exist
mkdir -p z/paper

# 2. Generate filename from title
PAPER_SLUG=$(echo "{paper_title}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | cut -c1-60)

# 3. Create the summary file
cat > "z/paper/${PAPER_SLUG}.md" << 'EOF'
# {Paper Title}

## 概要
{Summary content here}

## 技術的なラベル
{Labels here}

## コードリンク
{Code link or "なし"}

## 詳細な内容
{Detailed content here}
EOF

# 4. Confirm file creation
echo "論文要約が z/paper/${PAPER_SLUG}.md に保存されました"
```

## Important Notes

- **Output Format**: Create a Markdown file in `z/paper/` directory, not JSON
- **File Naming**: Use URL-friendly slugs for filenames
- **Language**: Write in Japanese for all narrative content
- **Code/Technical Terms**: Use English for code, mathematical notation, and technical terminology
- **Accuracy**: Ensure factual accuracy and avoid speculation
- **Completeness**: Address all required sections comprehensively
- **Clarity**: Use clear, accessible language while maintaining technical precision
- **Directory Creation**: Always ensure the target directory exists before creating files

The content to analyze will be provided in the format:
```
コンテンツ:
{content}
```

Process this content according to the above guidelines and create the Markdown file in the specified location.
