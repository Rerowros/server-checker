#!/bin/bash
# =============================================================================
# Quick Install Script for VPS Server Checker
# Usage: curl -sSL <URL>/install.sh | bash
# =============================================================================

set -e

INSTALL_DIR="${HOME}/server-checker"
REPO_URL="https://github.com/YOUR_REPO/server-checker"

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
    # Fall back to direct download
    mkdir -p lib
    
    curl -sSL "${REPO_URL}/raw/main/check-server.sh" -o check-server.sh
    curl -sSL "${REPO_URL}/raw/main/lib/colors.sh" -o lib/colors.sh
    curl -sSL "${REPO_URL}/raw/main/lib/network.sh" -o lib/network.sh
    curl -sSL "${REPO_URL}/raw/main/lib/blocklist.sh" -o lib/blocklist.sh
    curl -sSL "${REPO_URL}/raw/main/lib/dpi.sh" -o lib/dpi.sh
    curl -sSL "${REPO_URL}/raw/main/lib/report.sh" -o lib/report.sh
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

# Ask to run now
read -p "Run now? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    echo ""
    ./check-server.sh
fi
