name: "Vocoder Voice Dictation Debugging and Fix"
description: |
  Comprehensive PRP for diagnosing and fixing the vocoder voice dictation system that currently:
  - Toggles on with hotkey but stops arbitrarily regardless of audio input
  - Only pastes the prompt text instead of actual transcription
  - Not capturing audio or transcribing properly
  
  This PRP provides complete context for one-pass implementation success including audio system debugging,
  Whisper API integration fixes, and ydotool typing mechanism corrections.

---

## Goal

**Feature Goal**: Fix the vocoder daemon to properly capture audio, transcribe via Whisper API, and type the resulting text

**Deliverable**: 
- Fixed `/home/ice/dev/vocoder/bin/vocoder` daemon with proper audio capture
- Diagnostic script `/home/ice/dev/vocoder/scripts/diagnose-vocoder.py`
- Updated configuration with correct defaults
- Working hotkey-triggered voice dictation

**Success Definition**: 
- Super+Space hotkey starts recording
- Audio is properly captured from microphone (not monitor)
- Recording stops after 2 seconds of silence or max duration
- Transcription is sent to Whisper API on port 8771
- Transcribed text is typed at cursor position
- All errors are properly logged and visible

## User Persona

**Target User**: Developer using Fedora Linux with GNOME/Wayland, running Whisper API via Docker on port 8771

**Use Case**: Press Super+Space hotkey, speak naturally, have text automatically typed where cursor is focused

**User Journey**: 
1. User presses Super+Space hotkey
2. Recording notification appears and audio capture begins
3. User speaks their message
4. After 2 seconds of silence, recording stops automatically
5. Transcription happens via Whisper API
6. Text appears at cursor position

## Why

Current implementation has multiple critical failures:
- Audio device selection defaults to monitor (system output) instead of microphone
- ydotool typing uses sudo which fails silently without password
- Silence detection may be failing due to NaN RMS calculations
- No proper error visibility or debugging capabilities
- Port configuration mismatches between components

## What

### Functional Requirements

1. **Audio Capture**
   - Must select real microphone, not monitor device
   - Must handle gain properly without distortion
   - Must detect silence reliably
   - Must provide audio level feedback

2. **Whisper Integration**
   - Must use correct port 8771
   - Must handle multipart form data correctly
   - Must use appropriate model size
   - Must handle errors gracefully

3. **Text Typing**
   - Must work without sudo requirement
   - Must handle special characters properly
   - Must provide clipboard fallback
   - Must not add unwanted newlines

4. **Debugging**
   - Must log all errors visibly
   - Must provide diagnostic capabilities
   - Must validate configuration
   - Must test each component independently

### Technical Requirements

- Python 3.x with numpy, sounddevice, httpx
- PulseAudio/PipeWire audio system
- Whisper API running on port 8771
- ydotool or wtype for text input
- systemd user service management

## All Needed Context

### Critical Files to Modify

```yaml
primary_files:
  daemon:
    path: /home/ice/dev/vocoder/bin/vocoder
    issues:
      - Line 42: Hardcoded port 8767 should be 8771
      - Line 48: Silence threshold 0.02 may be too sensitive
      - Line 83-86: RMS calculation can produce NaN
      - Line 108: Audio device selection doesn't exclude monitors
      - Line 289: Uses sudo for ydotool which fails silently
      
  control_client:
    path: /home/ice/dev/vocoder/bin/vocoderctl
    purpose: CLI control interface for daemon
    
  service_file:
    path: /home/ice/.config/systemd/user/vocoder.service
    current_issues:
      - WHISPER_URL environment variable may be wrong
      - Watchdog timeout conflicts with blocking operations

configuration_files:
  yaml_config:
    path: /home/ice/dev/vocoder/config/vocoder.yaml
    whisper_url: "http://127.0.0.1:8771/v1/transcribe"
    
  systemd_env:
    path: ~/.config/systemd/user/vocoder.service.d/override.conf
    purpose: Override environment variables
```

### Whisper API Documentation

Based on https://github.com/arealicehole/whisper-on-fedora/blob/main/README.md:

```yaml
whisper_api:
  endpoint: http://localhost:8771/v1/transcribe
  method: POST
  content_type: multipart/form-data
  
  parameters:
    file: "@audio.wav"  # Required - audio file
    format: "json"      # json (default), text, srt, vtt
    model: "small"      # tiny, base, small (default), medium, large
    language: "en"      # Language code
    diarize: "false"    # Speaker identification
    
  response_json:
    text: "Transcribed text here"
    segments: []
    language: "en"
    duration: 2.5
    
  health_check:
    endpoint: http://localhost:8771/health
    expected:
      status: "healthy"
      gpu_available: true
```

### Audio System Context

```yaml
pulseaudio_issues:
  monitor_vs_microphone:
    problem: "Default source often set to .monitor (output loopback)"
    solution: "Filter devices by name, exclude 'monitor' and 'loopback'"
    
  device_detection:
    correct_source: "alsa_input.pci-0000_2f_00.4.analog-stereo"
    wrong_source: "alsa_output.pci-0000_2f_00.4.analog-stereo.monitor"
    
  commands:
    list_sources: "pactl list short sources"
    set_default: "pactl set-default-source alsa_input.pci-0000_2f_00.4.analog-stereo"
    check_levels: "pactl list sources | grep -A 10 'State: RUNNING'"
```

### ydotool Context

```yaml
ydotool_setup:
  daemon_requirement:
    service: "ydotoold"
    check: "pgrep ydotoold"
    start: "systemctl --user start ydotoold"
    
  usage_pattern:
    correct: 'echo "text" | ydotool type --file -'
    wrong: 'sudo ydotool type --file -'  # Requires password
    
  permissions:
    group: "input"
    check: "groups | grep input"
    add: "sudo usermod -a -G input $USER"
```

## Implementation Blueprint

### Task 1: Fix Audio Device Selection

```python
# In /home/ice/dev/vocoder/bin/vocoder, replace lines 102-119

def start_recording(self):
    """Start recording with proper device selection"""
    logging.info("Starting recording")
    self.recording = True
    self.audio_buffer = []
    self.silence_counter = 0
    
    try:
        # Find proper microphone device (exclude monitors)
        import sounddevice as sd
        devices = sd.query_devices()
        mic_device = None
        
        for i, device in enumerate(devices):
            if (device['max_input_channels'] > 0 and 
                'monitor' not in device['name'].lower() and
                'loopback' not in device['name'].lower()):
                logging.info(f"Found microphone: {device['name']} (device {i})")
                mic_device = i
                break
        
        if mic_device is None:
            # Fallback to default
            logging.warning("No microphone found, using default device")
            mic_device = None
        
        self.stream = sd.InputStream(
            callback=self.audio_callback,
            channels=self.config.channels,
            samplerate=self.config.sample_rate,
            blocksize=1024,
            dtype='float32',
            device=mic_device  # Use selected device
        )
        self.stream.start()
        
        # Verify stream is actually running
        if not self.stream.active:
            raise Exception("Stream failed to start")
        
        # Play start sound and notify
        self.play_sound("start")
        self.notify("Recording... (speak now)", 2000)
        
    except Exception as e:
        logging.error(f"Failed to start recording: {e}")
        self.recording = False
        self.play_sound("error")
        self.notify(f"Recording failed: {str(e)}", 3000)
        raise  # Re-raise to make error visible
```

### Task 2: Fix RMS Calculation

```python
# In /home/ice/dev/vocoder/bin/vocoder, replace lines 80-92

# Silence detection with NaN protection
if len(audio_data) > 0:
    # Calculate RMS with validation
    squared = audio_data ** 2
    mean_squared = np.mean(squared)
    
    # Protect against NaN/inf
    if np.isfinite(mean_squared) and mean_squared >= 0:
        rms = np.sqrt(mean_squared)
    else:
        logging.warning(f"Invalid audio data: mean_squared={mean_squared}")
        rms = 0.0  # Assume silence on error
    
    # Debug logging
    if hasattr(self, '_debug_counter'):
        self._debug_counter += 1
    else:
        self._debug_counter = 0
    
    if self._debug_counter % 30 == 0:  # Log every ~0.5s
        logging.debug(f"Audio RMS: {rms:.4f}, Threshold: {self.config.silence_threshold:.4f}, Silence: {self.silence_counter:.1f}s")
    
    # Adjusted threshold for better detection
    silence_threshold = 0.01  # Lower threshold (was 0.02)
    
    if rms < silence_threshold:
        self.silence_counter += frames / self.config.sample_rate
    else:
        self.silence_counter = 0
else:
    logging.warning("Empty audio buffer")
    self.silence_counter += frames / self.config.sample_rate
```

### Task 3: Fix ydotool Typing

```python
# In /home/ice/dev/vocoder/bin/vocoder, replace lines 287-300

# CRITICAL: Use --file - flag WITHOUT sudo
proc = await asyncio.create_subprocess_exec(
    "ydotool", "type", "--file", "-",  # No sudo!
    stdin=asyncio.subprocess.PIPE,
    stdout=asyncio.subprocess.PIPE,
    stderr=asyncio.subprocess.PIPE
)
# Send text without newline
stdout, stderr = await proc.communicate(text.encode())
success = proc.returncode == 0

if not success:
    logging.error(f"ydotool failed: {stderr.decode()}")
    # Try without --file flag as fallback
    proc2 = await asyncio.create_subprocess_exec(
        "ydotool", "type", text,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE
    )
    stdout2, stderr2 = await proc2.communicate()
    success = proc2.returncode == 0
    
    if not success:
        logging.error(f"ydotool fallback failed: {stderr2.decode()}")
        
return success
```

### Task 4: Fix Configuration

```python
# In /home/ice/dev/vocoder/bin/vocoder, line 42

@dataclass
class Config:
    """Configuration with correct defaults"""
    whisper_url: str = os.environ.get("WHISPER_URL", "http://127.0.0.1:8771/v1/transcribe")
    sample_rate: int = 16000
    channels: int = 1
    audio_gain_db: float = 15.0
    silence_start: float = 0.5
    silence_stop: float = 2.0
    silence_threshold: float = 0.01  # Lowered from 0.02
    max_duration: int = 30
    typing_tool_preference: tuple = ("ydotool", "wtype")
    socket_path: str = f"/run/user/{os.getuid()}/vocoder.sock"
```

### Task 5: Create Diagnostic Script

```python
# Create /home/ice/dev/vocoder/scripts/diagnose-vocoder.py

#!/usr/bin/env python3
"""Vocoder System Diagnostic Tool"""

import os
import sys
import subprocess
import json
import numpy as np
import sounddevice as sd
import httpx
from pathlib import Path

class VocoderDiagnostic:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.info = []
        
    def check_audio_devices(self):
        """Check audio device configuration"""
        print("\n🎤 Checking Audio Devices...")
        
        # Check default source
        result = subprocess.run(['pactl', 'get-default-source'], 
                              capture_output=True, text=True)
        default_source = result.stdout.strip()
        
        if 'monitor' in default_source.lower():
            self.errors.append(f"Default source is monitor (loopback): {default_source}")
            print("  ❌ Default audio source is set to monitor (recording system audio)")
            print(f"     Current: {default_source}")
            
            # Find correct source
            result = subprocess.run(['pactl', 'list', 'short', 'sources'],
                                  capture_output=True, text=True)
            for line in result.stdout.splitlines():
                if 'monitor' not in line.lower() and 'alsa_input' in line:
                    correct_source = line.split()[0]
                    print(f"  ✅ Found correct microphone: {correct_source}")
                    print(f"     Fix: pactl set-default-source {correct_source}")
                    break
        else:
            print(f"  ✅ Default source is microphone: {default_source}")
            
        # Check sounddevice
        try:
            devices = sd.query_devices()
            mic_found = False
            for i, device in enumerate(devices):
                if (device['max_input_channels'] > 0 and 
                    'monitor' not in device['name'].lower()):
                    print(f"  ✅ Found microphone device {i}: {device['name']}")
                    mic_found = True
                    break
            
            if not mic_found:
                self.errors.append("No microphone devices found by sounddevice")
                print("  ❌ sounddevice cannot find any microphone devices")
        except Exception as e:
            self.errors.append(f"sounddevice error: {e}")
            print(f"  ❌ sounddevice error: {e}")
            
    def check_whisper_api(self):
        """Check Whisper API connectivity"""
        print("\n🌐 Checking Whisper API...")
        
        url = "http://127.0.0.1:8771/health"
        try:
            response = httpx.get(url, timeout=5)
            if response.status_code == 200:
                data = response.json()
                print(f"  ✅ Whisper API is healthy on port 8771")
                print(f"     GPU Available: {data.get('gpu_available', 'unknown')}")
                print(f"     Status: {data.get('status', 'unknown')}")
            else:
                self.errors.append(f"Whisper API returned status {response.status_code}")
                print(f"  ❌ Whisper API returned status {response.status_code}")
        except Exception as e:
            self.errors.append(f"Cannot connect to Whisper API: {e}")
            print(f"  ❌ Cannot connect to Whisper API on port 8771")
            print(f"     Error: {e}")
            print("     Is the Docker container running?")
            print("     Check: docker ps | grep whisper")
            
    def check_ydotool(self):
        """Check ydotool setup"""
        print("\n⌨️ Checking ydotool...")
        
        # Check if ydotoold is running
        result = subprocess.run(['pgrep', 'ydotoold'], capture_output=True)
        if result.returncode != 0:
            self.warnings.append("ydotoold daemon not running")
            print("  ⚠️  ydotoold daemon is not running")
            print("     Fix: systemctl --user start ydotoold")
        else:
            print("  ✅ ydotoold daemon is running")
            
        # Check if ydotool works without sudo
        result = subprocess.run(['ydotool', 'version'], capture_output=True)
        if result.returncode != 0:
            self.errors.append("ydotool not working (may need group permissions)")
            print("  ❌ ydotool not working")
            print("     Check if user is in 'input' group:")
            print("     groups | grep input")
            print("     If not: sudo usermod -a -G input $USER")
        else:
            print("  ✅ ydotool is working")
            
    def check_daemon(self):
        """Check vocoder daemon status"""
        print("\n🔧 Checking Vocoder Daemon...")
        
        # Check systemd service
        result = subprocess.run(['systemctl', '--user', 'is-active', 'vocoder.service'],
                              capture_output=True, text=True)
        if result.stdout.strip() == 'active':
            print("  ✅ Vocoder service is active")
        else:
            self.warnings.append("Vocoder service not active")
            print(f"  ⚠️  Vocoder service is {result.stdout.strip()}")
            print("     Fix: systemctl --user start vocoder.service")
            
        # Check socket
        socket_path = Path(f"/run/user/{os.getuid()}/vocoder.sock")
        if socket_path.exists():
            print(f"  ✅ IPC socket exists: {socket_path}")
        else:
            self.warnings.append("IPC socket not found")
            print(f"  ⚠️  IPC socket not found at {socket_path}")
            
    def test_recording(self):
        """Test actual recording"""
        print("\n🎙️ Testing Audio Recording...")
        print("  Recording 2 seconds of audio...")
        
        try:
            duration = 2
            fs = 16000
            recording = sd.rec(int(duration * fs), samplerate=fs, 
                              channels=1, dtype='float32')
            sd.wait()
            
            # Check if we got audio
            rms = np.sqrt(np.mean(recording**2))
            max_val = np.max(np.abs(recording))
            
            print(f"  📊 Audio statistics:")
            print(f"     RMS Level: {rms:.4f}")
            print(f"     Max Level: {max_val:.4f}")
            
            if rms < 0.001:
                self.errors.append("Recording captured only silence")
                print("  ❌ Recording captured only silence")
                print("     Check microphone is not muted")
                print("     Check: pavucontrol (Recording tab)")
            else:
                print("  ✅ Audio recording successful")
                
        except Exception as e:
            self.errors.append(f"Recording test failed: {e}")
            print(f"  ❌ Recording test failed: {e}")
            
    def print_summary(self):
        """Print diagnostic summary"""
        print("\n" + "="*50)
        print("DIAGNOSTIC SUMMARY")
        print("="*50)
        
        if not self.errors and not self.warnings:
            print("✅ All systems operational!")
        else:
            if self.errors:
                print(f"\n❌ Critical Issues ({len(self.errors)}):")
                for error in self.errors:
                    print(f"  • {error}")
                    
            if self.warnings:
                print(f"\n⚠️  Warnings ({len(self.warnings)}):")
                for warning in self.warnings:
                    print(f"  • {warning}")
                    
        print("\n" + "="*50)
        print("QUICK FIXES")
        print("="*50)
        print("1. Set correct microphone:")
        print("   pactl set-default-source alsa_input.pci-0000_2f_00.4.analog-stereo")
        print("\n2. Start ydotool daemon:")
        print("   systemctl --user start ydotoold")
        print("\n3. Restart vocoder service:")
        print("   systemctl --user restart vocoder.service")
        print("\n4. Check Whisper Docker:")
        print("   docker ps | grep whisper")
        print("   docker logs whisper-blackwell")

if __name__ == "__main__":
    diag = VocoderDiagnostic()
    diag.check_audio_devices()
    diag.check_whisper_api()
    diag.check_ydotool()
    diag.check_daemon()
    diag.test_recording()
    diag.print_summary()
```

## Validation Loop

### Level 1: Component Testing

```bash
# Test audio recording
python3 /home/ice/dev/vocoder/scripts/diagnose-vocoder.py

# Test Whisper API
curl -s http://127.0.0.1:8771/health | jq .

# Test ydotool
echo "test" | ydotool type --file -

# Check daemon logs
journalctl --user -u vocoder.service -f
```

### Level 2: Integration Testing

```bash
# Restart daemon with fixes
systemctl --user restart vocoder.service

# Test via control client
python3 /home/ice/dev/vocoder/bin/vocoderctl status

# Trigger recording manually
python3 /home/ice/dev/vocoder/bin/vocoderctl toggle

# Watch logs for errors
journalctl --user -u vocoder.service -n 50
```

### Level 3: End-to-End Testing

```bash
# Test with hotkey
# 1. Open a text editor
# 2. Press Super+Space
# 3. Say "Testing vocoder transcription"
# 4. Wait for text to appear

# Verify each step:
# - Notification appears
# - Recording captures audio
# - Transcription returns text
# - Text is typed at cursor
```

### Level 4: Debugging Checklist

```yaml
audio_not_recording:
  - Check: pactl get-default-source
  - Fix: pactl set-default-source alsa_input.pci-0000_2f_00.4.analog-stereo
  - Verify: python3 -c "import sounddevice as sd; print(sd.query_devices())"
  
whisper_not_responding:
  - Check: curl http://127.0.0.1:8771/health
  - Fix: docker ps | grep whisper
  - Restart: docker compose -f docker-compose.blackwell.yml up -d
  
ydotool_not_typing:
  - Check: pgrep ydotoold
  - Fix: systemctl --user start ydotoold
  - Test: echo "test" | ydotool type --file -
  
daemon_not_working:
  - Check: systemctl --user status vocoder.service
  - Logs: journalctl --user -u vocoder.service -n 100
  - Debug: Run directly: python3 /home/ice/dev/vocoder/bin/vocoder
```

## Gotchas and Edge Cases

1. **PulseAudio Monitor Trap**: System often defaults to `.monitor` sources which record system audio instead of microphone
2. **ydotool sudo Trap**: Using sudo with ydotool requires password and fails silently in daemon
3. **NaN RMS Values**: Audio processing can produce NaN values that break silence detection
4. **Port Mismatch**: Whisper API on 8771 but config may have 8767
5. **Stream State**: sounddevice stream can appear started but not actually be running
6. **Gain Clipping**: 15dB gain can cause severe distortion if not clipped properly
7. **Empty Audio Buffers**: Recording can complete with empty buffers if device fails

## Final Validation Checklist

- [ ] Audio device selection excludes monitor sources
- [ ] RMS calculation handles NaN/inf values gracefully  
- [ ] ydotool runs without sudo requirement
- [ ] Whisper API URL uses port 8771
- [ ] All errors are logged with context
- [ ] Diagnostic script identifies all issues
- [ ] Hotkey triggers recording successfully
- [ ] Recording stops on silence correctly
- [ ] Transcription returns actual text
- [ ] Text is typed at cursor position
- [ ] Clipboard fallback works if typing fails

## Confidence Score

**8/10** - High confidence in fix success

The PRP provides comprehensive context covering all identified failure points with specific line-by-line fixes, complete diagnostic tooling, and detailed validation procedures. The only uncertainty is potential system-specific audio configurations that may require additional debugging.