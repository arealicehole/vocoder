name: "Vocoder Option A - Linux Hotkey-Driven Dictation Script"
description: |
  Comprehensive PRP for implementing a single-shot hotkey-triggered dictation script
  that records audio, transcribes via local Whisper API, and types output directly
  into the focused text field on GNOME Wayland.

---

## Goal

**Feature Goal**: Implement a hotkey-triggered voice dictation system that captures speech, transcribes it via local Whisper API, and types the result directly into the currently focused text field.

**Deliverable**: 
- `scripts/whisper-dictate.sh` - Main dictation script
- GNOME gsettings keybinding configuration
- Installation script for dependencies

**Success Definition**: User presses Super+D, speaks naturally, silence triggers transcription, and text appears in the active text field within 2 seconds of stopping speech.

## User Persona

**Target User**: Linux desktop users (developers, writers, accessibility users) on GNOME Wayland

**Use Case**: Quick voice input while coding, writing documentation, or composing emails without switching contexts

**User Journey**: 
1. User positions cursor in target text field
2. Presses Super+D hotkey
3. Speaks naturally (visual/audio feedback indicates recording)
4. Stops speaking for 2 seconds
5. Transcribed text appears at cursor position
6. User continues typing or triggers again

**Pain Points Addressed**: 
- Eliminates need for clipboard-based workflows
- No manual start/stop required
- Works universally across all applications
- Maintains focus on current task

## Why

- **Accessibility**: Provides voice input for users with RSI or mobility limitations
- **Productivity**: 3x faster than typing for long-form content
- **Universal Compatibility**: Works with any text field in any application
- **Privacy-First**: Local processing, no cloud dependencies
- **Low Friction**: Single hotkey, automatic silence detection

## What

### Technical Requirements
- Record audio with automatic silence-based stopping
- Send WAV file to local Whisper API endpoint
- Type transcribed text directly into focused field
- Support both wtype and ydotool for maximum compatibility
- Visual/audio feedback for recording state

### Success Criteria
- [ ] Hotkey triggers recording within 100ms
- [ ] Silence detection stops recording after 2-3 seconds
- [ ] Transcription completes within 1 second (Whisper Tiny)
- [ ] Text types into active field without clipboard
- [ ] Script handles errors gracefully with notifications
- [ ] Works on GNOME Wayland (Fedora 42+)

## All Needed Context

### Context Completeness Check
_This PRP contains all sox parameters, Whisper API endpoints, typing utilities, and GNOME configuration needed for implementation._

### Whisper Service Configuration

```yaml
whisper_service:
  url: http://127.0.0.1:8765
  type: FastAPI with GPU acceleration (RTX 5060 Ti)
  model: medium (configurable via WHISPER_MODEL env)
  features:
    - Real-time transcription with float16 compute
    - Optional speaker diarization (diarize=true)
    - Multi-format output (json/text/vtt/srt)
    - Auto-language detection or explicit (language=en)
  api_format:
    field: "file" (not "audio")
    parameters:
      - format: json|text (default: json)
      - language: en|es|auto etc (default: en)
      - diarize: true|false (default: false)
      - num_speakers: integer (optional, for diarization)
```

### Documentation & References

```yaml
- url: https://sox.sourceforge.net/sox.html#silence
  why: Silence detection parameters for automatic recording stop
  critical: "silence 1 0.5 2% 1 2.0 2%" - start on 0.5s speech, stop on 2s silence

- url: https://github.com/atanunq/wtype
  why: Primary Wayland typing utility
  critical: GNOME may restrict virtual keyboard protocol, needs testing

- url: https://github.com/ReimuNotMoe/ydotool
  why: Fallback typing method if wtype fails
  critical: Requires ydotoold daemon running with proper permissions

- url: http://127.0.0.1:8765/v1/transcribe
  why: Local FastAPI Whisper service with GPU acceleration
  critical: Expects multipart/form-data with 'file' field (not 'audio')
```

### Code Examples & Patterns

```bash
# Recording with silence detection (sox)
rec -q "$TEMP_WAV" rate 16000 channels 1 \
    silence 1 0.5 2% 1 2.0 2% \
    trim 0 30  # Max 30 seconds

# Whisper API call (using local FastAPI service)
RESPONSE=$(curl -s -X POST \
    -F "file=@$TEMP_WAV" \
    -F "format=json" \
    -F "language=en" \
    -F "diarize=false" \
    "http://127.0.0.1:8765/v1/transcribe")

# Text extraction from JSON
TEXT=$(echo "$RESPONSE" | jq -r '.text // empty')

# Typing with wtype (primary)
echo -n "$TEXT" | wtype -

# Typing with ydotool (fallback)
ydotool type "$TEXT"
```

### Known Gotchas & Solutions

```yaml
gotchas:
  - issue: "wtype fails on GNOME Wayland"
    solution: "Check ydotool availability first, fallback gracefully"
    
  - issue: "Sox continues recording indefinitely"
    solution: "Add 'trim 0 30' to enforce 30-second maximum"
    
  - issue: "Whisper returns empty on short audio"
    solution: "Check audio duration, minimum 0.5 seconds"
    
  - issue: "Special characters break typing"
    solution: "Escape text properly: printf '%q' \"$TEXT\""
    
  - issue: "No audio feedback"
    solution: "Play subtle beep on start/stop using paplay"
```

## Implementation Blueprint

### Core Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail

# === Configuration ===
WHISPER_URL="${WHISPER_URL:-http://127.0.0.1:8765/v1/transcribe}"
TEMP_DIR="${XDG_RUNTIME_DIR:-/tmp}"
TEMP_WAV="$TEMP_DIR/vocoder-$$.wav"
MAX_DURATION=30
SILENCE_START="0.5"
SILENCE_STOP="2.0"
SILENCE_THRESHOLD="2%"

# === Dependencies Check ===
check_deps() {
    local deps=("sox" "curl" "jq")
    local typing_tool=""
    
    # Check core deps
    for dep in "${deps[@]}"; do
        command -v "$dep" &>/dev/null || {
            notify-send "Vocoder Error" "Missing: $dep"
            exit 1
        }
    done
    
    # Determine typing tool
    if command -v wtype &>/dev/null; then
        typing_tool="wtype"
    elif command -v ydotool &>/dev/null; then
        typing_tool="ydotool"
    else
        notify-send "Vocoder Error" "No typing tool found"
        exit 1
    fi
    
    echo "$typing_tool"
}

# === Audio Feedback ===
play_sound() {
    local sound="$1"
    if command -v paplay &>/dev/null; then
        case "$sound" in
            start) paplay /usr/share/sounds/freedesktop/stereo/message.oga & ;;
            stop)  paplay /usr/share/sounds/freedesktop/stereo/complete.oga & ;;
            error) paplay /usr/share/sounds/freedesktop/stereo/dialog-error.oga & ;;
        esac
    fi
}

# === Recording Function ===
record_audio() {
    local output="$1"
    
    # Notify start
    notify-send "Vocoder" "Recording... (speak now)" -t 2000 &
    play_sound start
    
    # Record with silence detection
    timeout "${MAX_DURATION}s" rec -q "$output" \
        rate 16000 \
        channels 1 \
        silence 1 "$SILENCE_START" "$SILENCE_THRESHOLD" \
                1 "$SILENCE_STOP" "$SILENCE_THRESHOLD" \
        2>/dev/null || {
            if [[ $? -eq 124 ]]; then
                notify-send "Vocoder" "Max recording time reached"
            else
                notify-send "Vocoder Error" "Recording failed"
                play_sound error
                return 1
            fi
        }
    
    # Check file exists and has content
    if [[ ! -f "$output" ]] || [[ ! -s "$output" ]]; then
        notify-send "Vocoder Error" "No audio recorded"
        play_sound error
        return 1
    fi
    
    play_sound stop
    return 0
}

# === Transcription Function ===
transcribe_audio() {
    local audio_file="$1"
    local response
    
    # Call Whisper API (FastAPI service with GPU acceleration)
    response=$(curl -s -X POST \
        -F "file=@$audio_file" \
        -F "format=json" \
        -F "language=en" \
        -F "diarize=false" \
        "$WHISPER_URL" 2>/dev/null) || {
            notify-send "Vocoder Error" "Transcription failed"
            play_sound error
            return 1
        }
    
    # Extract text from response
    local text
    text=$(echo "$response" | jq -r '.text // empty' 2>/dev/null)
    
    if [[ -z "$text" ]]; then
        # Fallback for plain text response
        if [[ "$response" =~ ^[[:print:]]+$ ]]; then
            text="$response"
        else
            notify-send "Vocoder Error" "No transcription received"
            play_sound error
            return 1
        fi
    fi
    
    # Clean up text (remove leading/trailing whitespace)
    text=$(echo "$text" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "$text"
}

# === Typing Function ===
type_text() {
    local text="$1"
    local tool="$2"
    
    case "$tool" in
        wtype)
            echo -n "$text" | wtype -
            ;;
        ydotool)
            # Check if daemon is running
            if ! pgrep -x ydotoold &>/dev/null; then
                systemctl --user start ydotoold 2>/dev/null || true
                sleep 0.5
            fi
            ydotool type "$text"
            ;;
        *)
            notify-send "Vocoder Error" "Unknown typing tool"
            return 1
            ;;
    esac
}

# === Cleanup Function ===
cleanup() {
    [[ -f "$TEMP_WAV" ]] && rm -f "$TEMP_WAV"
}

# === Main Execution ===
main() {
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Check dependencies and get typing tool
    local typing_tool
    typing_tool=$(check_deps)
    
    # Record audio
    if ! record_audio "$TEMP_WAV"; then
        exit 1
    fi
    
    # Transcribe audio
    local transcribed_text
    transcribed_text=$(transcribe_audio "$TEMP_WAV")
    
    if [[ -z "$transcribed_text" ]]; then
        notify-send "Vocoder" "No speech detected"
        exit 0
    fi
    
    # Type the text
    if ! type_text "$transcribed_text" "$typing_tool"; then
        # Fallback: copy to clipboard if typing fails
        if command -v wl-copy &>/dev/null; then
            echo -n "$transcribed_text" | wl-copy
            notify-send "Vocoder" "Copied to clipboard (typing failed)"
        fi
        exit 1
    fi
    
    # Success notification (brief)
    notify-send "Vocoder" "Transcribed: ${#transcribed_text} chars" -t 1000
}

# Run main function
main "$@"
```

### GNOME Keybinding Setup Script

```bash
#!/usr/bin/env bash
# setup-keybinding.sh

SCRIPT_PATH="$(realpath scripts/whisper-dictate.sh)"
KEYBIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vocoder/"

# Get existing bindings
EXISTING=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)

# Add our binding if not present
if [[ "$EXISTING" != *"$KEYBIND_PATH"* ]]; then
    if [[ "$EXISTING" == "@as []" ]] || [[ "$EXISTING" == "[]" ]]; then
        NEW="['$KEYBIND_PATH']"
    else
        NEW="${EXISTING%]}, '$KEYBIND_PATH']"
    fi
    gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW"
fi

# Configure the keybinding
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
    name 'Vocoder Dictation'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
    command "$SCRIPT_PATH"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"$KEYBIND_PATH" \
    binding '<Super>d'

echo "✓ Keybinding configured: Super+D → $SCRIPT_PATH"
```

## Task Checklist

### Implementation Tasks
- [ ] Create `scripts/whisper-dictate.sh` with full implementation
- [ ] Add dependency checking for sox, curl, jq, wtype/ydotool
- [ ] Implement recording with configurable silence detection
- [ ] Add Whisper API integration with error handling
- [ ] Implement dual typing methods (wtype primary, ydotool fallback)
- [ ] Add audio feedback for start/stop/error states
- [ ] Create keybinding setup script
- [ ] Add configuration file support (optional)

### Testing Tasks
- [ ] Test recording with various silence thresholds
- [ ] Verify Whisper API connectivity and response parsing
- [ ] Test typing in different applications (terminal, browser, editor)
- [ ] Verify GNOME keybinding activation
- [ ] Test error scenarios (no mic, API down, typing blocked)
- [ ] Measure end-to-end latency

## Validation Loop

### Level 1: Syntax & Dependencies
```bash
# Check bash syntax
shellcheck scripts/whisper-dictate.sh

# Verify dependencies
for cmd in sox curl jq wtype ydotool; do
    command -v $cmd &>/dev/null && echo "✓ $cmd" || echo "✗ $cmd"
done
```

### Level 2: Component Testing
```bash
# Test recording
rec test.wav silence 1 0.5 2% 1 2.0 2% trim 0 5
file test.wav  # Should show: RIFF (little-endian) data, WAVE audio

# Test Whisper API (FastAPI service)
curl -X POST -F "file=@test.wav" \
    -F "format=json" \
    http://127.0.0.1:8765/v1/transcribe

# Test typing tools
echo "test" | wtype -
ydotool type "test"
```

### Level 3: Integration Testing
```bash
# Full pipeline test
./scripts/whisper-dictate.sh

# Keybinding test
gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:\
/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vocoder/ binding
# Should output: '<Super>d'
```

### Level 4: User Acceptance
```bash
# Open text editor
gedit &

# Press Super+D
# Speak: "Hello world, this is a test."
# Verify text appears in editor

# Test in different apps
firefox &  # Test in web forms
gnome-terminal &  # Test in terminal
```

## Edge Cases & Error Handling

### Handled Scenarios
1. **No microphone access**: Notify user, exit gracefully
2. **Whisper API down**: Notify user, optionally save audio
3. **Typing blocked**: Fall back to clipboard
4. **Long recordings**: Enforce 30-second maximum
5. **Empty transcription**: Notify "no speech detected"
6. **Special characters**: Properly escape for shell
7. **Concurrent invocations**: Use PID-based temp files

### Recovery Strategies
```yaml
microphone_error:
  detection: sox returns error code
  recovery: Check PulseAudio/ALSA settings notification
  
api_timeout:
  detection: curl timeout after 10 seconds
  recovery: Save audio to ~/Documents/vocoder-failed/
  
typing_failure:
  detection: wtype and ydotool both fail
  recovery: Copy to clipboard with notification
```

## Performance Optimization

### Latency Targets
- Hotkey → Recording start: < 100ms
- Speech end → Transcription start: < 500ms  
- Transcription complete → Text typed: < 100ms
- **Total end-to-end**: < 2 seconds

### Optimization Strategies
1. **Pre-load dependencies**: Source functions in bashrc
2. **Reduce sample rate**: 16kHz sufficient for speech
3. **Local Whisper**: Ensure model cached in memory
4. **Parallel processing**: Start Whisper while still recording
5. **Minimal notifications**: Quick, non-blocking alerts

## Future Enhancements

### Planned Improvements
1. **Configuration file**: `~/.config/vocoder/config.yaml`
2. **Multiple languages**: Auto-detect or configurable
3. **Custom wake words**: "Computer, take a note"
4. **Punctuation commands**: "period", "comma", "new line"
5. **Undo support**: Track last insertion for removal
6. **Visual indicator**: Floating widget showing recording state
7. **Streaming transcription**: Send audio chunks in real-time

---

*This PRP provides comprehensive context for implementing a production-ready Linux dictation system with minimal friction and maximum reliability.*