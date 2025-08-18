name: "Vocoder Option B Updated - Daemon Architecture Built on Working Option A"
description: |
  Comprehensive PRP for implementing a persistent daemon that extends the proven
  Option A implementation, maintaining all fixes and improvements discovered during
  development while adding low-latency and advanced control features.

---

## Goal

**Feature Goal**: Transform the working single-shot dictation script into a persistent daemon that maintains all the fixes from Option A (ydotool preference, gain boost, text cleanup, etc.) while adding instant response time and advanced control.

**Deliverable**: 
- `vocoder` - Python daemon service (maintains Option A's core logic)
- `vocoderctl` - CLI control client
- `~/.config/systemd/user/vocoder.service` - systemd integration
- Migration preserves all Option A improvements

**Success Definition**: Sub-second latency dictation that works identically to Option A but with persistent connections, multiple modes, and zero startup delay.

## User Persona

**Target User**: Current Option A users who want faster response and more control without losing any of the working functionality

**Use Case**: 
- Same as Option A but with instant response
- Push-to-talk for quick code comments
- Session-based dictation for long documents
- Keep existing Super+Space workflow

**User Journey**: 
1. User migrates from Option A (keeps working script as backup)
2. Daemon starts on boot with systemd
3. First dictation has zero startup delay
4. All Option A behaviors preserved (gain boost, ydotool, cleanup)
5. New modes available via vocoderctl

## Why

- **Preserve Success**: Keep everything that works in Option A
- **Add Speed**: Eliminate 1-2 second startup delay
- **Maintain Compatibility**: Same hotkey, same behavior, faster response
- **Enable Growth**: Foundation for push-to-talk and advanced features
- **Risk-Free Migration**: Option A remains as fallback

## What

### Core Requirements (Preserving Option A)

**Must Maintain from Working Option A:**
- ydotool as primary typing tool (wtype as fallback)
- Audio gain +15 for better pickup
- Text cleanup removing ALL newlines
- `--file -` flag for ydotool
- Clipboard fallback with clear notification
- Same audio feedback sounds
- Same silence detection parameters

**New Capabilities:**
- Persistent process (no startup delay)
- Warm Whisper connection
- Multiple recording modes
- IPC control interface
- Real-time status monitoring

### Success Criteria
- [ ] All Option A functionality works identically
- [ ] Recording starts in < 50ms (vs 1-2s)
- [ ] ydotool typing behaves exactly as Option A
- [ ] Text cleanup matches Option A exactly
- [ ] Supports original Super+Space workflow
- [ ] Backward compatible with Option A scripts

## All Needed Context

### Working Option A Implementation Details

```bash
# Critical fixes from development that must be preserved:

1. Typing tool preference (lines 26-34):
   if command -v ydotool &>/dev/null; then
       typing_tool="ydotool"  # Prefer ydotool for GNOME
   elif command -v wtype &>/dev/null; then
       typing_tool="wtype"

2. Audio recording with gain (lines 59-65):
   rec -q "$output" \
       rate 16000 \
       channels 1 \
       gain +15 \  # Critical for DJI MIC MINI
       silence 1 "$SILENCE_START" "$SILENCE_THRESHOLD" \
               1 "$SILENCE_STOP" "$SILENCE_THRESHOLD"

3. Text cleanup (lines 118-119):
   # Remove ALL newlines to prevent Enter key
   text=$(echo "$text" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

4. ydotool typing fix (lines 140-141):
   # Use --file to avoid shell interpretation
   echo -n "$text" | ydotool type --file -

5. Clipboard fallback messaging (lines 183-184):
   notify-send "Vocoder" "Typing failed - text copied to clipboard! Press Ctrl+V" -t 3000
```

### Documentation & References

```yaml
- url: Your working Option A at /home/ice/dev/vocoder/scripts/whisper-dictate.sh
  why: Base implementation with all fixes
  critical: Must preserve exact behavior

- url: http://127.0.0.1:8765/v1/transcribe
  why: Same Whisper API as Option A
  critical: Already configured and working

- url: https://www.freedesktop.org/software/systemd/man/systemd.service.html
  why: User service for daemon
  critical: Type=notify for proper startup
```

## Implementation Blueprint

### Core Daemon (Python) - Preserving Option A Logic

```python
#!/usr/bin/env python3
"""
vocoder - Daemon version of working Option A dictation
Preserves all fixes: ydotool preference, gain boost, text cleanup
"""

import asyncio
import subprocess
import tempfile
import json
import os
import signal
from pathlib import Path
from dataclasses import dataclass
from typing import Optional
import logging
from systemd import daemon
import numpy as np
import sounddevice as sd
import httpx

@dataclass
class Config:
    """Configuration matching Option A's working parameters"""
    whisper_url: str = "http://127.0.0.1:8765/v1/transcribe"
    sample_rate: int = 16000
    channels: int = 1
    audio_gain: float = 15.0  # Matching Option A's gain +15
    silence_start: float = 0.5
    silence_stop: float = 2.0
    silence_threshold: float = 0.02  # 2% as amplitude
    max_duration: int = 30
    typing_tool_preference: list = ("ydotool", "wtype")  # ydotool first!
    socket_path: str = "/run/user/1000/vocoder.sock"

class AudioRecorder:
    """Reimplements Option A's recording logic with gain"""
    
    def __init__(self, config: Config):
        self.config = config
        self.recording = False
        self.audio_buffer = []
        self.silence_counter = 0
        
    def audio_callback(self, indata, frames, time, status):
        """Process audio with gain matching Option A's rec gain +15"""
        if self.recording:
            # Apply gain (convert dB to amplitude multiplier)
            gain_multiplier = 10 ** (self.config.audio_gain / 20)
            audio_data = indata * gain_multiplier
            
            # Clip to prevent overflow
            audio_data = np.clip(audio_data, -1.0, 1.0)
            
            # Silence detection (matching Option A)
            rms = np.sqrt(np.mean(audio_data**2))
            
            if rms < self.config.silence_threshold:
                self.silence_counter += frames / self.config.sample_rate
            else:
                self.silence_counter = 0
                
            self.audio_buffer.append(audio_data.copy())
            
            # Auto-stop on silence (matching Option A's behavior)
            if self.silence_counter >= self.config.silence_stop:
                self.stop_recording()
    
    def start_recording(self):
        """Start recording with Option A's parameters"""
        self.recording = True
        self.audio_buffer = []
        self.silence_counter = 0
        
        self.stream = sd.InputStream(
            callback=self.audio_callback,
            channels=self.config.channels,
            samplerate=self.config.sample_rate,
            blocksize=1024
        )
        self.stream.start()
        
        # Play start sound (Option A compatibility)
        self.play_sound("start")
        self.notify("Recording... (speak now)", 2000)
        
    def stop_recording(self):
        """Stop and return audio matching Option A's format"""
        self.recording = False
        if hasattr(self, 'stream'):
            self.stream.stop()
            self.stream.close()
        
        self.play_sound("stop")
        
        if self.audio_buffer:
            return np.concatenate(self.audio_buffer)
        return None
    
    def play_sound(self, sound_type):
        """Play sounds exactly as Option A does"""
        sounds = {
            "start": "/usr/share/sounds/freedesktop/stereo/message.oga",
            "stop": "/usr/share/sounds/freedesktop/stereo/complete.oga",
            "error": "/usr/share/sounds/freedesktop/stereo/dialog-error.oga"
        }
        if sound_type in sounds:
            subprocess.Popen(
                ["paplay", sounds[sound_type]], 
                stderr=subprocess.DEVNULL
            )
    
    def notify(self, message, timeout=None):
        """Send notifications like Option A"""
        cmd = ["notify-send", "Vocoder", message]
        if timeout:
            cmd.extend(["-t", str(timeout)])
        subprocess.Popen(cmd)

class WhisperClient:
    """Maintains warm connection to Whisper API"""
    
    def __init__(self, config: Config):
        self.config = config
        self.client = httpx.AsyncClient(
            timeout=30.0,
            limits=httpx.Limits(keepalive_expiry=60)
        )
    
    async def transcribe(self, audio_data: np.ndarray) -> Optional[str]:
        """Transcribe using same API as Option A"""
        # Convert to WAV format as Option A does
        import wave
        import io
        
        wav_buffer = io.BytesIO()
        with wave.open(wav_buffer, 'wb') as wav:
            wav.setnchannels(self.config.channels)
            wav.setsampwidth(2)
            wav.setframerate(self.config.sample_rate)
            # Convert float to int16 as Option A does
            audio_int16 = (audio_data * 32767).astype(np.int16)
            wav.writeframes(audio_int16.tobytes())
        
        wav_buffer.seek(0)
        
        # Same API call as Option A
        files = {'file': ('audio.wav', wav_buffer, 'audio/wav')}
        data = {
            'format': 'json',
            'language': 'en',
            'diarize': 'false'
        }
        
        try:
            response = await self.client.post(
                self.config.whisper_url,
                files=files,
                data=data
            )
            
            if response.status_code == 200:
                result = response.json()
                text = result.get('text', '').strip()
                
                # CRITICAL: Apply Option A's text cleanup
                # Remove ALL newlines to prevent Enter key
                import re
                text = text.replace('\n', ' ').replace('\r', '')
                text = re.sub(r'^\s+|\s+$', '', text)
                
                return text
            
        except Exception as e:
            logging.error(f"Transcription error: {e}")
            return None

class TypingHandler:
    """Implements Option A's typing logic exactly"""
    
    def __init__(self, config: Config):
        self.config = config
        self.typing_tool = self.detect_typing_tool()
    
    def detect_typing_tool(self):
        """Use Option A's preference: ydotool first, then wtype"""
        for tool in self.config.typing_tool_preference:
            if subprocess.run(
                ["which", tool], 
                capture_output=True
            ).returncode == 0:
                return tool
        return None
    
    async def type_text(self, text: str) -> bool:
        """Type text using Option A's exact method"""
        if not self.typing_tool:
            return False
        
        try:
            if self.typing_tool == "ydotool":
                # Check if daemon is running (Option A logic)
                if subprocess.run(
                    ["pgrep", "-x", "ydotoold"],
                    capture_output=True
                ).returncode != 0:
                    subprocess.run(
                        ["systemctl", "--user", "start", "ydotoold"],
                        capture_output=True
                    )
                    await asyncio.sleep(0.5)
                
                # CRITICAL: Use --file - flag as Option A does
                proc = await asyncio.create_subprocess_exec(
                    "ydotool", "type", "--file", "-",
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                # Send text without newline
                stdout, stderr = await proc.communicate(text.encode())
                return proc.returncode == 0
                
            elif self.typing_tool == "wtype":
                # Use printf to ensure no trailing newline (Option A method)
                proc = await asyncio.create_subprocess_exec(
                    "wtype", "-",
                    stdin=asyncio.subprocess.PIPE,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE
                )
                stdout, stderr = await proc.communicate(text.encode())
                return proc.returncode == 0
                
        except Exception as e:
            logging.error(f"Typing error: {e}")
            return False
    
    async def copy_to_clipboard(self, text: str):
        """Fallback to clipboard exactly as Option A"""
        try:
            proc = await asyncio.create_subprocess_exec(
                "wl-copy",
                stdin=asyncio.subprocess.PIPE
            )
            await proc.communicate(text.encode())
            # Use Option A's exact notification message
            subprocess.run([
                "notify-send", "Vocoder", 
                "Typing failed - text copied to clipboard! Press Ctrl+V",
                "-t", "3000"
            ])
            return True
        except:
            return False

class VocoderDaemon:
    """Main daemon preserving Option A's workflow"""
    
    def __init__(self):
        self.config = Config()
        self.recorder = AudioRecorder(self.config)
        self.whisper = WhisperClient(self.config)
        self.typer = TypingHandler(self.config)
        self.running = True
    
    async def process_dictation(self):
        """Execute Option A's workflow"""
        # Record audio
        self.recorder.start_recording()
        
        # Wait for recording to complete (silence detection)
        while self.recorder.recording:
            await asyncio.sleep(0.1)
        
        # Get audio data
        audio_data = self.recorder.audio_buffer
        if not audio_data:
            subprocess.run([
                "notify-send", "Vocoder", "No speech detected"
            ])
            return
        
        audio_array = np.concatenate(audio_data)
        
        # Transcribe
        text = await self.whisper.transcribe(audio_array)
        if not text:
            subprocess.run([
                "notify-send", "Vocoder Error", "No transcription received"
            ])
            self.recorder.play_sound("error")
            return
        
        # Type text (with Option A's fallback logic)
        if await self.typer.type_text(text):
            # Success notification as Option A
            subprocess.run([
                "notify-send", "Vocoder", 
                f"Transcribed: {len(text)} chars",
                "-t", "1000"
            ])
        else:
            # Fallback to clipboard
            await self.typer.copy_to_clipboard(text)
    
    async def handle_command(self, command: str):
        """Process commands from vocoderctl"""
        if command == "start" or command == "toggle":
            await self.process_dictation()
        elif command == "status":
            return {"status": "running", "typing_tool": self.typer.typing_tool}
        elif command == "stop":
            self.running = False
    
    async def run(self):
        """Main daemon loop"""
        # Notify systemd we're ready
        daemon.notify("READY=1")
        
        # Set up IPC socket
        socket_path = Path(self.config.socket_path)
        socket_path.unlink(missing_ok=True)
        
        server = await asyncio.start_unix_server(
            self.handle_client,
            path=str(socket_path)
        )
        
        async with server:
            await server.serve_forever()
    
    async def handle_client(self, reader, writer):
        """Handle vocoderctl connections"""
        data = await reader.read(1024)
        command = data.decode().strip()
        
        result = await self.handle_command(command)
        
        if result:
            writer.write(json.dumps(result).encode())
        else:
            writer.write(b"OK")
        
        await writer.drain()
        writer.close()

# === Entry point ===
async def main():
    logging.basicConfig(level=logging.INFO)
    daemon = VocoderDaemon()
    await daemon.run()

if __name__ == "__main__":
    asyncio.run(main())
```

### CLI Client (vocoderctl) - Simple Interface

```bash
#!/usr/bin/env bash
# vocoderctl - Control client for vocoder daemon

SOCKET="/run/user/1000/vocoder.sock"
COMMAND="${1:-toggle}"

case "$COMMAND" in
    start|stop|toggle|status)
        echo "$COMMAND" | nc -U "$SOCKET"
        ;;
    *)
        echo "Usage: vocoderctl {start|stop|toggle|status}"
        exit 1
        ;;
esac
```

### Systemd Service

```ini
[Unit]
Description=Vocoder Daemon (Option B preserving Option A fixes)
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=notify
ExecStart=/usr/bin/python3 /home/ice/dev/vocoder/bin/vocoder
Restart=always
RestartSec=5
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=default.target
```

### Keybinding Compatibility

```bash
#!/bin/bash
# Update keybinding to use vocoderctl while preserving Super+Space

KEYBIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vocoder/"

# Keep Super+Space but use vocoderctl
gsettings set ... command "vocoderctl toggle"
gsettings set ... binding '<Super>space'  # Same as Option A!
```

## Task Checklist

### Implementation Tasks
- [ ] Create daemon that preserves Option A's recording logic
- [ ] Implement gain +15 in audio processing
- [ ] Maintain exact text cleanup (remove ALL newlines)
- [ ] Use ydotool with --file - flag
- [ ] Keep same notification messages
- [ ] Preserve clipboard fallback behavior
- [ ] Test typing matches Option A exactly
- [ ] Ensure backward compatibility

### Migration Tasks
- [ ] Keep Option A script as fallback
- [ ] Update keybinding to use vocoderctl
- [ ] Test side-by-side with Option A
- [ ] Document any behavior differences
- [ ] Create rollback procedure

## Validation Loop

### Level 1: Compatibility Testing
```bash
# Test that daemon produces same output as Option A
./scripts/whisper-dictate.sh  # Record "Hello world"
vocoderctl toggle             # Record "Hello world"
# Both should type identical text without newlines
```

### Level 2: Performance Testing
```bash
# Measure startup time
time vocoderctl toggle  # Should be < 50ms
time ./scripts/whisper-dictate.sh  # Current ~1-2s
```

### Level 3: Feature Parity
```bash
# Test all Option A scenarios:
# 1. Normal dictation
# 2. Empty speech (should show "No speech detected")
# 3. Typing failure (should fallback to clipboard)
# 4. Long speech (30 second timeout)
# 5. Audio feedback (start/stop sounds)
```

## Migration Strategy

### Safe Migration Path
1. **Install daemon alongside Option A** (different binary names)
2. **Test with secondary keybinding** (e.g., Super+Shift+Space)
3. **Run in parallel for a week** to verify stability
4. **Switch primary keybinding** when confident
5. **Keep Option A as backup** indefinitely

### Rollback Plan
```bash
# If daemon has issues, instant rollback:
systemctl --user stop vocoder
gsettings set ... command "/home/ice/dev/vocoder/scripts/whisper-dictate.sh"
# Back to Option A in seconds
```

## Critical Success Factors

### Must Preserve from Option A
1. **ydotool preference** - Works on GNOME
2. **Gain boost** - Critical for your microphone
3. **Text cleanup** - No unwanted newlines
4. **Exact notifications** - User familiarity
5. **Clipboard fallback** - Safety net

### New Benefits
1. **Instant response** - No startup delay
2. **Persistent connection** - Whisper stays warm
3. **Advanced control** - vocoderctl interface
4. **Future-ready** - Foundation for push-to-talk

---

*This PRP ensures Option B builds on the proven Option A implementation, preserving all fixes while adding professional features.*