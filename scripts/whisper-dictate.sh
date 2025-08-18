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
    
    # Determine typing tool (prefer ydotool for GNOME)
    if command -v ydotool &>/dev/null; then
        typing_tool="ydotool"
    elif command -v wtype &>/dev/null; then
        typing_tool="wtype"
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
            start) paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null & ;;
            stop)  paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null & ;;
            error) paplay /usr/share/sounds/freedesktop/stereo/dialog-error.oga 2>/dev/null & ;;
        esac
    fi
}

# === Recording Function ===
record_audio() {
    local output="$1"
    
    # Notify start
    notify-send "Vocoder" "Recording... (speak now)" -t 2000 &
    play_sound start
    
    # Record with silence detection AND gain boost for better pickup
    timeout "${MAX_DURATION}s" rec -q "$output" \
        rate 16000 \
        channels 1 \
        gain +15 \
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
    
    # Clean up text (remove ALL leading/trailing whitespace including newlines)
    text=$(echo "$text" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    echo "$text"
}

# === Typing Function ===
type_text() {
    local text="$1"
    local tool="$2"
    
    case "$tool" in
        wtype)
            # Use printf to ensure no trailing newline
            printf "%s" "$text" | wtype -
            ;;
        ydotool)
            # Check if daemon is running
            if ! pgrep -x ydotoold &>/dev/null; then
                systemctl --user start ydotoold 2>/dev/null || true
                sleep 0.5
            fi
            # Use --file to avoid shell interpretation and ensure no enter key
            echo -n "$text" | ydotool type --file -
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
    
    # Try to type the text directly
    if type_text "$transcribed_text" "$typing_tool"; then
        # Success notification (brief)
        notify-send "Vocoder" "Transcribed: ${#transcribed_text} chars" -t 1000
    else
        # Fallback to clipboard if typing fails
        if command -v wl-copy &>/dev/null; then
            echo -n "$transcribed_text" | wl-copy
            notify-send "Vocoder" "Typing failed - text copied to clipboard! Press Ctrl+V" -t 3000
        else
            notify-send "Vocoder Error" "Could not type or copy text"
            exit 1
        fi
    fi
}

# Run main function
main "$@"