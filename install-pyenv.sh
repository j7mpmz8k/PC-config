#!/usr/bin/env bash
# =============================================================================
# pyenv Installer
# =============================================================================
# Installs pyenv and Python 3.14.5t (free-threaded / no-GIL build) from
# source, then sets it as the global default.
#
# Usage:
#   chmod +x install-pyenv.sh
#   ./install-pyenv.sh
#
# What this script does:
#   1. Installs build dependencies via apt
#   2. Clones pyenv into ~/.pyenv
#   3. Adds pyenv init lines to ~/.bashrc (if not already present)
#   4. Installs Python 3.14.5t and sets it as the global default
# =============================================================================

set -e

PYTHON_VERSION="3.14.5t"

# -----------------------------------------------------------------------------
# 1. Build dependencies
# -----------------------------------------------------------------------------
echo "=> Installing build dependencies..."
sudo apt update
sudo apt install -y \
  build-essential \
  curl \
  git \
  libbz2-dev \
  libffi-dev \
  liblzma-dev \
  libncursesw5-dev \
  libreadline-dev \
  libsqlite3-dev \
  libssl-dev \
  libxml2-dev \
  libxmlsec1-dev \
  tk-dev \
  xz-utils \
  zlib1g-dev

# -----------------------------------------------------------------------------
# 2. Install pyenv
# -----------------------------------------------------------------------------
if [ -d "$HOME/.pyenv" ]; then
  echo "=> pyenv already found at ~/.pyenv — skipping clone."
else
  echo "=> Cloning pyenv into ~/.pyenv..."
  git clone https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
fi

# -----------------------------------------------------------------------------
# 3. Add pyenv init to ~/.bashrc (idempotent)
# -----------------------------------------------------------------------------
BASHRC="$HOME/.bashrc"
PYENV_INIT_MARKER="# >>> pyenv init >>>"

if grep -q "$PYENV_INIT_MARKER" "$BASHRC" 2>/dev/null; then
  echo "=> pyenv init already present in ~/.bashrc — skipping."
else
  echo "=> Adding pyenv init to ~/.bashrc..."
  cat >> "$BASHRC" << 'EOF'

# >>> pyenv init >>>
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"
eval "$(pyenv virtualenv-init -)"
# <<< pyenv init <<<
EOF
fi

# -----------------------------------------------------------------------------
# 4. Load pyenv for the rest of this script
# -----------------------------------------------------------------------------
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"

# -----------------------------------------------------------------------------
# 5. Install Python and set global version
# -----------------------------------------------------------------------------
if pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  echo "=> Python $PYTHON_VERSION already installed — skipping build."
else
  echo "=> Building Python $PYTHON_VERSION (this may take a few minutes)..."
  # PYTHON_GIL=0 is the env var that activates the free-threaded mode at runtime
  PYTHON_GIL=0 pyenv install "$PYTHON_VERSION"
fi

echo "=> Setting Python $PYTHON_VERSION as the global default..."
pyenv global "$PYTHON_VERSION"

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
echo "✓ Done! pyenv is installed with Python $PYTHON_VERSION set as global."
echo "  Restart your shell (or run: source ~/.bashrc) to activate pyenv."
echo "  Verify with: python --version"
echo ""
echo "  The 't' suffix = free-threaded build (no GIL). To confirm:"
echo "    python -c \"import sys; print(sys._is_gil_enabled())\""
echo "  Should print: False"
echo ""
