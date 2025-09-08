# Configuration Guide

Customize Vocoder to work perfectly with your setup.

## Configuration File

Main configuration file: `config/vocoder.yaml`

```yaml
# Whisper API Settings
whisper_url: "http://127.0.0.1:8771/v1/transcribe"

# Audio Settings
audio:
  sample_rate: 16000  # Hz
  channels: 1         # Mono
  gain_db: 15.0      # Microphone boost

# Silence Detection
silence:
  start_threshold: 0.5  # Seconds of speech to start
  stop_threshold: 2.0   # Seconds of silence to stop
  amplitude: 0.02       # Volume threshold (2%)

# Recording
max_duration: 30  # Maximum seconds

# Typing Tools
typing_tools:
  - ydotool  # Preferred for GNOME/Wayland
  - wtype    # Fallback option

# IPC Socket
socket_path: "/run/user/1000/vocoder.sock"
```

## Audio Settings

### Microphone Gain

Adjust `gain_db` based on your microphone:
- **Built-in laptop mic**: 10-15 dB
- **USB microphone**: 0-10 dB
- **DJI MIC MINI**: 15-20 dB (recommended: 15)
- **Headset**: 5-10 dB

Test different values:
```bash
# Edit config/vocoder.yaml
# Change gain_db value
# Test recording
./scripts/whisper-dictate.sh
```

### Sample Rate

- **16000 Hz**: Default, good quality/size balance
- **8000 Hz**: Lower quality, faster processing
- **22050 Hz**: Higher quality, larger files

## Silence Detection

### Adjusting Thresholds

```yaml
silence:
  start_threshold: 0.5  # Decrease for quicker start
  stop_threshold: 2.0   # Increase to avoid cutting off
  amplitude: 0.02       # Decrease for quieter environments
```

**For noisy environments:**
```yaml
silence:
  start_threshold: 1.0  # Wait longer to confirm speech
  stop_threshold: 1.5   # Stop sooner
  amplitude: 0.05       # Higher threshold (5%)
```

**For quiet environments:**
```yaml
silence:
  start_threshold: 0.3  # Start quickly
  stop_threshold: 3.0   # Wait longer before stopping
  amplitude: 0.01       # Lower threshold (1%)
```

## Whisper Model Selection

### Option A (Script Mode)

Edit `scripts/whisper-dictate.sh` line ~100:
```bash
-F "model=tiny"  # Options: tiny, base, small, medium, large
```

### Option B (Daemon Mode)

Edit `bin/vocoder` line ~202:
```python
'model': 'tiny'  # Options: tiny, base, small, medium, large
```

### Model Comparison

| Model  | Speed  | Accuracy | Memory | Use Case |
|--------|--------|----------|--------|----------|
| tiny   | <1s    | Good     | ~39MB  | Default, real-time |
| base   | ~1s    | Better   | ~74MB  | Balanced |
| small  | ~2s    | Great    | ~244MB | Accuracy focus |
| medium | ~5s    | Excellent| ~769MB | Professional |
| large  | ~10s   | Best     | ~1550MB| Maximum accuracy |

## Environment Variables

Override settings without editing files:

```bash
# Change Whisper URL
WHISPER_URL="http://192.168.1.100:8771/v1/transcribe" ./scripts/whisper-dictate.sh

# For daemon mode
WHISPER_URL="http://192.168.1.100:8771/v1/transcribe" python3 bin/vocoder

# Custom temp directory
XDG_RUNTIME_DIR="/custom/tmp" ./scripts/whisper-dictate.sh
```

## Hotkey Configuration

### Change Hotkey Binding

Default: `Super+Space` (Windows key + Space)

To change to `Super+V`:
```bash
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>v'
```

Common options:
- `<Super>space` - Windows key + Space
- `<Super>v` - Windows key + V
- `<Alt>space` - Alt + Space
- `<Ctrl><Alt>d` - Ctrl + Alt + D

### Multiple Hotkeys

Set up different keys for different modes:
```bash
# Custom0: Option A (script)
# Custom1: Option B (daemon)
# Configure separately in GNOME Settings
```

## Language Settings

### Change Recognition Language

```yaml
# In scripts or config files
language: "en"  # English (default)
```

Common language codes:
- `en` - English
- `es` - Spanish
- `fr` - French
- `de` - German
- `zh` - Chinese
- `ja` - Japanese

### Multi-language Support

For automatic language detection, omit the language parameter or set to `auto`.

## Advanced Settings

### Custom Socket Path

For multi-user systems:
```yaml
socket_path: "/run/user/${UID}/vocoder.sock"
```

### Typing Tool Priority

```yaml
typing_tools:
  - wtype     # For sway/wlroots
  - ydotool   # For GNOME
  - xdotool   # For X11 (fallback)
```

### Network Configuration

For remote Whisper server:
```yaml
whisper_url: "https://whisper.example.com:8443/v1/transcribe"
```

With authentication:
```bash
# Set in environment
export WHISPER_API_KEY="your-api-key"
```

## Performance Tuning

### For Fast Response

```yaml
audio:
  sample_rate: 8000  # Lower quality, faster
silence:
  start_threshold: 0.3  # Start quickly
max_duration: 10  # Shorter max recording
```

### For Best Accuracy

```yaml
audio:
  sample_rate: 22050  # Higher quality
  gain_db: 10.0  # Moderate gain
silence:
  stop_threshold: 3.0  # Don't cut off
```

## Applying Changes

### Option A (Script Mode)
Changes take effect immediately on next use.

### Option B (Daemon Mode)
Restart the service after changes:
```bash
systemctl --user restart vocoder.service
```

## Backup Configuration

Save your working configuration:
```bash
cp config/vocoder.yaml config/vocoder.yaml.backup
```

## Reset to Defaults

```bash
git checkout -- config/vocoder.yaml
```