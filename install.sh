#!/bin/bash
# =============================================================================
# Quick Install Script for VPS Server Checker
# Usage: curl -sSL <URL>/install.sh | bash
# =============================================================================

set -e

INSTALL_DIR="${HOME}/server-checker"
REPO_URL="https://github.com/Rerowros/server-checker"

echo "🖥️  VPS Server Checker - Quick Install"
echo "========================================"

# Create directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Check if git is available
if command -v git &>/dev/null; then
    echo "📥 Cloning repository..."
    git clone "$REPO_URL" . 2>/dev/null || {
        echo "⚠️  Git clone failed, downloading files directly..."
    }
else
    echo "📥 Downloading files..."
    # Fall back to direct download (using raw.githubusercontent.com for reliability)
    mkdir -p lib
    raw_url="https://raw.githubusercontent.com/Rerowros/server-checker/main"
    
    curl -sSL "${raw_url}/check-server.sh" -o check-server.sh
    curl -sSL "${raw_url}/lib/colors.sh" -o lib/colors.sh
    curl -sSL "${raw_url}/lib/network.sh" -o lib/network.sh
    curl -sSL "${raw_url}/lib/blocklist.sh" -o lib/blocklist.sh
    curl -sSL "${raw_url}/lib/dpi.sh" -o lib/dpi.sh
    curl -sSL "${raw_url}/lib/report.sh" -o lib/report.sh
fi

# Make executable
chmod +x check-server.sh
chmod +x lib/*.sh

echo ""
echo "✅ Installation complete!"
echo ""
echo "📍 Installed to: $INSTALL_DIR"
echo ""
echo "🚀 Run the checker:"
echo "   cd $INSTALL_DIR && ./check-server.sh"
echo ""

# Ask to run now (pipe-safe read using /dev/tty)
if [ -t 0 ] || [ -c /dev/tty ]; then
    read -p "Run now? [Y/n] " -n 1 -r < /dev/tty || true
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo ""
        ./check-server.sh
    fi
fi
