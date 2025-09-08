# Quick Audio Fixes - Emergency Reference Card

## 🚨 IMMEDIATE FIXES FOR SILENT RECORDING

### 1. Check if recording from monitor instead of microphone
```bash
# While your app is recording, run:
pavucontrol
# Go to "Recording" tab → Select your actual microphone (NOT "Monitor of...")
```

### 2. Fix PulseAudio default source
```bash
# List sources
pactl list sources short

# Set real microphone as default (replace with your actual mic)
pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo

# NOT this (monitor source):
# alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
```

### 3. Unmute and boost microphone
```bash
# Unmute microphone
pactl set-source-mute @DEFAULT_SOURCE@ false

# Set volume to 100%
pactl set-source-volume @DEFAULT_SOURCE@ 100%

# Check levels in alsamixer
alsamixer
# Press F6 → Select sound card → F5 → Find "Input Source" → Set to microphone
```

## 🔍 QUICK DIAGNOSTICS

### Run the automated diagnostic
```bash
cd /home/ice/dev/vocoder
python3 scripts/diagnose-audio-issues.py
```

### Manual checks
```bash
# 1. Is PulseAudio running?
pulseaudio --check && echo "OK" || echo "RESTART NEEDED"

# 2. List input devices  
pactl list sources short | grep -v monitor

# 3. Test recording
timeout 3s arecord -f cd /tmp/test.wav && echo "ALSA works"
timeout 3s parec --channels=1 /tmp/test2.wav && echo "PulseAudio works"
```

## 🐍 PYTHON SOUNDDEVICE FIXES

### Quick device check
```python
import sounddevice as sd

# List all devices
print(sd.query_devices())

# Find input devices (avoid monitors)
devices = sd.query_devices()
for i, d in enumerate(devices):
    if d['max_input_channels'] > 0 and 'monitor' not in d['name'].lower():
        print(f"ID {i}: {d['name']}")

# Set specific device
sd.default.device = DEVICE_ID  # Replace with actual ID
```

### Test recording
```python
import sounddevice as sd
import numpy as np

# Record 3 seconds
audio = sd.rec(48000, samplerate=16000, channels=1)
sd.wait()

# Check if silent
max_amp = np.max(np.abs(audio))
print(f"Max amplitude: {max_amp}")

if max_amp < 1e-6:
    print("SILENT - Check device selection!")
elif max_amp < 0.01:
    print("LOW - Need more gain")
else:
    print("GOOD")
```

## ⚡ ONE-LINE FIXES

```bash
# Restart PulseAudio
pulseaudio -k && pulseaudio --start

# Reset ALSA
sudo alsa force-reload

# Kill any stuck audio processes
pkill -f "rec\|parec\|arecord"

# Add user to audio group (requires logout)
sudo usermod -a -G audio $USER

# Test if microphone is physically working
speaker-test -t wav -c 1 & sleep 2; pkill speaker-test
```

## 🎯 VOCODER-SPECIFIC FIXES

### Update vocoder with better device selection
Add this to your vocoder's AudioRecorder.__init__():

```python
def find_best_microphone(self):
    """Find non-monitor input device"""
    devices = sd.query_devices()
    for i, device in enumerate(devices):
        if (device['max_input_channels'] > 0 and 
            'monitor' not in device['name'].lower() and
            'loopback' not in device['name'].lower()):
            return i
    return None

# Use it:
mic_id = self.find_best_microphone()
if mic_id is not None:
    sd.default.device = mic_id
```

### Test your current vocoder setup
```bash
cd /home/ice/dev/vocoder

# Check current status
./scripts/check-status.sh

# Test recording (Option A)
timeout 5s ./scripts/whisper-dictate.sh

# Test daemon (Option B)
systemctl --user status vocoder.service
python3 bin/vocoderctl status
```

## 🔧 HARDWARE TROUBLESHOOTING

```bash
# Check sound cards
cat /proc/asound/cards

# Check USB devices (for USB mics)
lsusb | grep -i audio

# Check if microphone is detected
arecord -l

# Check PulseAudio modules
pactl list modules | grep -E "(alsa|udev)"
```

## 📋 PRIORITY ORDER FOR FIXING ISSUES

1. **First**: Use pavucontrol while recording to check input device
2. **Second**: Ensure default source isn't a monitor: `pactl info | grep "Default Source"`
3. **Third**: Test with system tools: `arecord` and `parec`
4. **Fourth**: Check microphone levels in `alsamixer`
5. **Fifth**: Restart PulseAudio: `pulseaudio -k && pulseaudio --start`
6. **Last Resort**: Check hardware connections and drivers

## 🆘 WHEN NOTHING WORKS

1. **Check physical connections**: USB plugged in, 3.5mm jack fully inserted
2. **Try different USB ports** (for USB mics)
3. **Test microphone on another computer** to verify it works
4. **Check BIOS settings** for built-in microphones
5. **Look for hardware mute switches** on laptop/microphone
6. **Check if privacy settings** are blocking microphone access
7. **Install different audio driver** if using proprietary hardware

## 📞 GET HELP

Post this information when asking for help:
```bash
# Run this and share the output:
echo "=== SYSTEM INFO ===" 
uname -a
echo "=== AUDIO CARDS ===" 
cat /proc/asound/cards
echo "=== PULSEAUDIO SOURCES ==="
pactl list sources short
echo "=== DEFAULT SOURCE ==="
pactl info | grep "Default Source"
echo "=== PYTHON TEST ==="
python3 -c "import sounddevice as sd; print('Devices:'); [print(f'{i}: {d[\"name\"]} (in:{d[\"max_input_channels\"]})') for i,d in enumerate(sd.query_devices()) if d['max_input_channels']>0]"
```