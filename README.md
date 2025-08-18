# Vocoder - Voice Dictation System

## 🎉 Current Status: WORKING!

The vocoder dictation system is **fully operational**:
- ✅ All dependencies installed and verified
- ✅ Audio recording tested and working
- ✅ Whisper API running with GPU acceleration
- ✅ Hotkey configured (Super + Space)
- ✅ ydotool typing confirmed working on GNOME
- ✅ Successfully transcribing and typing text

## What This Is

A hotkey-triggered voice dictation system for Linux that:
- Records your voice when you press **Super + Space**
- Transcribes it using a local Whisper API 
- Types the text directly where your cursor is focused
- Works on GNOME/Wayland with ydotool

## What Happened Today (Implementation Journey)

### The Problem
You wanted to implement "Option A" from the PRP - a simple hotkey dictation system, but the Whisper API service wasn't running and needed to be set up from scratch.

### What We Built

1. **Created the Whisper FastAPI Service** (`/home/ice/whisper-api/main.py`)
   - Full REST API with GPU acceleration (RTX 5060 Ti)
   - Supports both sync (`/v1/transcribe`) and async (`/v2/transcript`) endpoints
   - Multi-format output (json, text, vtt, srt)
   - Speaker diarization capability (though currently disabled due to PyTorch/CUDA compatibility)

2. **Set Up systemd Service** (`~/.config/systemd/user/whisper-api.service`)
   - Auto-starts on boot
   - Runs on http://127.0.0.1:8765
   - Uses the whisper312 venv with all dependencies

3. **Fixed the Dictation Script** (`scripts/whisper-dictate.sh`)
   - Switched from wtype to ydotool (wtype doesn't work with GNOME)
   - Fixed the unwanted Enter key press issue
   - Added proper text cleanup to remove newlines
   - Implemented clipboard fallback when typing fails

4. **Configured Hotkey**
   - Set up **Super + Space** to trigger dictation
   - Works system-wide in any text field

### Issues We Solved

- ❌ "Unit whisper-api.service not found" → ✅ Created complete service from scratch
- ❌ "Compositor does not support virtual keyboard" → ✅ Switched to ydotool
- ❌ Text was adding unwanted Enter keys → ✅ Used `--file -` flag and stripped newlines
- ❌ ydotoold wasn't running → ✅ Created startup script
- ❌ Recording missed beginning of speech → ✅ Removed delay, record immediately
- ❌ Empty transcription results (intermittent) → ✅ Fixed with:
  - Disabled aggressive VAD filter
  - Added +15 gain boost for DJI MIC MINI
  - Switched from medium to tiny model (HuggingFace auth issues)
  - Added initial_prompt to guide model
  - Lowered no_speech_threshold for better detection
- ❌ PyTorch CUDA compatibility → ⚠️ RTX 5060 Ti not fully supported yet (but transcription works!)

## How to Use

### Prerequisites (Already Done)
- ✅ Whisper API service is running: `systemctl --user status whisper-api.service`
- ✅ ydotoold daemon is running: `systemctl --user status ydotoold` or `./scripts/start-ydotoold.sh`
- ✅ Hotkey is configured: **Super + Space**

### Using Voice Dictation

1. **Focus on any text field** (browser, editor, terminal, etc.)
2. **Press Super + Space**
3. **Speak when you see the notification** "Recording... (speak now)"
4. **Stop speaking** - it auto-detects silence after 2 seconds
5. **Text appears** where your cursor was

### Manual Testing
```bash
cd /home/ice/dev/vocoder
./scripts/whisper-dictate.sh
```

## Technical Details

### Components
- **Whisper API**: FastAPI service using faster-whisper with CUDA
- **Audio Recording**: sox with silence detection
- **Keyboard Typing**: ydotool (works with Wayland)
- **Hotkey Binding**: GNOME settings-daemon custom keybinding

### File Structure
```
/home/ice/dev/vocoder/
├── scripts/
│   ├── whisper-dictate.sh          # Main dictation script (with your improvements)
│   ├── whisper-dictate-clipboard.sh # Clipboard-only fallback
│   ├── setup-keybinding.sh         # Configure GNOME hotkey
│   ├── install-deps.sh             # Dependency checker
│   ├── start-whisper.sh            # Start Whisper API helper
│   └── start-ydotoold.sh           # Start typing daemon
└── README.md                        # This file

/home/ice/whisper-api/
└── main.py                          # FastAPI Whisper service

/home/ice/.config/systemd/user/
├── whisper-api.service              # Whisper API systemd service
└── ydotoold.service                 # Typing daemon service
```

### Configuration
- **Whisper Model**: tiny (fast and reliable, medium had auth issues)
- **Audio Format**: 16kHz mono WAV with +15 gain boost
- **Max Recording**: 30 seconds (configurable)
- **Silence Detection**: 2 seconds of silence stops recording
- **API Port**: 8765
- **Special Settings**:
  - VAD disabled (was too aggressive)
  - no_speech_threshold: 0.6 (more lenient)
  - initial_prompt added for better guidance

## Troubleshooting

### If dictation doesn't work
1. Check Whisper API: `curl http://127.0.0.1:8765/health`
2. Check ydotoold: `pgrep ydotoold`
3. Test manually: `./scripts/whisper-dictate.sh`

### If text doesn't type
- ydotool needs ydotoold daemon running
- Fallback: Text will be copied to clipboard, paste with Ctrl+V

### If recording doesn't start
- Check microphone: `rec test.wav`
- Check PulseAudio: `pactl info`

## Next Steps
- Could add punctuation commands
- Could add voice commands for formatting
- Could integrate with more applications
- Fix PyTorch CUDA compatibility for speaker diarization

---
*Built with the PRP framework - Product Requirement Prompts for AI-driven development*