#!/bin/bash
# Setup isolated Python environment for vocoder
# This ensures consistent dependencies regardless of system Python

set -euo pipefail

VENV_DIR="${HOME}/.local/share/vocoder/venv"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔧 Setting up vocoder virtual environment..."

# Create venv if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment at $VENV_DIR"
    python3 -m venv "$VENV_DIR"
fi

# Activate venv
source "$VENV_DIR/bin/activate"

# Upgrade pip
pip install --upgrade pip wheel setuptools

# Install locked dependencies
echo "Installing pinned dependencies..."
pip install -r "$PROJECT_DIR/requirements.lock"

# Create wrapper scripts that use venv
mkdir -p ~/.local/bin

cat > ~/.local/bin/vocoder <<'EOF'
#!/bin/bash
source ~/.local/share/vocoder/venv/bin/activate
exec python3 /home/ice/dev/vocoder/bin/vocoder "$@"
EOF

cat > ~/.local/bin/vocoderctl <<'EOF'
#!/bin/bash
source ~/.local/share/vocoder/venv/bin/activate
exec python3 /home/ice/dev/vocoder/bin/vocoderctl "$@"
EOF

chmod +x ~/.local/bin/vocoder ~/.local/bin/vocoderctl

# Update systemd service to use venv
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/vocoder.service <<EOF
[Unit]
Description=Vocoder Daemon - Fast voice dictation
After=network.target sound.target

[Service]
Type=simple
ExecStart=$VENV_DIR/bin/python $PROJECT_DIR/bin/vocoder
Restart=on-failure
RestartSec=5
Environment="PYTHONUNBUFFERED=1"
Environment="WHISPER_URL=http://127.0.0.1:8771/v1/transcribe"
Environment="CLIPBOARD_MODE=true"
Environment="MAX_DURATION=60"
Environment="DEBUG=1"

[Install]
WantedBy=default.target
EOF

echo "✅ Virtual environment setup complete!"
echo ""
echo "Installed to: $VENV_DIR"
echo "Wrappers at: ~/.local/bin/vocoder[ctl]"
echo ""
echo "To activate manually: source $VENV_DIR/bin/activate"
echo "To reload service: systemctl --user daemon-reload && systemctl --user restart vocoder"