# Vocoder Command Reference

## 🎯 Primary Commands

### Voice Dictation (depends on your setup)
```bash
# Option A - Direct script (current)
/home/ice/dev/vocoder/scripts/whisper-dictate.sh

# Option B - Via daemon (if configured)
vocoderctl toggle       # Start/stop recording
vocoderctl start        # Start recording
vocoderctl stop         # Stop recording
vocoderctl status       # Check daemon status
vocoderctl shutdown     # Stop daemon
```

## 🔧 Setup & Configuration Commands

### Initial Setup
```bash
# Option A (already done)
./scripts/setup-keybinding.sh

# Option B daemon setup
./scripts/setup-option-b.sh
  # Options when running:
  # - Install deps system-wide (s) or venv (v)
  # - Keybinding: Keep A (A), Replace with B (B), Both on different keys (C)
```

### Check Current Status
```bash
# See which option is active
./scripts/check-status.sh

# Check which Whisper model is configured
./scripts/check-model.sh

# Test Option B components
./scripts/test-option-b.sh

# Check dependencies
./scripts/check-dependencies.sh
```

## ⚙️ Systemd Service Management

### Option B Daemon Control
```bash
# Start/stop/restart daemon
systemctl --user start vocoder.service
systemctl --user stop vocoder.service
systemctl --user restart vocoder.service

# Check status
systemctl --user status vocoder.service

# View logs
journalctl --user -u vocoder.service -f        # Follow logs
journalctl --user -u vocoder.service -n 50     # Last 50 lines
journalctl --user -u vocoder.service --since "5 min ago"

# Enable/disable auto-start on boot
systemctl --user enable vocoder.service
systemctl --user disable vocoder.service

# Reload service file after editing
systemctl --user daemon-reload
```

### Other Required Services
```bash
# ydotool daemon (for typing)
systemctl --user start ydotoold
systemctl --user status ydotoold

# Whisper API (your local service)
systemctl --user status whisper-api.service
```

## 🎨 Adjustable Settings

### Option A Settings (edit `/home/ice/dev/vocoder/scripts/whisper-dictate.sh`)
```bash
# Line 5: Whisper API URL
WHISPER_URL="${WHISPER_URL:-http://127.0.0.1:8765/v1/transcribe}"

# Line 8: Max recording duration
MAX_DURATION=30

# Line 9-11: Silence detection
SILENCE_START="0.5"    # Seconds of speech to start recording
SILENCE_STOP="2.0"     # Seconds of silence to stop recording
SILENCE_THRESHOLD="2%" # Volume threshold

# Line 63: Audio gain
gain +15  # Boost for DJI MIC MINI

# Line 99: Whisper model
-F "model=tiny"  # Options: tiny, base, small, medium, large

# Line 96-98: Language and format
-F "language=en"    # Language code
-F "format=json"    # Response format
-F "diarize=false"  # Speaker diarization
```

### Option B Settings (edit `config/vocoder.yaml`)
```yaml
# Whisper API
whisper_url: "http://127.0.0.1:8765/v1/transcribe"

# Audio Settings
audio:
  sample_rate: 16000
  channels: 1
  gain_db: 15.0  # Microphone boost in dB

# Silence Detection
silence:
  start_threshold: 0.5  # Seconds to start
  stop_threshold: 2.0   # Seconds to stop
  amplitude: 0.02       # 2% volume threshold

# Recording
max_duration: 30  # Maximum seconds

# Typing Tool Preference
typing_tools:
  - ydotool  # Preferred for GNOME
  - wtype    # Fallback

# IPC Socket
socket_path: "/run/user/1000/vocoder.sock"
```

**After editing Option B config:**
```bash
systemctl --user restart vocoder.service
```

### Option B Model Setting (edit `bin/vocoder` line 202)
```python
'model': 'tiny'  # Options: tiny, base, small, medium, large
```

## 🔄 Switching Between Options

### Use Option B (faster daemon)
```bash
# One-line switch
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "python3 /home/ice/dev/vocoder/bin/vocoderctl toggle"
```

### Use Option A (reliable script)
```bash
# One-line switch back
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "/home/ice/dev/vocoder/scripts/whisper-dictate.sh"
```

### Check current binding
```bash
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command
```

## 🔍 Debugging Commands

### Audio Diagnostics
```bash
# Comprehensive audio debugging (recommended first step)
./scripts/diagnose-audio-issues.py

# Quick audio debug
./scripts/debug-audio.sh

# Manual tests
rec test.wav gain +15 silence 1 0.5 2% 1 2.0 2% trim 0 5
timeout 3s arecord -f cd /tmp/test-alsa.wav
timeout 3s parec --channels=1 /tmp/test-pulse.wav
```

### Audio Device Management  
```bash
# List audio sources (inputs)
pactl list sources short

# Set correct default source (NOT monitor)
pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo

# Check current default
pactl info | grep "Default Source"

# Open audio mixer
alsamixer  # Press F6 for sound card, F5 for all controls

# Unmute microphone
pactl set-source-mute @DEFAULT_SOURCE@ false
pactl set-source-volume @DEFAULT_SOURCE@ 100%
```

### Test Recording
```bash
# Test Whisper API
curl -X POST -F "file=@test.wav" -F "format=json" -F "language=en" -F "model=tiny" http://127.0.0.1:8765/v1/transcribe

# Test typing tool
echo "test" | ydotool type --file -
```

### Check Process Status
```bash
# Check if daemon is running
pgrep -f "bin/vocoder"

# Check ydotoold
pgrep ydotoold

# Check socket
ls -la /run/user/$(id -u)/vocoder.sock
```

### Manual Testing
```bash
# Test Option A directly
/home/ice/dev/vocoder/scripts/whisper-dictate.sh

# Test Option B daemon manually
python3 /home/ice/dev/vocoder/bin/vocoder

# Test Option B client
python3 /home/ice/dev/vocoder/bin/vocoderctl toggle
```

## 📊 Performance Monitoring

### Check daemon resource usage
```bash
# CPU and memory
systemctl --user status vocoder.service

# Detailed stats
ps aux | grep vocoder

# Socket stats
ss -x | grep vocoder
```

### Measure response times
```bash
# Time Option A
time /home/ice/dev/vocoder/scripts/whisper-dictate.sh

# Time Option B
time python3 /home/ice/dev/vocoder/bin/vocoderctl toggle
```

## 🚀 Quick Actions

### Emergency Stop Recording
```bash
# Kill any recording process
pkill -f rec
pkill -f vocoder

# Or for Option B
vocoderctl stop
```

### Reset Everything
```bash
# Stop daemon
systemctl --user stop vocoder.service

# Clear socket
rm -f /run/user/$(id -u)/vocoder.sock

# Restart
systemctl --user start vocoder.service
```

### Update PATH (to use vocoderctl anywhere)
```bash
# Add to ~/.bashrc
export PATH="$PATH:/home/ice/dev/vocoder/bin"

# Or create symlink
sudo ln -sf /home/ice/dev/vocoder/bin/vocoderctl /usr/local/bin/
```

## 📝 Environment Variables

### Option A
```bash
WHISPER_URL="http://192.168.1.100:8765/v1/transcribe" ./scripts/whisper-dictate.sh
XDG_RUNTIME_DIR="/custom/tmp" ./scripts/whisper-dictate.sh
```

### Option B
```bash
WHISPER_URL="http://192.168.1.100:8765/v1/transcribe" python3 bin/vocoder
PYTHONUNBUFFERED=1 python3 bin/vocoder  # For better logging
```

## 🎛️ Advanced Tweaks

### Change hotkey binding
```bash
# Current: Super+Space
# Change to Super+V:
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>v'
```

### Adjust notification timeout
```bash
# In whisper-dictate.sh, change -t parameter
notify-send "Vocoder" "Recording..." -t 2000  # 2 seconds
```

### Change audio device
```bash
# List devices
pactl list sources short

# Set default
pactl set-default-source <device_name>
```

## 📚 File Locations

```
/home/ice/dev/vocoder/
├── scripts/
│   ├── whisper-dictate.sh     # Option A main script
│   ├── check-status.sh        # Status checker
│   ├── check-model.sh         # Model checker
│   ├── test-option-b.sh       # Option B tester
│   └── setup-option-b.sh      # Option B installer
├── bin/
│   ├── vocoder                # Option B daemon
│   └── vocoderctl             # Option B client
├── config/
│   └── vocoder.yaml           # Option B config
├── daemon/
│   └── vocoder.service        # Systemd service
└── COMMANDS.md                # This file
```

## 💡 Tips

1. **For fastest response**: Use Option B with tiny model
2. **For reliability**: Keep Option A as fallback
3. **For accuracy**: Switch to base or small model
4. **For debugging**: Check journalctl logs first
5. **For different mics**: Adjust gain_db in config