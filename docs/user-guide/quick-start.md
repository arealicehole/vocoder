# Quick Start Guide

Get voice dictation working in 5 minutes with Vocoder.

## Prerequisites

Before starting, ensure you have:
- Linux system with PulseAudio/ALSA
- Whisper API service running on port 8771
- Microphone connected and working

## Installation

### One-Line Install

```bash
curl -sSL https://raw.githubusercontent.com/arealicehole/vocoder/main/install.sh | bash
```

### Manual Install

```bash
# Clone repository
git clone https://github.com/arealicehole/vocoder.git
cd vocoder

# Install dependencies
sudo dnf install sox ydotool portaudio  # Fedora
sudo apt install sox ydotool portaudio19-dev  # Ubuntu

# Run installer
./install.sh
```

## First Use

### 1. Test Your Setup

```bash
# Check system status
./scripts/check-status.sh

# Test microphone recording
./scripts/whisper-dictate.sh
```

### 2. Using the Hotkey

1. **Focus any text field** (browser, editor, terminal)
2. **Press Super+Space** (Windows key + Space)
3. **Speak clearly** when you see "Recording..."
4. **Stop speaking** - auto-stops after 2 seconds of silence
5. **Text appears** at your cursor position

## Choose Your Mode

### Option A: Simple Script (Default)
- **Pros**: Reliable, simple to debug
- **Cons**: 1-2 second startup delay
- **Best for**: Occasional use

### Option B: Daemon Mode (Advanced)
- **Pros**: Instant response (<50ms)
- **Cons**: Uses more memory
- **Best for**: Frequent use

To switch to daemon mode:
```bash
# Start daemon
systemctl --user enable --now vocoder.service

# Switch hotkey to daemon
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "python3 /home/ice/dev/vocoder/bin/vocoderctl toggle"
```

## Common Commands

```bash
# Test dictation
./scripts/whisper-dictate.sh

# Check status
./scripts/check-status.sh

# For daemon mode
vocoderctl toggle    # Start/stop recording
vocoderctl status    # Check daemon
```

## Quick Troubleshooting

### No text appears?
```bash
# Check Whisper API
curl http://127.0.0.1:8771/health

# Check ydotool daemon
pgrep ydotoold || sudo ydotoold &
```

### Recording silence?
```bash
# Use GUI tool while recording
pavucontrol
# Go to Recording tab → Select actual microphone (NOT "Monitor of...")
```

### Text in wrong place?
- Text is copied to clipboard if typing fails
- Press Ctrl+V to paste

## Next Steps

- [Configuration Guide](configuration.md) - Customize settings
- [Troubleshooting Guide](troubleshooting.md) - Detailed fixes
- [COMMANDS.md](../../COMMANDS.md) - All available commands

## Getting Help

- Check `journalctl --user -u vocoder -n 50` for daemon logs
- Run `./scripts/diagnose-audio-issues.py` for audio debugging
- See [Troubleshooting Guide](troubleshooting.md) for detailed solutions