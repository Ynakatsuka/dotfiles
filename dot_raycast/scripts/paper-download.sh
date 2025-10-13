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

# Initialize mise environment for tools installed via mise
if command -v mise &> /dev/null; then
    eval "$(mise activate bash --shims)"
fi

# Constants
PAPERS_DIR="$HOME/papers"
TEMP_DIR=$(mktemp -d)
CLAUDE_COMMANDS_DIR="$HOME/dotfiles/commands"

# Cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_dependencies() {
    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v pandoc &> /dev/null; then
        missing_deps+=("pandoc")
    fi

    if ! command -v pdftotext &> /dev/null; then
        log_warn "pdftotext not found. PDF support will be limited."
        log_warn "Install with: brew install poppler"
    fi

    if ! command -v claude &> /dev/null; then
        missing_deps+=("claude")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"

        # Provide installation instructions for specific tools
        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                claude)
                    log_error "Install Claude Code via mise:"
                    log_error "  mise use -g claude-code@latest"
                    ;;
                pandoc)
                    log_error "Install pandoc via Homebrew:"
                    log_error "  brew install pandoc"
                    ;;
                *)
                    log_error "Install $dep and ensure it's in your PATH"
                    ;;
            esac
        done

        exit 1
    fi
}

get_content_type() {
    local url="$1"
    curl -sI "$url" | grep -i "content-type:" | awk '{print $2}' | tr -d '\r'
}

download_and_convert_html() {
    local url="$1"
    local output_file="$2"

    log_info "Downloading HTML content..."

    # Download HTML and convert to markdown using pandoc
    curl -sL "$url" | pandoc -f html -t markdown -o "$output_file"

    if [ -s "$output_file" ]; then
        log_info "HTML content converted successfully"
        return 0
    else
        log_error "Failed to download or convert HTML content"
        return 1
    fi
}

download_and_convert_pdf() {
    local url="$1"
    local output_file="$2"

    if ! command -v pdftotext &> /dev/null; then
        log_error "pdftotext is required for PDF processing"
        log_error "Install with: brew install poppler"
        return 1
    fi

    log_info "Downloading PDF content..."

    local pdf_file="$TEMP_DIR/paper.pdf"
    curl -sL "$url" -o "$pdf_file"

    if [ ! -f "$pdf_file" ]; then
        log_error "Failed to download PDF"
        return 1
    fi

    log_info "Converting PDF to text..."
    pdftotext -layout "$pdf_file" "$output_file"

    if [ -s "$output_file" ]; then
        log_info "PDF content converted successfully"
        return 0
    else
        log_error "Failed to convert PDF to text"
        return 1
    fi
}

process_with_claude() {
    local content_file="$1"
    local url="$2"

    log_info "Processing content with Claude Code..."

    # Create papers directory if it doesn't exist
    mkdir -p "$PAPERS_DIR"

    # Prepare input for Claude
    local content
    content=$(cat "$content_file")

    # Read the paper-summary command template and modify it to save to current directory
    # Since we'll cd into PAPERS_DIR, change z/paper to . (current directory)
    local system_prompt
    system_prompt=$(sed 's|z/paper|.|g' "$CLAUDE_COMMANDS_DIR/paper-summary.md")

    # Execute Claude Code from within the papers directory
    # This ensures Claude has permission to write to the directory
    (
        cd "$PAPERS_DIR"
        echo "コンテンツ:
$content

元のURL: $url" | claude -p --system-prompt "$system_prompt"
    )

    log_info "Paper summary generated successfully"
}

main() {
    local url="${1:-}"

    if [ -z "$url" ]; then
        log_error "No URL provided"
        echo "Usage: $0 <paper_url>"
        exit 1
    fi

    log_info "Processing URL: $url"

    # Check dependencies
    check_dependencies

    # Determine content type
    local content_type
    content_type=$(get_content_type "$url")
    log_info "Content type: $content_type"

    local content_file="$TEMP_DIR/content.txt"

    # Download and convert based on content type
    case "$content_type" in
        *pdf*)
            download_and_convert_pdf "$url" "$content_file" || exit 1
            ;;
        *html*|*text*)
            download_and_convert_html "$url" "$content_file" || exit 1
            ;;
        *)
            # Try to detect from URL extension
            if [[ "$url" =~ \.pdf$ ]]; then
                download_and_convert_pdf "$url" "$content_file" || exit 1
            else
                # Default to HTML
                download_and_convert_html "$url" "$content_file" || exit 1
            fi
            ;;
    esac

    # Process with Claude Code
    process_with_claude "$content_file" "$url"

    log_info "Done! Check $PAPERS_DIR for the generated summary."
}

main "$@"
