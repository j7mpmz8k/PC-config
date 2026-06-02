#!/bin/bash
# Install Ollama and pull Gemma 4 (2B & 4B) on the hosting machine
# (Supports Windows Git Bash, WSL, and native Linux)

IS_WINDOWS=false
IS_WSL=false

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
elif grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

echo "Setting up local AI backend (Ollama & Gemma 4)..."

if ! command -v ollama &> /dev/null; then
    if $IS_WINDOWS; then
        echo "Ollama not found. Installing Ollama for Windows via winget..."
        winget install Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements
        echo "Configuring Ollama to listen on all interfaces (OLLAMA_HOST=0.0.0.0)..."
        setx OLLAMA_HOST "0.0.0.0"
        # Temporarily add Ollama directory to path so this script can run it immediately
        export PATH="$PATH:$HOME/AppData/Local/Programs/Ollama"
        echo "Starting Ollama..."
        powershell.exe -Command "Start-Process '$HOME\AppData\Local\Programs\Ollama\ollama.exe'"
    else
        echo "Ollama not found. Installing Ollama (may prompt for your sudo password)..."
        curl -fsSL https://ollama.com/install.sh | sh
    fi
else
    echo "Ollama is already installed."
    if $IS_WINDOWS && [ -z "$OLLAMA_HOST" ]; then
        echo "Configuring OLLAMA_HOST=0.0.0.0 on Windows..."
        setx OLLAMA_HOST "0.0.0.0"
        # Temporarily add Ollama directory to path
        export PATH="$PATH:$HOME/AppData/Local/Programs/Ollama"
        powershell.exe -Command "Stop-Process -Name ollama -ErrorAction SilentlyContinue; Start-Process '$HOME\AppData\Local\Programs\Ollama\ollama.exe'"
    fi
fi

# Start/Configure Ollama service on Linux & WSL
if ! $IS_WINDOWS; then
    if $IS_WSL; then
        # WSL Path: start in background without systemd
        if ! pgrep -x "ollama" >/dev/null; then
            echo "Starting Ollama server in WSL background..."
            OLLAMA_HOST=0.0.0.0 ollama serve >/dev/null 2>&1 &
            sleep 3
        fi
    else
        # Native Linux Path: configure and restart systemd service
        if [ -d /etc/systemd/system ] && [ ! -f /etc/systemd/system/ollama.service.d/override.conf ]; then
            echo "Configuring Ollama to listen on all interfaces on Linux..."
            sudo mkdir -p /etc/systemd/system/ollama.service.d
            echo -e "[Service]\nEnvironment=\"OLLAMA_HOST=0.0.0.0\"" | sudo tee /etc/systemd/system/ollama.service.d/override.conf >/dev/null
            sudo systemctl daemon-reload
        fi

        if [ -d /run/systemd/system ]; then
            echo "Restarting Ollama systemd service..."
            sudo systemctl restart ollama
        else
            if ! pgrep -x "ollama" >/dev/null; then
                echo "Starting Ollama server in background..."
                OLLAMA_HOST=0.0.0.0 ollama serve >/dev/null 2>&1 &
                sleep 3
            fi
        fi
    fi
fi

echo "Pulling the Gemma 4 (2B and 4B) models..."
ollama pull gemma4:e2b
ollama pull gemma4:e4b

echo "------------------------------------------------"
echo "Ollama & Gemma 4 Setup Complete!"
echo "------------------------------------------------"
if $IS_WINDOWS; then
    echo "Find this machine's IP by running 'ipconfig' in Windows Command Prompt/PowerShell."
elif $IS_WSL; then
    echo "WSL IP address is shared with Windows host."
    echo "You can connect using: http://localhost:11434"
else
    echo "Find this machine's IP by running 'hostname -I' or 'ip addr'."
fi
echo "Then connect Odysseus to this machine using its IP address on port 11434"
echo "------------------------------------------------"
