#!/bin/bash
# Install and launch Odysseus AI Workspace using Docker

# 1. Validation Checks
echo "Checking system prerequisites..."

IS_WINDOWS=false
IS_WSL=false
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    IS_WINDOWS=true
elif grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
fi

if $IS_WINDOWS; then
    if ! command -v docker &> /dev/null; then
        echo "Docker Desktop not found. Installing via winget..."
        if ! command -v winget &> /dev/null; then
            echo "Error: winget is not available. Please install Docker Desktop manually." >&2
            exit 1
        fi
        winget install Docker.DockerDesktop --silent --accept-source-agreements --accept-package-agreements
        echo "Docker Desktop installed! Please restart your terminal after this script finishes."
    fi
    DOCKER_CMD="docker compose"
    echo "Prerequisites verified! Docker is running and accessible."
else
    if ! command -v docker &> /dev/null; then
        echo "Docker not found. Installing Docker and dependencies..."
        sudo apt update
        sudo apt install -y docker.io docker-buildx docker-compose-v2
        sudo usermod -aG docker $USER
    fi

    if ! docker compose version &> /dev/null; then
        echo "Docker Compose not found. Installing..."
        sudo apt update
        sudo apt install -y docker-compose-v2
    fi

    if ! command -v sshd &> /dev/null; then
        echo "SSH server not found. Installing openssh-server..."
        sudo apt update
        sudo apt install -y openssh-server
        sudo systemctl enable --now ssh
    fi

    if docker info &> /dev/null; then
        DOCKER_CMD="docker compose"
    elif sg docker -c "docker info" &> /dev/null; then
        DOCKER_CMD="sg docker -c \"docker compose\""
    elif command -v docker &> /dev/null; then
        DOCKER_CMD="sg docker -c \"docker compose\""
    else
        echo "Error: Cannot connect to the Docker daemon." >&2
        echo "Verify that Docker is running and your user is in the 'docker' group." >&2
        exit 1
    fi
    echo "Prerequisites verified! Docker is running and accessible."
fi

# 2. Local AI Model Setup (Ollama & Gemma 4)
echo "------------------------------------------------"
echo "Setting up local AI backend (Ollama & Gemma 4)..."

OLLAMA_CONNECTED=false

if $IS_WSL; then
    echo "WSL detected. Checking if Ollama is running on Windows host..."
    # Connect to the host's Ollama API port (11434)
    if curl -s -o /dev/null -w "%{http_code}" http://host.docker.internal:11434/api/tags | grep -q "200"; then
        echo "Ollama detected on Windows host!"
        OLLAMA_CONNECTED=true
    else
        echo "Windows Ollama is not running (or not set to OLLAMA_HOST=0.0.0.0)."
    fi
fi

if ! $OLLAMA_CONNECTED; then
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

    # Start the service safely (works on systemd systems and WSL fallbacks)
    if ! $IS_WINDOWS; then
        if [ -d /run/systemd/system ]; then
            if ! systemctl is-active --quiet ollama; then
                echo "Starting Ollama systemd service..."
                sudo systemctl start ollama
            fi
        else
            if ! pgrep -x "ollama" >/dev/null; then
                echo "Starting Ollama server in background..."
                ollama serve >/dev/null 2>&1 &
                sleep 3
            fi
        fi
    fi
fi
echo "------------------------------------------------"

# 3. Odysseus Setup
TARGET_DIR="$HOME/odysseus"

if [ -d "$TARGET_DIR" ]; then
    echo "Odysseus directory already exists at $TARGET_DIR. Pulling latest changes..."
    cd "$TARGET_DIR" || exit 1
    git pull
else
    echo "Cloning Odysseus repository into $TARGET_DIR..."
    git clone https://github.com/pewdiepie-archdaemon/odysseus.git "$TARGET_DIR"
    cd "$TARGET_DIR" || exit 1
fi

if [ ! -f .env ]; then
    echo "Creating .env configuration from template..."
    cp .env.example .env
fi

if [ ! -f docker-compose.override.yml ]; then
    echo "Configuring home directory access and host network access in docker-compose.override.yml..."
    cat <<EOF > docker-compose.override.yml
services:
  odysseus:
    volumes:
      - \${HOME}:\${HOME}:z
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF
fi

echo "Starting Odysseus services..."
eval "$DOCKER_CMD up -d --build"

echo "------------------------------------------------"
echo "Odysseus setup complete!"
echo "------------------------------------------------"
echo "1. Access the UI: Open http://localhost:7000 in your browser."
echo "2. Initial Setup: Create your admin account directly in the browser."
echo "3. Connect Gemma 4 (Local or Remote):"
echo "   - Go to Settings -> Servers in Odysseus."
echo "   - OPTION A: For Local Gemma (running on this machine):"
echo "     * Click 'Local' then 'Scan for servers'."
echo "     * Fallback: paste http://host.docker.internal:11434 into the local LLM endpoint box."
echo "     * Save settings and select 'gemma4:e2b' from the model dropdown."
echo "   - OPTION B: For Remote Gemma (running on another machine on your LAN):"
echo "     * Paste http://<REMOTE_MACHINE_IP>:11434 into the local LLM endpoint box."
echo "     * Save settings and select 'gemma4:e4b' from the model dropdown!"
echo "4. Connect to Host Terminal via SSH (Optional):"
echo "   - Go to Settings -> Servers in Odysseus."
echo "   - Add a new server connection:"
echo "     * Host: host.docker.internal"
echo "     * Port: 22"
echo "     * Username: $USER"
echo "     * Auth Method: SSH Key (Generate key in Odysseus and copy its public key to ~/.ssh/authorized_keys on this host)"
echo "   - Click 'Save' to add the server, then double check the connection by pressing 'Check' to ping the server."
echo "------------------------------------------------"

if ! $IS_WINDOWS; then
    echo ""
    read -p "Paste the SSH setup command from Odysseus to authorize it (optional, press Enter to skip): " USER_CMD
    if [ -n "$USER_CMD" ]; then
        PUB_KEY_REGEX="(ssh-ed25519[[:space:]][a-zA-Z0-9+/=]+([[:space:]]+[a-zA-Z0-9._@-]+)?)"
        if [[ "$USER_CMD" =~ $PUB_KEY_REGEX ]]; then
            PUB_KEY="${BASH_REMATCH[1]}"
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh"
            touch "$HOME/.ssh/authorized_keys"
            chmod 600 "$HOME/.ssh/authorized_keys"
            if ! grep -qxF "$PUB_KEY" "$HOME/.ssh/authorized_keys"; then
                echo "$PUB_KEY" >> "$HOME/.ssh/authorized_keys"
                echo "Successfully installed SSH key directly to ~/.ssh/authorized_keys!"
            else
                echo "SSH key is already registered."
            fi
        else
            FIXED_CMD=$(echo "$USER_CMD" | sed 's/host\.docker\.internal/localhost/g')
            echo "Executing: $FIXED_CMD"
            eval "$FIXED_CMD"
        fi
    fi

    if ! groups | grep -q "\bdocker\b"; then
        echo "Reloading terminal group permissions..."
        exec sg docker "$SHELL"
    fi
fi
