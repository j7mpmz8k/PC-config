#!/bin/bash
# Install Ollama and pull AI models (Gemma 4, Llama 3.1, Qwen 2.5) on the hosting machine
# (Supports Windows Git Bash, WSL, and native Linux)

IS_WINDOWS=false
IS_WSL=false

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
elif grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

echo "Setting up local AI backend (Ollama & AI Models)..."

if ! command -v ollama &> /dev/null; then
    if $IS_WINDOWS; then
        echo "Ollama not found. Installing Ollama for Windows via winget..."
        winget install Ollama.Ollama --silent --accept-source-agreements --accept-package-agreements
        echo "Configuring Ollama to listen on all interfaces (OLLAMA_HOST=0.0.0.0)..."
        setx OLLAMA_HOST "0.0.0.0"
        # Temporarily add Ollama directory to path so this script can run it immediately
        export PATH="$PATH:$HOME/AppData/Local/Programs/Ollama"
        echo "Starting Ollama..."
        powershell.exe -Command "[System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '0.0.0.0', 'Process'); Start-Process '$HOME\AppData\Local\Programs\Ollama\ollama.exe'"
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
        powershell.exe -Command "Stop-Process -Name ollama -ErrorAction SilentlyContinue; [System.Environment]::SetEnvironmentVariable('OLLAMA_HOST', '0.0.0.0', 'Process'); Start-Process '$HOME\AppData\Local\Programs\Ollama\ollama.exe'"
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

echo "Pulling Ollama models (Gemma 4, Llama 3.1, and Qwen 2.5)..."
ollama pull gemma4:e2b
ollama pull gemma4:e4b
ollama pull llama3.1
ollama pull qwen2.5:7b

echo "------------------------------------------------"
echo "Ollama & AI Models Setup Complete!"
echo "------------------------------------------------"
# Dynamically calculate the local IP address
HOST_IP=""
if $IS_WINDOWS; then
    # Prioritize finding a 192.* IP on physical adapters, then fall back to other private/available IPs
    HOST_IP=$(powershell.exe -Command "
        \$ip = (Get-NetIPAddress -InterfaceAlias 'Wi-Fi*', 'Ethernet*' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { \$_.IPAddress -like '192.*' } | Select-Object -First 1).IPAddress;
        if (-not \$ip) {
            \$ip = (Get-NetIPAddress -InterfaceAlias 'Wi-Fi*', 'Ethernet*' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { \$_.IPAddress -like '10.*' -or \$_.IPAddress -like '172.*' } | Select-Object -First 1).IPAddress;
        }
        if (-not \$ip) {
            \$ip = (Get-NetIPAddress -InterfaceAlias 'Wi-Fi*', 'Ethernet*' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress;
        }
        if (-not \$ip) {
            \$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { \$_.IPAddress -like '192.*' } | Select-Object -First 1).IPAddress;
        }
        if (-not \$ip) {
            \$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress;
        }
        \$ip
    " | tr -d '\r\n ')
elif $IS_WSL; then
    HOST_IP="localhost"
else
    # Use active routing destination to find the true local LAN IP interface
    HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -o -E "src [0-9.]+" | awk '{print $2}')
    # Fallback to private range matching if routing table lookup fails
    [ -z "$HOST_IP" ] && HOST_IP=$(hostname -I | tr ' ' '\n' | grep -E -o "192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|172\.(1[6-9]|2[0-9]|3[0-1])\.[0-9]+\.[0-9]+" | head -n 1)
fi

echo "Connect Odysseus to this machine using this exact URL in Settings -> Servers:"
echo "http://${HOST_IP:-<THIS_MACHINE_IP>}:11434"
echo "------------------------------------------------"
