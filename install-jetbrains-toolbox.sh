#!/usr/bin/env bash
# =============================================================================
# JetBrains Toolbox Installer
# =============================================================================
# Automatically fetches the latest version of JetBrains Toolbox and installs
# it. On first run, Toolbox installs itself to ~/.local/share/JetBrains/Toolbox
# and registers a .desktop entry in the app launcher.
#
# Usage:
#   chmod +x install-jetbrains-toolbox.sh
#   ./install-jetbrains-toolbox.sh
# =============================================================================

set -e

echo "=> Fetching latest JetBrains Toolbox download URL..."
URL=$(curl -s 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release' \
  | python3 -c "import sys, json; d = json.load(sys.stdin); print(d['TBA'][0]['downloads']['linux']['link'])")

echo "=> Downloading: $URL"
curl -Lo /tmp/jb-toolbox.tar.gz "$URL"

echo "=> Extracting..."
tar -xzf /tmp/jb-toolbox.tar.gz -C /tmp

echo "=> Launching Toolbox (it will install itself)..."
/tmp/jetbrains-toolbox-*/bin/jetbrains-toolbox &

echo ""
echo "✓ Done! JetBrains Toolbox is launching."
echo "  Look for it in your system tray or app launcher."
echo ""
echo "  Installed to: ~/.local/share/JetBrains/Toolbox"
echo "  It will autostart on future logins."
