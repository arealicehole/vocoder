# Vocoder - Voice Dictation System

## 🎉 Production Ready!

A hotkey-triggered voice dictation system for Linux with two implementation options:

### Option A - Simple Script (Default)
- **Status**: Production ready, bound to Super+Space
- **Response Time**: 1-2 seconds startup
- **Dependencies**: sox, ydotool, curl

### Option B - Daemon Architecture  
- **Status**: Fully implemented with toggle support
- **Response Time**: < 50ms instant response
- **Features**: Persistent Whisper connection, toggle mode
- **Dependencies**: PortAudio, Python (numpy, sounddevice, httpx)

## Features

- **Hotkey Activation**: Press Super+Space to start dictation
- **Local Transcription**: Uses Whisper API running on localhost
- **Direct Typing**: Types text where your cursor is focused
- **Wayland Support**: Works with ydotool on GNOME/Wayland
- **Silence Detection**: Auto-stops after 2 seconds of silence
- **Clipboard Fallback**: Copies to clipboard if typing fails

## Quick Start

```bash
# Check system status
./scripts/check-status.sh

# Test dictation
./scripts/whisper-dictate.sh

# Use hotkey
Press Super+Space, speak, wait for auto-stop
```

## Installation

### Prerequisites

```bash
# Fedora/RHEL
sudo dnf install sox ydotool curl jq

# For Option B (daemon)
sudo dnf install portaudio portaudio-devel
pip install numpy sounddevice httpx
```

### Setup Whisper API

Requires a separate Whisper API service running on port 8767.
See whisper-api documentation for setup.

## Usage

### Option A: Simple Script (Current Default)

1. **Focus on any text field** (browser, editor, terminal, etc.)
2. **Press Super + Space**
3. **Speak when you see the notification** "Recording... (speak now)"
4. **Stop speaking** - it auto-detects silence after 2 seconds
5. **Text appears** where your cursor was

### Option B: Daemon Control
```bash
# Switch hotkey to daemon mode
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "python3 /home/ice/dev/vocoder/bin/vocoderctl toggle"

# Manual daemon control
python3 bin/vocoderctl toggle    # Toggle recording
python3 bin/vocoderctl start     # Start recording
python3 bin/vocoderctl stop      # Stop recording
```

### Manual Testing

```bash
# Test Option A (script)
./scripts/whisper-dictate.sh

# Test Option B (daemon)
python3 bin/vocoderctl toggle

# Check system status
./scripts/check-status.sh
```

## Configuration

- **Whisper Model**: tiny (fast and accurate)
- **Audio**: 16kHz mono with +15dB gain
- **Silence Detection**: 2 seconds threshold
- **API Port**: 8767
- **Max Recording**: 30 seconds

## File Structure

```
vocoder/
├── scripts/
│   ├── whisper-dictate.sh    # Main dictation script
│   ├── check-status.sh       # System status check
│   └── setup-option-b.sh     # Daemon setup
├── bin/
│   ├── vocoder               # Python daemon
│   └── vocoderctl            # Control client
├── config/
│   └── vocoder.yaml          # Configuration
└── daemon/
    └── vocoder.service       # systemd service
```


## Troubleshooting

- **No dictation**: Check Whisper API: `curl http://127.0.0.1:8767/health`
- **Text won't type**: Ensure ydotoold is running: `pgrep ydotoold`
- **No recording**: Test mic: `rec test.wav`
- **Clipboard fallback**: Text copies to clipboard if typing fails (Ctrl+V to paste)

## License

MIT

