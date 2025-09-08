#!/bin/bash
# One-line installer for vocoder
# Usage: curl -sSL https://github.com/arealicehole/vocoder/raw/main/install.sh | bash

set -euo pipefail

echo "🎤 Vocoder Installer"
echo "==================="

# Detect OS
if [ -f /etc/fedora-release ]; then
    OS="fedora"
    PKG_MGR="dnf"
    AUDIO_PKG="portaudio-devel"
elif [ -f /etc/debian_version ]; then
    OS="debian"
    PKG_MGR="apt"
    AUDIO_PKG="portaudio19-dev"
else
    echo "❌ Unsupported OS. Manual installation required."
    exit 1
fi

echo "📦 Installing system dependencies..."
sudo $PKG_MGR install -y $AUDIO_PKG python3-pip python3-venv

# Clone or update repo
INSTALL_DIR="$HOME/.local/share/vocoder"
if [ -d "$INSTALL_DIR" ]; then
    echo "📂 Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "📂 Cloning vocoder..."
    git clone https://github.com/arealicehole/vocoder.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Setup virtual environment
echo "🐍 Setting up Python environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.lock

# Create user bin links
echo "🔗 Creating command links..."
mkdir -p ~/.local/bin
ln -sf "$INSTALL_DIR/venv/bin/python" ~/.local/bin/vocoder-python
cat > ~/.local/bin/vocoder <<EOF
#!/bin/bash
exec ~/.local/bin/vocoder-python $INSTALL_DIR/bin/vocoder "\$@"
EOF
cat > ~/.local/bin/vocoderctl <<EOF
#!/bin/bash
exec ~/.local/bin/vocoder-python $INSTALL_DIR/bin/vocoderctl "\$@"
EOF
chmod +x ~/.local/bin/vocoder ~/.local/bin/vocoderctl

# Setup systemd service
echo "⚙️ Setting up systemd service..."
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/vocoder.service <<EOF
[Unit]
Description=Vocoder Daemon
After=network.target

[Service]
Type=simple
ExecStart=$HOME/.local/bin/vocoder
Restart=on-failure
Environment="WHISPER_URL=http://127.0.0.1:8771/v1/transcribe"
Environment="CLIPBOARD_MODE=true"

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable vocoder.service
systemctl --user start vocoder.service

# Setup hotkey (GNOME)
if command -v gsettings &> /dev/null; then
    echo "⌨️ Setting up Super+Space hotkey..."
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name 'Vocoder'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "$HOME/.local/bin/vocoderctl toggle"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>space'
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Commands available:"
echo "  vocoderctl status  - Check daemon status"
echo "  vocoderctl toggle  - Start/stop recording"
echo ""
echo "Hotkey: Super+Space (if using GNOME)"
echo ""
echo "⚠️  Make sure Whisper API is running on port 8771"