#!/usr/bin/env bash
# =============================================================================
# VS Code Installer
# =============================================================================
# Installs Visual Studio Code from Microsoft's official apt repository.
# This gives you native system integration and automatic updates via apt.
#
# Usage:
#   chmod +x install-vscode.sh
#   ./install-vscode.sh
# =============================================================================

set -e

echo "=> Adding Microsoft GPG key..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null

echo "=> Adding VS Code apt repository..."
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

echo "=> Updating package list..."
sudo apt update

echo "=> Installing VS Code..."
sudo apt install -y code

echo ""
echo "✓ Done! VS Code is installed."
echo "  Launch it by typing: code"
echo "  Or find it in your app launcher."
echo ""
echo "  Future updates will come automatically via: sudo apt upgrade"
