#!/bin/bash
# =============================================================================
# Quick Install Script for VPS Server Checker
# Usage: curl -sSL <URL>/install.sh | bash
# =============================================================================

set -e

main() {
    INSTALL_DIR="${HOME}/server-checker"
    REPO_URL="https://github.com/Rerowros/server-checker"
    RAW_URL="https://raw.githubusercontent.com/Rerowros/server-checker/main"

    echo "🖥️  VPS Server Checker - Quick Install"
    echo "========================================"

    # Create directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # Check if git is available
    if command -v git &>/dev/null; then
        echo "📥 Cloning repository..."
        if [ -d ".git" ]; then
            git pull origin main 2>/dev/null || true
        else
            git clone "$REPO_URL" . 2>/dev/null || {
                echo "⚠️  Git clone failed, downloading files directly..."
                download_files "$RAW_URL"
            }
        fi
    else
        echo "📥 Downloading files..."
        download_files "$RAW_URL"
    fi

    # Make executable
    chmod +x check-server.sh lib/*.sh 2>/dev/null || chmod +x check-server.sh

    echo ""
    echo "✅ Installation complete!"
    echo "📍 Installed to: $INSTALL_DIR"
    echo ""
    echo "🚀 To run the checker now:"
    echo "   cd $INSTALL_DIR && ./check-server.sh"
    echo ""

    # Ask to run now (pipe-safe because we are inside a function)
    if [ -t 0 ] || [ -c /dev/tty ]; then
        echo -n "Run now? [Y/n] "
        read -n 1 -r REPLY < /dev/tty || true
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            ./check-server.sh
        fi
    fi
}

download_files() {
    local base_url="$1"
    mkdir -p lib
    curl -sSL "${base_url}/check-server.sh" -o check-server.sh
    curl -sSL "${base_url}/lib/colors.sh" -o lib/colors.sh
    curl -sSL "${base_url}/lib/network.sh" -o lib/network.sh
    curl -sSL "${base_url}/lib/blocklist.sh" -o lib/blocklist.sh
    curl -sSL "${base_url}/lib/dpi.sh" -o lib/dpi.sh
    curl -sSL "${base_url}/lib/report.sh" -o lib/report.sh
}

# Execute main function
main "$@"
