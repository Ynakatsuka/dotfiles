#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Download & Summarize Paper
# @raycast.mode fullOutput

# Optional parameters:
# @raycast.icon 📄
# @raycast.argument1 { "type": "text", "placeholder": "Paper URL(s) or local file path(s) - space separated" }
# @raycast.packageName Research Tools

# Documentation:
# @raycast.description Download paper(s) from URL(s) or process local PDF file(s) and generate summaries using Claude Code. Supports multiple URLs/files.
# @raycast.author yuki
# @raycast.authorURL https://github.com/yourusername

set -euo pipefail

# Initialize mise environment
command -v mise &> /dev/null && eval "$(mise activate bash --shims)"

# Constants
readonly PAPERS_DIR="$HOME/papers"
readonly PAPERS_RAW_DIR="$HOME/papers/raw"
readonly PAPERS_LOGS_DIR="$HOME/papers/logs"

# Logging
log() {
    local level=$1; shift
    echo "[$level] $*" >&2
    [ -n "${LOG_FILE:-}" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# Send desktop notification
notify() {
    local title=$1
    local message=$2
    local sound=${3:-"default"}

    if command -v osascript &> /dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\" sound name \"$sound\""
    fi
}

# Check required dependencies
check_dependencies() {
    local deps=("curl" "claude")
    local missing=()

    for cmd in "${deps[@]}"; do
        command -v "$cmd" &> /dev/null || missing+=("$cmd")
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log ERROR "Missing dependencies: ${missing[*]}"
        log ERROR "Install with:"
        log ERROR "  mise use -g claude-code@latest"
        exit 1
    fi

    # Optional: pandoc for HTML support
    command -v pandoc &> /dev/null || log WARN "pandoc not found. Install: brew install pandoc (needed for HTML papers)"

    # Optional: Playwright for fallback when curl fails
    if command -v uv &> /dev/null; then
        local script_dir
        script_dir=$(dirname "$0")
        if ! uv run --directory "$script_dir" python -c "import playwright" 2>/dev/null; then
            log WARN "Playwright not found. Install: cd $script_dir && uv sync && uv run playwright install chromium"
            log WARN "Playwright is used as fallback when curl fails to download PDFs"
        fi
    else
        log WARN "uv not found. Playwright fallback will not be available"
    fi
}

# Check if input is a local file
is_local_file() {
    local input=$1
    [[ -f "$input" ]]
}

# Detect if URL is PDF
is_pdf_url() {
    local url=$1

    # Check if URL ends with .pdf or has pdf-related query parameters
    if [[ "$url" =~ \.pdf$ ]] || [[ "$url" =~ (\?|\&)name=pdf ]]; then
        return 0
    fi

    # Fallback: Check Content-Type header
    local content_type
    content_type=$(curl -sI -L "$url" 2>/dev/null | grep -i "^content-type:" | head -1)
    [[ -n "$content_type" ]] && [[ "$content_type" =~ pdf ]]
}

# Download paper (PDF or HTML)
download_paper() {
    local url=$1

    # Create raw directory
    mkdir -p "$PAPERS_RAW_DIR"

    # Generate safe filename from URL
    # Remove protocol, convert special chars to underscore, remove consecutive underscores
    local raw_filename
    raw_filename=$(echo "$url" | sed 's|https\?://||' | sed 's|[^a-zA-Z0-9]|_|g' | sed 's/__*/_/g' | sed 's/^_\|_$//g' | cut -c1-80)

    # Add timestamp for uniqueness
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    raw_filename="${timestamp}_${raw_filename}"

    if is_pdf_url "$url"; then
        log INFO "Downloading PDF..."
        local raw_file="$PAPERS_RAW_DIR/${raw_filename}.pdf"

        # Use -L to follow redirects
        local curl_success=false
        if curl -sL "$url" -o "$raw_file" && file "$raw_file" | grep -q "PDF"; then
            curl_success=true
        else
            log WARN "curl failed, trying Playwright..."
            [ -f "$raw_file" ] && rm "$raw_file"
        fi

        # Fallback to Playwright if curl failed
        if [ "$curl_success" = false ]; then
            local script_dir
            script_dir=$(dirname "$0")
            local playwright_script="$script_dir/dl_pdf.py"

            if [ ! -f "$playwright_script" ]; then
                log ERROR "Playwright script not found: $playwright_script"
                return 1
            fi

            if ! uv run --directory "$script_dir" python "$playwright_script" "$url" "$raw_file"; then
                log ERROR "Playwright download failed"
                return 1
            fi

            # Verify it's actually a PDF
            if ! file "$raw_file" | grep -q "PDF"; then
                log ERROR "Downloaded file is not a valid PDF"
                [ -f "$raw_file" ] && rm "$raw_file"
                return 1
            fi
        fi

        log INFO "Raw file saved to: $raw_file"
        echo "$raw_file"
    else
        log INFO "Downloading HTML..."
        local raw_file="$PAPERS_RAW_DIR/${raw_filename}.html"

        if ! command -v pandoc &> /dev/null; then
            log ERROR "pandoc required for HTML. Install: brew install pandoc"
            return 1
        fi

        if ! curl -sL "$url" -o "$raw_file"; then
            log ERROR "Failed to download HTML"
            return 1
        fi

        log INFO "HTML downloaded successfully"
        log INFO "Raw file saved to: $raw_file"
        echo "$raw_file"
    fi
}

# Process with Claude Code
process_with_claude() {
    local paper_file=$1
    local url=$2

    log INFO "Processing with Claude Code..."

    local file_size
    file_size=$(wc -c < "$paper_file")
    [ "$file_size" -gt 10485760 ] && log WARN "Large file (>10MB), may take several minutes"

    mkdir -p "$PAPERS_DIR"

    local output_file="$TEMP_DIR/claude_output.txt"
    local timeout_seconds=600  # 10 minutes timeout

    # Convert file path to use tilde notation
    local paper_file_display="${paper_file/#$HOME/~}"

    # Prepare the prompt with file reference and metadata
    local prompt_file="$TEMP_DIR/prompt.txt"
    cat > "$prompt_file" <<EOF
Analyze the paper at this file path: $paper_file

Generate a comprehensive Japanese summary in Markdown format.

**Paper Information:**
- Original URL: $url
- Raw file: $paper_file_display

Output ONLY the markdown content, starting with the paper title heading.

## Required Structure
\`\`\`markdown
# {Paper Title}

## メタ情報
- **元のURL**: $url
- **Raw file**: $paper_file_display

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
- **重要な数式**: {LaTeX形式: \$\$formula\$\$}

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
\`\`\`

## Guidelines
- Write summary in Japanese (except for the paper title)
- Use **bold** for important terms
- Use \$\$formula\$\$ for mathematical expressions
- Output ONLY the markdown content, no extra commentary
- Ensure comprehensive analysis of the paper
- Extract all important information from the paper including figures and tables
EOF

    # Run Claude with the paper file directly
    # Add papers directory to allowed directories for file access
    {
        cat "$prompt_file" | claude -p --add-dir "$PAPERS_DIR" --add-dir "$PAPERS_RAW_DIR" > "$output_file" 2>&1
    } &

    local claude_pid=$!
    local elapsed=0

    # Wait with timeout
    while kill -0 "$claude_pid" 2>/dev/null; do
        [ "$elapsed" -ge "$timeout_seconds" ] && {
            kill "$claude_pid" 2>/dev/null
            wait "$claude_pid" 2>/dev/null
            log ERROR "Processing timed out after ${timeout_seconds}s"
            return 1
        }
        sleep 1
        ((elapsed++))
    done

    wait "$claude_pid"
    local exit_status=$?

    if [ $exit_status -eq 0 ]; then
        log INFO "Processing completed (${elapsed}s)"

        # Extract title and create filename
        local paper_title
        paper_title=$(head -1 "$output_file" | sed 's/^# //')

        if [ -z "$paper_title" ]; then
            log ERROR "Failed to extract paper title"
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
        log ERROR "Claude processing failed (exit code: $exit_status)"
        return 1
    fi
}

# Background job wrapper
run_in_background() {
    local input=$1
    local job_index=${2:-}

    # Setup log directory
    mkdir -p "$PAPERS_LOGS_DIR"

    # Generate unique log filename
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')

    # Add job index to filename if processing multiple URLs
    local log_filename
    if [ -n "$job_index" ]; then
        log_filename="paper-download-${timestamp}-job${job_index}.log"
    else
        log_filename="paper-download-${timestamp}.log"
    fi

    export LOG_FILE="$PAPERS_LOGS_DIR/$log_filename"

    log INFO "Starting background job..."
    log INFO "Input: $input"
    log INFO "Log file: $LOG_FILE"

    # Show immediate feedback
    echo ""
    echo "🚀 Background job started!"
    if [ -n "$job_index" ]; then
        echo "📋 Job: $job_index"
    fi
    echo "📄 Input: $input"
    echo "📝 Log file: $LOG_FILE"
    echo "💡 You can close this window safely."
    echo ""
    echo "To view progress:"
    echo "  tail -f $LOG_FILE"

    # Run actual processing in background
    {
        # Create temp directory for this background job
        local TEMP_DIR
        TEMP_DIR=$(mktemp -d)
        trap 'rm -rf "$TEMP_DIR"' EXIT

        check_dependencies

        local paper_file
        local source_url=""

        # Check if input is a local file or URL
        if is_local_file "$input"; then
            log INFO "Processing local file: $input"

            # Copy to raw directory for record keeping
            mkdir -p "$PAPERS_RAW_DIR"
            local filename
            filename=$(basename "$input")
            local raw_file="$PAPERS_RAW_DIR/${timestamp}-${filename}"
            cp "$input" "$raw_file"

            paper_file="$raw_file"
            source_url="(local file: $input)"
            log INFO "File copied to: $raw_file"
        else
            log INFO "Downloading from URL: $input"
            source_url="$input"
            paper_file=$(download_paper "$input")
        fi

        if [ $? -eq 0 ] && [ -n "$paper_file" ]; then
            if process_with_claude "$paper_file" "$source_url"; then
                log INFO "Successfully completed"
                notify "📄 Paper Download Complete" "Summary has been generated and saved" "Glass"
            else
                log ERROR "Failed to process with Claude"
                notify "📄 Paper Download Failed" "Claude processing failed" "Basso"
            fi
        else
            log ERROR "Failed to download paper"
            notify "📄 Paper Download Failed" "Download failed" "Basso"
        fi
    } &

    # Return immediately
    disown
}

# Main
main() {
    # Check if any arguments provided
    [ $# -eq 0 ] && {
        echo "Usage: $0 <paper_url_or_file_path> [<url2> <url3> ...]"
        echo ""
        echo "Examples:"
        echo "  $0 https://arxiv.org/pdf/2403.00133.pdf"
        echo "  $0 /path/to/local/paper.pdf"
        echo "  $0 https://arxiv.org/pdf/2403.00133.pdf https://openreview.net/pdf?id=abc123"
        exit 1
    }

    # If multiple URLs provided, process them sequentially
    if [ $# -gt 1 ]; then
        echo "========================================"
        echo "📚 Processing $# papers sequentially"
        echo "========================================"
        echo ""

        local total=$#
        local current=0

        for input in "$@"; do
            current=$((current + 1))
            echo "----------------------------------------"
            echo "[$current/$total] Processing: $input"
            echo "----------------------------------------"
            run_in_background "$input" "$current"

            # Wait a bit between launches to avoid overwhelming the system
            if [ $current -lt $total ]; then
                echo ""
                echo "⏳ Waiting 3 seconds before next paper..."
                sleep 3
                echo ""
            fi
        done

        echo ""
        echo "========================================"
        echo "✅ All $total papers queued!"
        echo "========================================"
        echo ""
        echo "📂 Check logs in: $PAPERS_LOGS_DIR"
        echo "📊 Monitor all jobs:"
        echo "  tail -f $PAPERS_LOGS_DIR/paper-download-*.log"
    else
        # Single URL - original behavior
        run_in_background "$1"
    fi
}

main "$@"
