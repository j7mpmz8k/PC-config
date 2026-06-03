#!/bin/bash
# Install Docker and Docker Compose on Pop!_OS / Ubuntu

if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Error: WSL detected." >&2
    echo "Do not install native Linux Docker inside WSL as it conflicts with Docker Desktop." >&2
    echo "Please install Docker Desktop on your Windows host instead." >&2
    echo "" >&2
    echo "Windows Installation Options:" >&2
    echo "---------------------------------------------------------" >&2
    echo "Option A: Manual GUI Installation (No Terminal)" >&2
    echo "  1. Download the installer from: https://www.docker.com/products/docker-desktop/" >&2
    echo "  2. Double-click the downloaded installer and follow the wizard." >&2
    echo "" >&2
    echo "Option B: PowerShell Terminal (Fastest)" >&2
    echo "  1. Open PowerShell on Windows (as Administrator)." >&2
    echo "  2. Run: winget install Docker.DockerDesktop" >&2
    echo "" >&2
    echo "Option C: Run this Script Natively on Windows" >&2
    echo "  You must run this script from 'Git Bash' (not WSL)." >&2
    echo "  - To get Git Bash: Download & install 'Git for Windows' from: https://git-scm.com/downloads" >&2
    echo "  - Once installed, open Git Bash and run: ./install-docker.sh" >&2
    echo "---------------------------------------------------------" >&2
    exit 1

elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    echo "Windows detected (via Git Bash/MSYS). Installing Docker Desktop..."
    if ! command -v winget &> /dev/null; then
        echo "Error: winget is not available. Please install Docker Desktop manually from https://www.docker.com/products/docker-desktop/"
        exit 1
    fi
    winget install Docker.DockerDesktop --silent --accept-source-agreements --accept-package-agreements
    echo "Docker Desktop installed! Please restart your terminal/Windows to apply changes."
else
    echo "Linux detected (Pop!_OS / Ubuntu / WSL2)..."
    sudo apt update
    sudo apt install -y docker.io docker-buildx docker-compose-v2 openssh-server
    sudo systemctl enable --now ssh
    sudo usermod -aG docker $USER
    echo "Docker and SSH server installed. Automatically reloading group permissions..."
    exec sg docker "$SHELL"
fi
