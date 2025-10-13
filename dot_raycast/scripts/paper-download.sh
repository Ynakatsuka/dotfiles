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
readonly TEMP_DIR=$(mktemp -d)
readonly CLAUDE_COMMANDS_DIR="$HOME/dotfiles/commands"

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

    if is_pdf_url "$url"; then
        if ! command -v pdftotext &> /dev/null; then
            log ERROR "pdftotext required for PDF. Install: brew install poppler"
            return 1
        fi
        log INFO "Downloading PDF..."
        curl -sL "$url" -o "$TEMP_DIR/paper.pdf"
        pdftotext -layout "$TEMP_DIR/paper.pdf" "$output"
    else
        log INFO "Downloading HTML..."
        curl -sL "$url" | pandoc -f html -t markdown -o "$output"
    fi

    [ -s "$output" ] || { log ERROR "Download failed"; return 1; }
    log INFO "Content downloaded successfully"
}

# Process with Claude Code
process_with_claude() {
    local content_file=$1
    local url=$2

    log INFO "Processing with Claude Code..."
    mkdir -p "$PAPERS_DIR"

    local system_prompt
    system_prompt=$(sed 's|z/paper|.|g' "$CLAUDE_COMMANDS_DIR/paper-summary.md")

    # Run Claude in papers directory for write permissions
    (
        cd "$PAPERS_DIR"
        cat "$content_file" | claude -p --system-prompt "$system_prompt" <<EOF
コンテンツ:
$(cat "$content_file")

元のURL: $url
EOF
    )
}

# Open generated file in Cursor if available
open_in_cursor() {
    local timestamp=$1
    sleep 1

    local file
    file=$(find "$PAPERS_DIR" -maxdepth 1 -type f -name "*.md" -newermt "@$timestamp" -print | head -1)

    if [ -n "$file" ]; then
        log INFO "Generated: $file"

        if command -v cursor &> /dev/null; then
            cursor "$file"
        elif [ -d "/Applications/Cursor.app" ]; then
            open -a "Cursor" "$file"
        fi
    else
        log WARN "Generated file not found. Check $PAPERS_DIR"
    fi
}

# Main
main() {
    local url="${1:-}"

    [ -z "$url" ] && { log ERROR "No URL provided"; echo "Usage: $0 <paper_url>"; exit 1; }

    log INFO "Processing: $url"
    check_dependencies

    local content_file="$TEMP_DIR/content.txt"
    download_content "$url" "$content_file" || exit 1

    local timestamp
    timestamp=$(date +%s)

    process_with_claude "$content_file" "$url"
    open_in_cursor "$timestamp"

    log INFO "Done! Check $PAPERS_DIR for the summary."
}

main "$@"
