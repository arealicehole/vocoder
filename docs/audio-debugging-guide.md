# PulseAudio/ALSA Audio Recording Issues - Comprehensive Debugging Guide

This document provides comprehensive solutions for common audio recording issues on Linux, specifically targeting problems with microphone input defaulting to monitor loopback, device detection, sounddevice library issues, and best practices for audio configuration.

## Table of Contents
1. [Monitor Loopback vs Actual Microphone](#monitor-loopback-vs-actual-microphone)
2. [Programmatic Audio Device Detection & Selection](#programmatic-audio-device-detection--selection)
3. [Common sounddevice Library Issues](#common-sounddevice-library-issues)
4. [Recording Silence Troubleshooting](#recording-silence-troubleshooting)
5. [Best Practices for Audio Configuration](#best-practices-for-audio-configuration)
6. [Debugging Commands Reference](#debugging-commands-reference)
7. [Python Code Examples](#python-code-examples)

---

## Monitor Loopback vs Actual Microphone

### Understanding the Problem

PulseAudio creates "monitor" sources for every audio output (sink) that capture the audio being played through that output. These monitor sources often appear alongside real microphone inputs and can be mistakenly selected as the recording source, leading to recording system audio instead of microphone input.

### Root Causes

1. **Default Source Selection**: PulseAudio may default to a monitor source instead of the physical microphone
2. **Application Confusion**: Recording applications may not distinguish between monitor and input sources
3. **Hardware Loopback**: Some sound cards have hardware loopback that mixes output into input
4. **Module Conflicts**: The `module-loopback` can cause unintended audio routing

### Solutions

#### 1. Using pavucontrol (Graphical Solution)

```bash
# Install pavucontrol
sudo dnf install pavucontrol  # Fedora
sudo apt install pavucontrol  # Ubuntu/Debian

# Steps:
# 1. Start your recording application (vocoder daemon)
# 2. Open pavucontrol
# 3. Go to "Recording" tab
# 4. While recording is active, you'll see your application
# 5. Click the dropdown showing the current input device
# 6. Select your actual microphone (NOT any "Monitor of..." option)
```

#### 2. Command Line Detection and Fixing

```bash
# List all audio sources (inputs)
pactl list sources short

# Look for sources that contain "monitor" - these are loopback sources
# Example output:
# 0    alsa_output.pci-0000_00_1f.3.analog-stereo.monitor
# 1    alsa_input.pci-0000_00_1f.3.analog-stereo

# List source outputs (what's currently recording)
pactl list source-outputs

# Set default source to your microphone (not monitor)
pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo

# Move active recording to correct source
pactl move-source-output <SOURCE_OUTPUT_ID> alsa_input.pci-0000_00_1f.3.analog-stereo
```

#### 3. Disable Monitor Sources (if not needed)

```bash
# List loaded modules
pactl list modules | grep -i loopback

# Unload loopback modules if present
pactl unload-module module-loopback

# Prevent monitor sources from being used (add to /etc/pulse/default.pa)
echo "set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo" | sudo tee -a /etc/pulse/default.pa
```

#### 4. ALSA-Level Input Source Check

```bash
# Open alsamixer
alsamixer

# Press F6 to select sound card
# Press F5 to show all controls
# Look for "Input Source" and set to "Internal Mic" or "Microphone"
# Ensure microphone is unmuted and at reasonable volume
```

---

## Programmatic Audio Device Detection & Selection

### Python sounddevice Approach

```python
import sounddevice as sd
import re
from typing import List, Tuple, Optional

def list_audio_devices() -> None:
    """List all available audio devices with detailed information"""
    devices = sd.query_devices()
    print("Available Audio Devices:")
    print("=" * 50)
    
    for i, device in enumerate(devices):
        print(f"ID: {i}")
        print(f"Name: {device['name']}")
        print(f"Channels: In={device['max_input_channels']}, Out={device['max_output_channels']}")
        print(f"Sample Rate: {device['default_samplerate']}")
        print(f"Host API: {sd.query_hostapis(device['hostapi'])['name']}")
        print("-" * 30)

def find_microphone_devices() -> List[Tuple[int, dict]]:
    """Find devices that can record audio (input channels > 0) and are likely microphones"""
    devices = sd.query_devices()
    microphones = []
    
    # Patterns that indicate monitor/loopback sources to avoid
    monitor_patterns = [
        r'monitor',
        r'loopback', 
        r'what.*hear',
        r'stereo.*mix',
        r'output.*capture'
    ]
    
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            device_name_lower = device['name'].lower()
            
            # Skip monitor/loopback devices
            is_monitor = any(re.search(pattern, device_name_lower) for pattern in monitor_patterns)
            
            if not is_monitor:
                microphones.append((i, device))
    
    return microphones

def select_best_microphone() -> Optional[int]:
    """Automatically select the best microphone device"""
    microphones = find_microphone_devices()
    
    if not microphones:
        print("No microphone devices found!")
        return None
    
    # Prioritize devices with these keywords
    priority_keywords = ['microphone', 'mic', 'internal', 'built-in', 'usb']
    
    for device_id, device in microphones:
        device_name_lower = device['name'].lower()
        if any(keyword in device_name_lower for keyword in priority_keywords):
            print(f"Selected microphone: {device['name']} (ID: {device_id})")
            return device_id
    
    # Fallback to first available microphone
    device_id, device = microphones[0]
    print(f"Using first available microphone: {device['name']} (ID: {device_id})")
    return device_id

def set_default_audio_device(device_id: int) -> bool:
    """Set default input device for sounddevice"""
    try:
        # Validate device exists and has input channels
        device = sd.query_devices(device_id)
        if device['max_input_channels'] == 0:
            print(f"Device {device_id} has no input channels!")
            return False
        
        # Set as default
        sd.default.device = device_id
        print(f"Set default input device to: {device['name']}")
        return True
        
    except Exception as e:
        print(f"Error setting default device: {e}")
        return False

# Usage example
if __name__ == "__main__":
    list_audio_devices()
    
    best_mic = select_best_microphone()
    if best_mic is not None:
        set_default_audio_device(best_mic)
```

### PulseAudio Command Integration

```python
import subprocess
import json
import re
from typing import List, Dict, Optional

def get_pulseaudio_sources() -> List[Dict]:
    """Get detailed information about PulseAudio sources"""
    try:
        result = subprocess.run(['pactl', 'list', 'sources', '--json'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            return json.loads(result.stdout)
    except:
        pass
    
    # Fallback to parsing text output
    result = subprocess.run(['pactl', 'list', 'sources'], 
                          capture_output=True, text=True)
    sources = []
    current_source = {}
    
    for line in result.stdout.split('\n'):
        if line.startswith('Source #'):
            if current_source:
                sources.append(current_source)
            current_source = {'index': re.search(r'#(\d+)', line).group(1)}
        elif 'Name:' in line:
            current_source['name'] = line.split('Name:')[1].strip()
        elif 'Description:' in line:
            current_source['description'] = line.split('Description:')[1].strip()
        elif 'Mute:' in line:
            current_source['mute'] = 'yes' in line
    
    if current_source:
        sources.append(current_source)
    
    return sources

def set_pulseaudio_default_source(source_name: str) -> bool:
    """Set PulseAudio default source"""
    try:
        result = subprocess.run(['pactl', 'set-default-source', source_name],
                              capture_output=True)
        return result.returncode == 0
    except:
        return False

def find_real_microphone_source() -> Optional[str]:
    """Find the best real microphone source (not monitor)"""
    sources = get_pulseaudio_sources()
    
    # Filter out monitor sources
    real_sources = [s for s in sources 
                   if 'monitor' not in s.get('name', '').lower() and
                      'monitor' not in s.get('description', '').lower()]
    
    # Look for microphone-like sources
    mic_keywords = ['microphone', 'mic', 'internal', 'built-in', 'input']
    
    for source in real_sources:
        desc = source.get('description', '').lower()
        if any(keyword in desc for keyword in mic_keywords):
            return source['name']
    
    # Return first non-monitor source
    return real_sources[0]['name'] if real_sources else None

# Usage
mic_source = find_real_microphone_source()
if mic_source:
    set_pulseaudio_default_source(mic_source)
    print(f"Set PulseAudio default source to: {mic_source}")
```

---

## Common sounddevice Library Issues

### Installation and Dependencies

```bash
# System dependencies (varies by distro)
# Fedora/RHEL/CentOS
sudo dnf install portaudio portaudio-devel python3-devel

# Ubuntu/Debian  
sudo apt-get install portaudio19-dev python3-dev

# Python dependencies
pip install sounddevice numpy

# Check installation
python3 -c "import sounddevice as sd; print(sd.__version__)"
```

### Common Error Patterns and Solutions

#### 1. PortAudio Not Found

```python
# Error: ImportError: cannot find PortAudio library
# Solution: Install system PortAudio library

import subprocess
import sys

def check_portaudio():
    """Check if PortAudio is available"""
    try:
        import sounddevice as sd
        return True
    except ImportError as e:
        if "portaudio" in str(e).lower():
            print("PortAudio library not found!")
            print("Install with:")
            print("  Fedora: sudo dnf install portaudio portaudio-devel")
            print("  Ubuntu: sudo apt-get install portaudio19-dev")
            return False
        else:
            print(f"Other import error: {e}")
            return False

if not check_portaudio():
    sys.exit(1)
```

#### 2. No Audio Devices Found

```python
import sounddevice as sd

def diagnose_audio_setup():
    """Diagnose common audio setup issues"""
    print("Audio Setup Diagnosis")
    print("=" * 30)
    
    try:
        devices = sd.query_devices()
        print(f"Total devices found: {len(devices)}")
        
        input_devices = [d for d in devices if d['max_input_channels'] > 0]
        print(f"Input devices: {len(input_devices)}")
        
        if not input_devices:
            print("\nNo input devices found!")
            print("Possible solutions:")
            print("1. Check if microphone is connected")
            print("2. Check PulseAudio: pulseaudio --check")
            print("3. Restart audio services: pulseaudio -k && pulseaudio --start")
            print("4. Check user permissions (audio group)")
            
        # Check default device
        try:
            default_device = sd.default.device
            print(f"Default device: {default_device}")
        except:
            print("No default device set")
            
        # Check host APIs
        host_apis = [sd.query_hostapis(i) for i in range(sd.query_hostapis())]
        print(f"Available host APIs: {[api['name'] for api in host_apis]}")
        
    except Exception as e:
        print(f"Error querying devices: {e}")
        print("Try:")
        print("1. Restart PulseAudio: pulseaudio -k && pulseaudio --start")
        print("2. Check if user is in audio group: groups $USER")

diagnose_audio_setup()
```

#### 3. Permission Issues

```bash
# Check audio group membership
groups $USER

# Add user to audio group if not present
sudo usermod -a -G audio $USER

# May need to log out and back in, or:
newgrp audio

# Check PulseAudio status
pulseaudio --check -v

# Restart PulseAudio if needed
pulseaudio -k && pulseaudio --start
```

---

## Recording Silence Troubleshooting

### Common Causes of Silent Recording

1. **Wrong Input Device**: Recording from monitor instead of microphone
2. **Muted Input**: Microphone is muted in system settings
3. **Low Gain**: Input gain is set too low
4. **Hardware Issues**: Faulty microphone or connection
5. **Driver Problems**: Audio driver issues

### Diagnostic Steps

```python
import sounddevice as sd
import numpy as np
import time

def test_microphone_input(duration=5, device=None):
    """Test microphone input and provide diagnostic information"""
    print(f"Testing microphone input for {duration} seconds...")
    print("Speak into your microphone now!")
    
    sample_rate = 16000
    channels = 1
    
    try:
        # Record audio
        recording = sd.rec(int(duration * sample_rate), 
                          samplerate=sample_rate, 
                          channels=channels,
                          device=device,
                          dtype='float32')
        sd.wait()  # Wait until recording is finished
        
        # Analyze the recording
        audio_data = recording.flatten()
        
        # Calculate statistics
        max_amplitude = np.max(np.abs(audio_data))
        rms = np.sqrt(np.mean(audio_data**2))
        non_zero_samples = np.count_nonzero(audio_data)
        total_samples = len(audio_data)
        
        print("\nRecording Analysis:")
        print(f"  Duration: {duration}s")
        print(f"  Sample rate: {sample_rate}Hz")
        print(f"  Total samples: {total_samples}")
        print(f"  Non-zero samples: {non_zero_samples} ({non_zero_samples/total_samples*100:.1f}%)")
        print(f"  Maximum amplitude: {max_amplitude:.6f}")
        print(f"  RMS level: {rms:.6f}")
        
        # Interpretation
        if max_amplitude < 1e-6:
            print("\n❌ PROBLEM: Recording is completely silent")
            print("Possible causes:")
            print("- Microphone is muted")
            print("- Recording from wrong device (monitor/loopback)")
            print("- Microphone not connected")
            print("- Hardware failure")
            
        elif max_amplitude < 0.01:
            print("\n⚠️  WARNING: Very low input level")
            print("Consider:")
            print("- Increasing microphone gain")
            print("- Speaking closer to microphone")
            print("- Checking if microphone needs power/batteries")
            
        elif max_amplitude > 0.95:
            print("\n⚠️  WARNING: Input may be clipping")
            print("Consider:")
            print("- Reducing microphone gain")
            print("- Speaking further from microphone")
            
        else:
            print(f"\n✅ Good recording level (max: {max_amplitude:.3f})")
            
        # Check for potential issues
        if non_zero_samples < total_samples * 0.1:
            print("\n⚠️  WARNING: Mostly silent recording")
            print("This could indicate:")
            print("- Input gain too low")
            print("- Background noise gate active")
            print("- Intermittent connection")
            
        return recording
        
    except Exception as e:
        print(f"\n❌ ERROR: Failed to record audio: {e}")
        print("Try:")
        print("- Different audio device")
        print("- Restarting audio services")
        print("- Checking device permissions")
        return None

def test_all_input_devices():
    """Test all available input devices"""
    devices = sd.query_devices()
    input_devices = [(i, d) for i, d in enumerate(devices) if d['max_input_channels'] > 0]
    
    print(f"Found {len(input_devices)} input devices. Testing each...")
    
    for device_id, device in input_devices:
        print(f"\n{'='*50}")
        print(f"Testing Device {device_id}: {device['name']}")
        print(f"{'='*50}")
        
        try:
            test_microphone_input(duration=3, device=device_id)
        except Exception as e:
            print(f"Failed to test device {device_id}: {e}")

# Run diagnostics
if __name__ == "__main__":
    test_microphone_input()
    
    # Uncomment to test all devices
    # test_all_input_devices()
```

### System-Level Debugging

```bash
#!/bin/bash
# comprehensive-audio-debug.sh

echo "=== Comprehensive Audio Debug Script ==="
echo

# Check PulseAudio status
echo "1. PulseAudio Status:"
pulseaudio --check && echo "✅ PulseAudio running" || echo "❌ PulseAudio not running"
echo

# List audio devices
echo "2. PulseAudio Sources (inputs):"
pactl list sources short
echo

echo "3. ALSA Cards:"
cat /proc/asound/cards
echo

echo "4. Current default source:"
pactl info | grep "Default Source"
echo

# Test recording with different tools
echo "5. Testing with arecord (ALSA):"
echo "Recording 3 seconds with ALSA..."
timeout 3s arecord -f cd /tmp/test_alsa.wav 2>/dev/null
if [ -f /tmp/test_alsa.wav ]; then
    size=$(stat -c%s /tmp/test_alsa.wav)
    echo "✅ ALSA recording: ${size} bytes"
    # Check if it has actual content
    sox /tmp/test_alsa.wav -n stat 2>&1 | grep "Maximum amplitude" || echo "⚠️  Silent recording"
else
    echo "❌ ALSA recording failed"
fi
echo

echo "6. Testing with PulseAudio (parec):"
echo "Recording 3 seconds with PulseAudio..."
timeout 3s parec --format=s16le --rate=16000 --channels=1 /tmp/test_pulse.wav 2>/dev/null
if [ -f /tmp/test_pulse.wav ]; then
    size=$(stat -c%s /tmp/test_pulse.wav)
    echo "✅ PulseAudio recording: ${size} bytes"
else
    echo "❌ PulseAudio recording failed"
fi
echo

echo "7. Checking microphone levels:"
amixer | grep -A 5 -B 5 -i mic || echo "No microphone controls found in amixer"
echo

echo "8. User audio permissions:"
groups $USER | grep audio && echo "✅ User in audio group" || echo "❌ User not in audio group"
echo

# Check for problematic modules
echo "9. PulseAudio modules:"
pactl list modules | grep -E "(module-loopback|module-echo-cancel)" || echo "No loopback/echo-cancel modules loaded"
echo

echo "=== Debug Complete ==="
echo "If recordings are silent:"
echo "1. Check pavucontrol Recording tab while recording"
echo "2. Ensure correct input device selected (not Monitor)"  
echo "3. Check microphone gain in alsamixer"
echo "4. Try different input devices with Python script"
```

---

## Best Practices for Audio Configuration

### Python Application Setup

```python
import sounddevice as sd
import numpy as np
import logging
from typing import Optional

class RobustAudioRecorder:
    """Robust audio recorder with proper error handling and device selection"""
    
    def __init__(self, sample_rate: int = 16000, channels: int = 1, gain_db: float = 15.0):
        self.sample_rate = sample_rate
        self.channels = channels
        self.gain_multiplier = 10 ** (gain_db / 20.0)
        
        # Initialize logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
        
        # Find and set best microphone
        self.device_id = self._find_best_microphone()
        if self.device_id is None:
            raise RuntimeError("No suitable microphone found!")
            
    def _find_best_microphone(self) -> Optional[int]:
        """Find the best microphone device, avoiding monitors/loopbacks"""
        try:
            devices = sd.query_devices()
            
            # Filter potential microphones (has input channels, not a monitor)
            candidates = []
            for i, device in enumerate(devices):
                if device['max_input_channels'] > 0:
                    name_lower = device['name'].lower()
                    
                    # Skip known monitor/loopback patterns
                    if any(pattern in name_lower for pattern in 
                          ['monitor', 'loopback', 'what u hear', 'stereo mix']):
                        continue
                        
                    candidates.append((i, device))
            
            if not candidates:
                self.logger.error("No input devices found!")
                return None
                
            # Prioritize certain device types
            priority_keywords = ['microphone', 'mic', 'built-in', 'internal']
            for device_id, device in candidates:
                name_lower = device['name'].lower()
                if any(keyword in name_lower for keyword in priority_keywords):
                    self.logger.info(f"Selected microphone: {device['name']}")
                    return device_id
            
            # Fallback to first candidate
            device_id, device = candidates[0]
            self.logger.info(f"Using first available input: {device['name']}")
            return device_id
            
        except Exception as e:
            self.logger.error(f"Error finding microphone: {e}")
            return None
    
    def test_device(self, duration: float = 2.0) -> bool:
        """Test if the selected device can record audio"""
        try:
            self.logger.info("Testing microphone...")
            recording = sd.rec(
                int(duration * self.sample_rate),
                samplerate=self.sample_rate,
                channels=self.channels,
                device=self.device_id,
                dtype='float32'
            )
            sd.wait()
            
            # Check if recording has content
            max_amplitude = np.max(np.abs(recording))
            
            if max_amplitude < 1e-6:
                self.logger.error("Microphone test failed: silent recording")
                return False
            elif max_amplitude < 0.001:
                self.logger.warning(f"Low microphone level: {max_amplitude:.6f}")
            else:
                self.logger.info(f"Microphone test passed: {max_amplitude:.6f}")
                
            return True
            
        except Exception as e:
            self.logger.error(f"Microphone test failed: {e}")
            return False
    
    def record(self, duration: float) -> Optional[np.ndarray]:
        """Record audio with error handling"""
        try:
            recording = sd.rec(
                int(duration * self.sample_rate),
                samplerate=self.sample_rate,
                channels=self.channels,
                device=self.device_id,
                dtype='float32'
            )
            sd.wait()
            
            # Apply gain
            audio_data = recording.flatten() * self.gain_multiplier
            audio_data = np.clip(audio_data, -1.0, 1.0)
            
            return audio_data
            
        except Exception as e:
            self.logger.error(f"Recording failed: {e}")
            return None

# Usage example
if __name__ == "__main__":
    try:
        recorder = RobustAudioRecorder(gain_db=15.0)
        
        # Test the device
        if recorder.test_device():
            print("✅ Audio setup successful!")
            
            # Record some audio
            print("Recording 5 seconds...")
            audio = recorder.record(5.0)
            if audio is not None:
                print(f"✅ Recorded {len(audio)} samples")
            else:
                print("❌ Recording failed")
        else:
            print("❌ Audio setup failed")
            
    except Exception as e:
        print(f"❌ Failed to initialize recorder: {e}")
```

### System Configuration

```bash
# /etc/pulse/default.pa additions for reliable microphone setup

# Set explicit default source (replace with your actual microphone)
set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo

# Disable module-suspend-on-idle to keep audio active
# (comment out or remove this line if present)
# load-module module-suspend-on-idle

# Load echo cancellation if needed
load-module module-echo-cancel source_name=echoCancel_source sink_name=echoCancel_sink
set-default-source echoCancel_source
set-default-sink echoCancel_sink

# Alternative: Load noise suppression
load-module module-echo-cancel use_volume_sharing=1 \
    aec_method=webrtc source_name=echoCancel_source sink_name=echoCancel_sink \
    aec_args="analog_gain_control=0 digital_gain_control=1 noise_suppression=1"
```

---

## Debugging Commands Reference

### Quick Diagnostic Commands

```bash
# Audio system status
pulseaudio --check && echo "PulseAudio OK" || echo "PulseAudio Problem"
systemctl --user status pulseaudio

# List devices
pactl list sources short              # PulseAudio inputs
pactl list sinks short               # PulseAudio outputs  
aplay -L                             # ALSA playback devices
arecord -L                           # ALSA capture devices
cat /proc/asound/cards               # Sound cards

# Current settings
pactl info | grep "Default Source"   # Current default input
pactl info | grep "Default Sink"     # Current default output

# Test recording
arecord -f cd -t wav -d 3 test.wav   # ALSA test
parec -d 3 --channels=1 test.wav     # PulseAudio test
```

### Detailed Device Information

```bash
# Get detailed source information
pactl list sources | grep -A 20 "Source #"

# Show source properties
pactl list sources | grep -E "(Name|Description|State|Mute|Volume)"

# Find monitor sources specifically
pactl list sources | grep -B 2 -A 10 "monitor"

# Check which applications are recording
pactl list source-outputs
```

### Fix Common Issues

```bash
# Restart audio system
pulseaudio -k && pulseaudio --start

# Reset to ALSA defaults
sudo alsa force-reload

# Set specific default source
pactl set-default-source "alsa_input.pci-0000_00_1f.3.analog-stereo"

# Unmute microphone
pactl set-source-mute @DEFAULT_SOURCE@ false
pactl set-source-volume @DEFAULT_SOURCE@ 100%

# Move recording stream to different source
pactl move-source-output <SOURCE_OUTPUT_ID> <SOURCE_NAME>
```

---

## Python Code Examples

### Complete Audio Device Manager

```python
#!/usr/bin/env python3
"""
Complete audio device management for vocoder
"""

import sounddevice as sd
import subprocess
import json
import re
import logging
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass

@dataclass
class AudioDevice:
    """Audio device information"""
    id: int
    name: str
    description: str
    max_input_channels: int
    max_output_channels: int
    default_samplerate: float
    hostapi: str
    is_monitor: bool = False
    
class AudioDeviceManager:
    """Manages audio device detection and selection"""
    
    def __init__(self):
        self.logger = logging.getLogger(__name__)
        self._devices_cache = None
        
    def refresh_devices(self) -> None:
        """Refresh device cache"""
        self._devices_cache = None
        
    def get_devices(self) -> List[AudioDevice]:
        """Get all audio devices with detailed information"""
        if self._devices_cache is None:
            self._devices_cache = self._query_devices()
        return self._devices_cache
        
    def _query_devices(self) -> List[AudioDevice]:
        """Query all audio devices"""
        devices = []
        
        try:
            sd_devices = sd.query_devices()
            host_apis = [sd.query_hostapis(i) for i in range(sd.query_hostapis())]
            
            for i, device in enumerate(sd_devices):
                # Determine if this is a monitor device
                name_lower = device['name'].lower()
                is_monitor = any(pattern in name_lower for pattern in [
                    'monitor', 'loopback', 'what u hear', 'stereo mix',
                    'what you hear', 'wave out mix'
                ])
                
                # Get host API name
                hostapi_name = host_apis[device['hostapi']]['name']
                
                audio_device = AudioDevice(
                    id=i,
                    name=device['name'],
                    description=device['name'],  # SD doesn't provide separate description
                    max_input_channels=device['max_input_channels'],
                    max_output_channels=device['max_output_channels'],
                    default_samplerate=device['default_samplerate'],
                    hostapi=hostapi_name,
                    is_monitor=is_monitor
                )
                devices.append(audio_device)
                
        except Exception as e:
            self.logger.error(f"Error querying sounddevice: {e}")
            
        return devices
    
    def get_input_devices(self, exclude_monitors: bool = True) -> List[AudioDevice]:
        """Get devices capable of audio input"""
        devices = self.get_devices()
        input_devices = [d for d in devices if d.max_input_channels > 0]
        
        if exclude_monitors:
            input_devices = [d for d in input_devices if not d.is_monitor]
            
        return input_devices
    
    def find_microphone(self) -> Optional[AudioDevice]:
        """Find the best microphone device"""
        input_devices = self.get_input_devices()
        
        if not input_devices:
            return None
            
        # Priority keywords for microphone selection
        priority_keywords = [
            'microphone', 'mic', 'built-in', 'internal', 
            'front', 'rear', 'line-in', 'usb'
        ]
        
        # Check for priority devices
        for device in input_devices:
            name_lower = device.name.lower()
            for keyword in priority_keywords:
                if keyword in name_lower:
                    self.logger.info(f"Selected microphone by keyword '{keyword}': {device.name}")
                    return device
        
        # Fallback to first input device
        device = input_devices[0]
        self.logger.info(f"Using first available input device: {device.name}")
        return device
    
    def set_default_device(self, device: AudioDevice) -> bool:
        """Set default input device"""
        try:
            sd.default.device = device.id
            self.logger.info(f"Set default device to: {device.name}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to set default device: {e}")
            return False
    
    def test_device(self, device: AudioDevice, duration: float = 2.0) -> Tuple[bool, Dict]:
        """Test recording from a device"""
        result = {
            'success': False,
            'max_amplitude': 0.0,
            'rms': 0.0,
            'error': None,
            'samples': 0
        }
        
        try:
            # Record test audio
            recording = sd.rec(
                int(duration * 16000),  # 16kHz sample rate
                samplerate=16000,
                channels=1,
                device=device.id,
                dtype='float32'
            )
            sd.wait()
            
            # Analyze recording
            audio_data = recording.flatten()
            result['samples'] = len(audio_data)
            result['max_amplitude'] = float(np.max(np.abs(audio_data)))
            result['rms'] = float(np.sqrt(np.mean(audio_data**2)))
            
            # Consider test successful if we have some audio content
            if result['max_amplitude'] > 1e-6:
                result['success'] = True
                
        except Exception as e:
            result['error'] = str(e)
            
        return result['success'], result

def setup_vocoder_audio() -> Optional[AudioDevice]:
    """Setup audio for vocoder application"""
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)
    
    manager = AudioDeviceManager()
    
    # Find microphone
    microphone = manager.find_microphone()
    if not microphone:
        logger.error("No microphone found!")
        return None
    
    # Test microphone
    logger.info(f"Testing microphone: {microphone.name}")
    success, result = manager.test_device(microphone)
    
    if success:
        logger.info(f"✅ Microphone test passed - Max amplitude: {result['max_amplitude']:.6f}")
        
        # Set as default
        if manager.set_default_device(microphone):
            return microphone
    else:
        logger.error(f"❌ Microphone test failed: {result.get('error', 'Silent recording')}")
        
        # Try other input devices
        input_devices = manager.get_input_devices()
        for device in input_devices[1:]:  # Skip the first one (already tested)
            logger.info(f"Trying alternative device: {device.name}")
            success, result = manager.test_device(device)
            
            if success and result['max_amplitude'] > 1e-4:
                logger.info(f"✅ Alternative device works: {device.name}")
                if manager.set_default_device(device):
                    return device
    
    return None

if __name__ == "__main__":
    # Example usage
    import numpy as np
    
    device = setup_vocoder_audio()
    if device:
        print(f"Audio setup complete. Using: {device.name}")
        
        # List all devices for reference
        manager = AudioDeviceManager()
        print("\nAll available input devices:")
        for dev in manager.get_input_devices():
            status = "✅" if dev.id == device.id else "  "
            monitor = " (Monitor)" if dev.is_monitor else ""
            print(f"{status} ID:{dev.id:2d} - {dev.name}{monitor}")
    else:
        print("❌ Failed to setup audio")
```

### Integration with Existing Vocoder

```python
# Add to your vocoder's AudioRecorder class

class AudioRecorder:
    def __init__(self, config: Config):
        self.config = config
        self.recording = False
        self.audio_buffer = []
        self.silence_counter = 0
        self.stream = None
        
        # Initialize audio device manager
        self.device_manager = AudioDeviceManager()
        self.setup_microphone()
        
    def setup_microphone(self):
        """Setup and verify microphone"""
        microphone = self.device_manager.find_microphone()
        
        if not microphone:
            logging.error("No microphone found!")
            raise RuntimeError("No suitable microphone available")
        
        # Test the microphone
        success, result = self.device_manager.test_device(microphone)
        
        if not success or result['max_amplitude'] < 1e-6:
            logging.warning(f"Primary microphone failed test: {microphone.name}")
            
            # Try alternative devices
            for device in self.device_manager.get_input_devices():
                if device.id != microphone.id:
                    success, result = self.device_manager.test_device(device)
                    if success and result['max_amplitude'] > 1e-6:
                        microphone = device
                        logging.info(f"Using alternative microphone: {device.name}")
                        break
            else:
                raise RuntimeError("No working microphone found!")
        
        # Set device and store ID
        self.device_manager.set_default_device(microphone)
        self.microphone_device_id = microphone.id
        
        logging.info(f"Microphone setup complete: {microphone.name}")
        
    def start_recording(self):
        """Start recording with verified microphone"""
        logging.info("Starting recording")
        self.recording = True
        self.audio_buffer = []
        self.silence_counter = 0
        
        try:
            self.stream = sd.InputStream(
                callback=self.audio_callback,
                channels=self.config.channels,
                samplerate=self.config.sample_rate,
                blocksize=1024,
                dtype='float32',
                device=self.microphone_device_id  # Use verified device
            )
            self.stream.start()
            
            self.play_sound("start")
            self.notify("Recording... (speak now)", 2000)
            
        except Exception as e:
            logging.error(f"Failed to start recording: {e}")
            self.recording = False
            self.play_sound("error")
            self.notify("Recording failed - check audio setup", 2000)
```

This comprehensive guide should help you diagnose and fix most PulseAudio/ALSA audio recording issues. The key points are:

1. **Always verify you're not recording from monitor sources**
2. **Use both GUI (pavucontrol) and command-line tools for debugging**
3. **Implement robust device detection and testing in your applications**
4. **Have fallback mechanisms when the primary device fails**
5. **Test your setup thoroughly with both system tools and your application**

The provided Python code examples can be integrated into your vocoder to make it more robust against common audio configuration issues.