# Troubleshooting Guide

Solutions for common Vocoder issues.

## Quick Fixes

### 🚨 Emergency: No Text Appears

1. **Check Whisper API**
   ```bash
   curl http://127.0.0.1:8771/health
   # Should return: {"status":"ok"}
   ```

2. **Check ydotool daemon**
   ```bash
   pgrep ydotoold || sudo ydotoold &
   ```

3. **Try manual test**
   ```bash
   ./scripts/whisper-dictate.sh
   ```

### 🔇 Recording Silence

**Most Common Cause**: Recording from monitor instead of microphone

**Immediate Fix**:
```bash
# While recording, open:
pavucontrol
# Go to "Recording" tab
# Select your actual microphone (NOT "Monitor of...")
```

**Command Line Fix**:
```bash
# List sources
pactl list sources short

# Set correct microphone (replace with your device)
pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo

# NOT this (monitor):
# alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
```

### 🎤 Microphone Too Quiet

```bash
# Unmute microphone
pactl set-source-mute @DEFAULT_SOURCE@ false

# Set volume to 100%
pactl set-source-volume @DEFAULT_SOURCE@ 100%

# Adjust in config/vocoder.yaml
# Increase gain_db: 15.0 → 20.0
```

## Audio Issues

### Run Automatic Diagnostic

```bash
cd /home/ice/dev/vocoder
python3 scripts/diagnose-audio-issues.py
```

### Manual Audio Tests

```bash
# Test ALSA
timeout 3s arecord -f cd /tmp/test.wav && echo "✓ ALSA works"

# Test PulseAudio
timeout 3s parec --channels=1 /tmp/test2.wav && echo "✓ PulseAudio works"

# Test with gain
rec test.wav gain +15 silence 1 0.5 2% 1 2.0 2% trim 0 5
```

### Fix Monitor/Loopback Issue

Monitor sources capture system audio instead of microphone:

```bash
# Find real microphone (not monitor)
pactl list sources short | grep -v monitor

# Example output:
# 0  alsa_output.pci-0000_00_1f.3.analog-stereo.monitor  (SKIP THIS)
# 1  alsa_input.pci-0000_00_1f.3.analog-stereo           (USE THIS)

# Set as default
pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo
```

### Reset Audio System

```bash
# Restart PulseAudio
pulseaudio -k && pulseaudio --start

# Reset ALSA
sudo alsa force-reload

# Check status
pulseaudio --check && echo "✓ PulseAudio OK"
```

## Hotkey Issues

### Hotkey Doesn't Work

1. **Check current binding**:
   ```bash
   gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command
   ```

2. **Reset to Option A**:
   ```bash
   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "/home/ice/dev/vocoder/scripts/whisper-dictate.sh"
   ```

3. **Or reset to Option B**:
   ```bash
   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "python3 /home/ice/dev/vocoder/bin/vocoderctl toggle"
   ```

### Hotkey Conflicts

Change to different key combination:
```bash
# Change to Super+V
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding '<Super>v'
```

## Daemon Issues (Option B)

### Daemon Won't Start

```bash
# Check status
systemctl --user status vocoder.service

# View logs
journalctl --user -u vocoder.service -n 50

# Restart service
systemctl --user restart vocoder.service

# Reload if service file changed
systemctl --user daemon-reload
```

### Socket Errors

```bash
# Check socket exists
ls -la /run/user/$(id -u)/vocoder.sock

# Remove stale socket
rm -f /run/user/$(id -u)/vocoder.sock

# Restart daemon
systemctl --user restart vocoder.service
```

## Typing Issues

### Text Won't Type

1. **Check ydotool**:
   ```bash
   # Is it running?
   pgrep ydotoold
   
   # Start if needed
   sudo ydotoold &
   
   # Test typing
   echo "test" | ydotool type --file -
   ```

2. **Fallback to clipboard**:
   - Text is copied if typing fails
   - Press Ctrl+V to paste

### Wrong Window Gets Text

- Ensure target window has focus before pressing hotkey
- Some applications may need click-to-focus

## Performance Issues

### Slow Response

1. **Switch to tiny model**:
   ```bash
   # Edit scripts/whisper-dictate.sh or bin/vocoder
   # Change model to 'tiny'
   ```

2. **Use daemon mode** for instant response:
   ```bash
   systemctl --user enable --now vocoder.service
   ```

3. **Reduce sample rate** in config:
   ```yaml
   audio:
     sample_rate: 8000  # Faster processing
   ```

### High CPU Usage

```bash
# Check daemon usage
systemctl --user status vocoder.service

# Limit CPU in service file
# Edit daemon/vocoder.service
CPUQuota=30%  # Limit to 30% CPU
```

## Network Issues

### Remote Whisper Server

```bash
# Test connection
curl http://192.168.1.100:8771/health

# Use with environment variable
WHISPER_URL="http://192.168.1.100:8771/v1/transcribe" ./scripts/whisper-dictate.sh
```

### Firewall Blocking

```bash
# Open port for Whisper
sudo firewall-cmd --add-port=8771/tcp --permanent
sudo firewall-cmd --reload
```

## Hardware Issues

### USB Microphone Not Detected

```bash
# List USB devices
lsusb | grep -i audio

# Check if recognized
arecord -l

# Try different USB port
# Disconnect and reconnect
```

### Built-in Microphone Not Working

```bash
# Check ALSA
alsamixer
# Press F6 → Select sound card
# Press F5 → Check "Input Source"
# Set to "Internal Mic"
```

## Debug Information

### Collect System Info

When reporting issues, run:
```bash
echo "=== AUDIO DEVICES ==="
pactl list sources short
echo "=== DEFAULT SOURCE ==="
pactl info | grep "Default Source"
echo "=== VOCODER STATUS ==="
./scripts/check-status.sh
echo "=== PYTHON CHECK ==="
python3 -c "import sounddevice; print(sounddevice.query_devices())"
```

### Enable Debug Logging

```bash
# For daemon mode
PYTHONUNBUFFERED=1 python3 bin/vocoder

# View detailed logs
journalctl --user -u vocoder.service -f
```

## Common Error Messages

### "No module named 'sounddevice'"
```bash
pip install sounddevice numpy
```

### "PortAudio library not found"
```bash
# Fedora
sudo dnf install portaudio portaudio-devel

# Ubuntu
sudo apt install portaudio19-dev
```

### "Permission denied"
```bash
# Add user to audio group
sudo usermod -a -G audio $USER
# Log out and back in
```

## Still Not Working?

1. **Try the automated diagnostic**:
   ```bash
   python3 scripts/diagnose-audio-issues.py
   ```

2. **Check physical connections**:
   - USB cable secure
   - 3.5mm jack fully inserted
   - Microphone not muted (physical switch)

3. **Test on another application**:
   - Open Sound Recorder
   - Try recording
   - If this fails, it's a system issue

4. **Get help**:
   - Run debug info collection above
   - Check [GitHub Issues](https://github.com/arealicehole/vocoder/issues)
   - Include debug output in your report