#!/usr/bin/env bash
# setup-option-b.sh - Install and configure vocoder daemon (Option B)
# Preserves Option A as fallback

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "Vocoder Option B - Daemon Setup"
echo "======================================"
echo ""
echo "This will install the vocoder daemon alongside Option A."
echo "Option A will remain as a fallback."
echo ""

# Check if we're in the right directory
if [[ ! -f "bin/vocoder" ]]; then
    echo -e "${RED}Error: Run this script from the vocoder project root${NC}"
    exit 1
fi

PROJECT_DIR="$(pwd)"

# Step 1: Check Python
echo "1. Checking Python..."
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}✗ Python 3 not found${NC}"
    echo "Install with: sudo dnf install python3"
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo -e "${GREEN}✓ Python $PYTHON_VERSION found${NC}"

# Step 2: Install Python dependencies
echo ""
echo "2. Installing Python dependencies..."
echo "Do you want to install dependencies system-wide or in a venv? (s/v)"
read -r INSTALL_TYPE

if [[ "$INSTALL_TYPE" == "v" ]]; then
    # Create venv
    if [[ ! -d ".venv" ]]; then
        echo "Creating virtual environment..."
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    PIP_CMD=".venv/bin/pip"
    PYTHON_CMD=".venv/bin/python3"
else
    PIP_CMD="pip3"
    PYTHON_CMD="python3"
fi

echo "Installing requirements..."
$PIP_CMD install -q numpy sounddevice httpx 2>/dev/null || {
    echo -e "${YELLOW}⚠ Some packages may need to be installed with:${NC}"
    echo "  pip3 install --user numpy sounddevice httpx"
}

# Optional systemd-python
$PIP_CMD install -q systemd-python 2>/dev/null || {
    echo -e "${YELLOW}Note: systemd-python not installed (optional)${NC}"
}

echo -e "${GREEN}✓ Python dependencies installed${NC}"

# Step 3: Test daemon can start
echo ""
echo "3. Testing daemon startup..."
timeout 2s $PYTHON_CMD bin/vocoder &>/dev/null &
DAEMON_PID=$!
sleep 1

if kill -0 $DAEMON_PID 2>/dev/null; then
    echo -e "${GREEN}✓ Daemon starts successfully${NC}"
    kill $DAEMON_PID 2>/dev/null || true
    wait $DAEMON_PID 2>/dev/null || true
else
    echo -e "${RED}✗ Daemon failed to start${NC}"
    echo "Check with: $PYTHON_CMD bin/vocoder"
    exit 1
fi

# Step 4: Install systemd service
echo ""
echo "4. Installing systemd service..."

SERVICE_FILE="$HOME/.config/systemd/user/vocoder.service"
mkdir -p "$HOME/.config/systemd/user"

# Update service file with correct Python path
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Vocoder Daemon - Fast voice dictation (Option B)
Documentation=https://github.com/arealicehole/vocoder
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=notify
ExecStart=$PYTHON_CMD $PROJECT_DIR/bin/vocoder
Restart=always
RestartSec=5

Environment="PYTHONUNBUFFERED=1"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u)"
Environment="WHISPER_URL=http://127.0.0.1:8765/v1/transcribe"

NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=default.target
EOF

echo -e "${GREEN}✓ Service file created${NC}"

# Reload systemd
systemctl --user daemon-reload

# Step 5: Start the service
echo ""
echo "5. Starting vocoder service..."
systemctl --user start vocoder.service

sleep 2

if systemctl --user is-active vocoder.service >/dev/null; then
    echo -e "${GREEN}✓ Vocoder daemon is running${NC}"
else
    echo -e "${RED}✗ Failed to start service${NC}"
    echo "Check logs with: journalctl --user -u vocoder.service -n 50"
    exit 1
fi

# Step 6: Test vocoderctl
echo ""
echo "6. Testing vocoderctl..."
if $PYTHON_CMD bin/vocoderctl status | grep -q "running"; then
    echo -e "${GREEN}✓ vocoderctl working${NC}"
else
    echo -e "${YELLOW}⚠ vocoderctl may not be working${NC}"
fi

# Step 7: Update PATH (optional)
echo ""
echo "7. PATH Setup..."
if [[ ":$PATH:" != *":$PROJECT_DIR/bin:"* ]]; then
    echo "Add to your ~/.bashrc:"
    echo "  export PATH=\"\$PATH:$PROJECT_DIR/bin\""
    echo ""
    echo "Or create symlinks:"
    echo "  sudo ln -sf $PROJECT_DIR/bin/vocoderctl /usr/local/bin/"
else
    echo -e "${GREEN}✓ PATH already includes $PROJECT_DIR/bin${NC}"
fi

# Step 8: Keybinding setup
echo ""
echo "8. Keybinding Configuration..."
echo ""
echo "Option A: Keep Super+Space for Option A (current script)"
echo "Option B: Update Super+Space to use daemon (faster)"
echo "Option C: Use Super+Shift+Space for daemon (test both)"
echo ""
echo "Which option? (A/B/C)"
read -r KEYBIND_CHOICE

KEYBIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vocoder-daemon/"

case "$KEYBIND_CHOICE" in
    B|b)
        # Replace Option A binding
        echo "Updating Super+Space to use daemon..."
        KEYBIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vocoder/"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
            command "$PYTHON_CMD $PROJECT_DIR/bin/vocoderctl toggle"
        echo -e "${GREEN}✓ Super+Space now uses daemon${NC}"
        ;;
    C|c)
        # Add secondary binding
        echo "Adding Super+Shift+Space for daemon..."
        EXISTING=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
        if [[ "$EXISTING" != *"$KEYBIND_PATH"* ]]; then
            if [[ "$EXISTING" == "@as []" ]] || [[ "$EXISTING" == "[]" ]]; then
                NEW="['$KEYBIND_PATH']"
            else
                NEW="${EXISTING%]}, '$KEYBIND_PATH']"
            fi
            gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
        fi
        
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
            name 'Vocoder Daemon'
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
            command "$PYTHON_CMD $PROJECT_DIR/bin/vocoderctl toggle"
        gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
            binding '<Super><Shift>space'
        
        echo -e "${GREEN}✓ Super+Shift+Space triggers daemon${NC}"
        echo -e "${GREEN}✓ Super+Space still uses Option A${NC}"
        ;;
    *)
        echo "Keeping current keybindings unchanged"
        ;;
esac

# Final summary
echo ""
echo "======================================"
echo -e "${GREEN}✅ Option B Setup Complete!${NC}"
echo "======================================"
echo ""
echo "Daemon Status:"
systemctl --user status vocoder.service --no-pager | head -5
echo ""
echo "Usage:"
echo "  • vocoderctl toggle  - Start dictation"
echo "  • vocoderctl status  - Check daemon"
echo "  • vocoderctl stop    - Stop recording"
echo ""
echo "Service Management:"
echo "  • systemctl --user status vocoder.service"
echo "  • systemctl --user restart vocoder.service"
echo "  • systemctl --user stop vocoder.service"
echo ""
echo "To enable on boot:"
echo "  systemctl --user enable vocoder.service"
echo ""
echo "Option A remains available at:"
echo "  $PROJECT_DIR/scripts/whisper-dictate.sh"
echo ""
echo "Test the daemon now with your configured hotkey!"
echo "======================================"