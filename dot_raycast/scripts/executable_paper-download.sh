#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download & Summarize Paper
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📄
# @raycast.argument1 { "type": "text", "placeholder": "Paper URL" }
# @raycast.packageName Research Tools

# Documentation:
# @raycast.description Download paper from URL and generate summary using Claude Code
# @raycast.author yuki
# @raycast.authorURL https://github.com/yourusername

set -euo pipefail

# Initialize mise environment
command -v mise &> /dev/null && eval "$(mise activate bash --shims)"

# Constants
readonly PAPERS_DIR="$HOME/papers"
readonly PAPERS_RAW_DIR="$HOME/papers/raw"
readonly TEMP_DIR=$(mktemp -d)

# Cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

# Logging
log() {
    local level=$1; shift
    local color=""
    case "$level" in
        INFO)  color='\033[0;32m' ;;
        ERROR) color='\033[0;31m' ;;
        WARN)  color='\033[1;33m' ;;
    esac
    echo -e "${color}[${level}]\033[0m $*"
}

# Check required dependencies
check_dependencies() {
    local deps=("curl" "pandoc" "claude")
    local missing=()

    for cmd in "${deps[@]}"; do
        command -v "$cmd" &> /dev/null || missing+=("$cmd")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log ERROR "Missing dependencies: ${missing[*]}"
        log ERROR "Install with:"
        log ERROR "  brew install pandoc"
        log ERROR "  mise use -g claude-code@latest"
        exit 1
    fi

    # Optional: pdftotext for PDF support
    command -v pdftotext &> /dev/null || log WARN "pdftotext not found. Install: brew install poppler"
}

# Detect if URL is PDF
is_pdf_url() {
    local url=$1
    [[ "$url" =~ \.pdf$ ]] || [[ $(curl -sI "$url" | grep -i "content-type:" | grep -i "pdf") ]]
}

# Download and convert content
download_content() {
    local url=$1
    local output=$2

    # Create raw directory
    mkdir -p "$PAPERS_RAW_DIR"

    # Generate filename from URL
    local raw_filename
    raw_filename=$(echo "$url" | sed 's|https\?://||' | sed 's|[/?&=]|-|g' | sed 's/--*/-/g' | cut -c1-100)

    if is_pdf_url "$url"; then
        if ! command -v pdftotext &> /dev/null; then
            log ERROR "pdftotext required for PDF. Install: brew install poppler"
            return 1
        fi
        log INFO "Downloading PDF..."
        local raw_file="$PAPERS_RAW_DIR/${raw_filename}.pdf"
        curl -sL "$url" -o "$TEMP_DIR/paper.pdf"
        cp "$TEMP_DIR/paper.pdf" "$raw_file"
        pdftotext -layout "$TEMP_DIR/paper.pdf" "$output"
        echo "$raw_file"
    else
        log INFO "Downloading HTML..."
        local raw_file="$PAPERS_RAW_DIR/${raw_filename}.txt"
        curl -sL "$url" | pandoc -f html -t markdown -o "$output"
        cp "$output" "$raw_file"
        echo "$raw_file"
    fi

    [ -s "$output" ] || { log ERROR "Download failed"; return 1; }
    log INFO "Content downloaded successfully"
    log INFO "Raw file saved to: $raw_file"
}

# Process with Claude Code
process_with_claude() {
    local content_file=$1
    local url=$2
    local raw_file=$3

    # Check file size
    local file_size
    file_size=$(wc -c < "$content_file")
    local file_lines
    file_lines=$(wc -l < "$content_file")

    log INFO "Processing with Claude Code... (Content: ${file_lines} lines, $(numfmt --to=iec-i --suffix=B "$file_size" 2>/dev/null || echo "${file_size} bytes"))"

    if [ "$file_size" -gt 1048576 ]; then  # 1MB
        log WARN "Large content detected (>1MB). This may take several minutes..."
    fi

    mkdir -p "$PAPERS_DIR"

    # Run Claude in papers directory for write permissions
    local output_file="$TEMP_DIR/claude_output.txt"
    local timeout_seconds=300  # 5 minutes timeout

    # Convert raw file path to use tilde notation
    local raw_file_display="${raw_file/#$HOME/~}"

    {
        cat "$content_file"
        echo ""
        echo "---"
        echo "元のURL: $url"
        echo "Raw file: $raw_file_display"
    } | claude -p --system-prompt "$(cat <<'PROMPT'
Analyze the provided paper content and generate a comprehensive Japanese summary in Markdown format.

Output ONLY the markdown content, starting with the paper title heading.

## Required Structure
```markdown
# {Paper Title}

## メタ情報
- **元のURL**: {論文の元URL}
- **Raw file**: {保存したrawファイルへのパス}

## 概要
{5行以内の概要：研究目的、主な貢献、手法、結果、意義}

## 技術的なラベル
{カンマ区切りで最大10個：Recommender Systems, Deep Learning, etc.}

## コードリンク
{GitHubリンクまたは「なし」}

## 詳細な内容

### リサーチクエスチョン
- **問題設定**: {解決する問題}
- **研究の動機**: {重要性}
- **仮説**: {検証する仮説}

### 技術的側面
- **手法の概要**: {使用した手法の説明}
- **実装方法**: {具体的な実装アプローチ}
- **重要な数式**: {LaTeX形式: $$formula$$}

### 学習の詳細（該当する場合）
- **入力データ**: {モデルへの入力の形式と内容}
- **ラベル/ターゲット**: {予測対象や教師信号の定義}
- **データセット**: {使用したデータセットの名前、規模、特性}
- **学習設定**: {損失関数、最適化手法、ハイパーパラメータ}

### 研究の結果
- **主要な結果**: {定量的・定性的結果}
- **有効性の証明**: {手法の有効性を示すエビデンス}

### 結果の解釈と限界
- **限界と適用範囲**: {制約や適用可能な範囲}
- **今後の研究方向**: {将来的な研究課題}

### 関連研究
- **論文名・著者・発表年**: {引用箇所}

### 図表の説明
- **Figure X**: {説明と重要性}
- **Table Y**: {主要な発見}
```

## Guidelines
- Write summary in Japanese (except for the paper title)
- Use **bold** for important terms
- Use $$formula$$ for mathematical expressions
- Output ONLY the markdown content, no extra commentary
- Ensure comprehensive analysis of the paper
PROMPT
)" > "$output_file" 2>&1 &

    local claude_pid=$!
    local elapsed=0

    # Display elapsed time while Claude is processing (every 10 seconds)
    while kill -0 "$claude_pid" 2>/dev/null; do
        if [ $((elapsed % 10)) -eq 0 ] && [ "$elapsed" -gt 0 ]; then
            printf "\r\033[K\033[0;36m[PROCESSING]\033[0m %d seconds elapsed..." "$elapsed"
        fi

        # Check for timeout
        if [ "$elapsed" -ge "$timeout_seconds" ]; then
            kill "$claude_pid" 2>/dev/null
            wait "$claude_pid" 2>/dev/null
            printf "\r\033[K"
            log ERROR "Processing timed out after ${timeout_seconds} seconds"
            log ERROR "Output saved to: $output_file"
            return 1
        fi

        sleep 1
        ((elapsed++))
    done

    # Wait for the process to complete and get exit status
    wait "$claude_pid"
    local exit_status=$?

    printf "\r\033[K"  # Clear the line

    if [ $exit_status -eq 0 ]; then
        log INFO "Processing completed in ${elapsed} seconds"

        # Extract title and create filename
        local paper_title
        paper_title=$(head -1 "$output_file" | sed 's/^# //')

        if [ -z "$paper_title" ]; then
            log ERROR "Failed to extract paper title from output"
            log ERROR "Output saved to: $output_file"
            return 1
        fi

        # Create URL-friendly filename
        local filename
        filename=$(echo "$paper_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | cut -c1-60)
        filename="${filename}.md"

        # Save to papers directory
        cp "$output_file" "$PAPERS_DIR/$filename"
        log INFO "Summary saved to: $PAPERS_DIR/$filename"

        # Open in Cursor if available
        if command -v cursor &> /dev/null; then
            cursor "$PAPERS_DIR/$filename"
        elif [ -d "/Applications/Cursor.app" ]; then
            open -a "Cursor" "$PAPERS_DIR/$filename"
        fi

    else
        log ERROR "Claude processing failed after ${elapsed} seconds (exit code: $exit_status)"
        log ERROR "Output saved to: $output_file"
        head -20 "$output_file" >&2
        return 1
    fi
}

# Main
main() {
    local url="${1:-}"

    [ -z "$url" ] && { log ERROR "No URL provided"; echo "Usage: $0 <paper_url>"; exit 1; }

    log INFO "Processing: $url"
    check_dependencies

    local content_file="$TEMP_DIR/content.txt"
    local raw_file
    raw_file=$(download_content "$url" "$content_file") || exit 1

    process_with_claude "$content_file" "$url" "$raw_file"

    log INFO "Done! Check $PAPERS_DIR for the summary."
}

main "$@"
