#!/usr/bin/env bash
set -euo pipefail

# Simple dictation script that uses clipboard instead of typing

WHISPER_URL="${WHISPER_URL:-http://127.0.0.1:8765/v1/transcribe}"
TEMP_WAV="/tmp/vocoder-$$.wav"

# Cleanup on exit
trap 'rm -f "$TEMP_WAV"' EXIT

# Start recording notification
notify-send "Vocoder" "Recording... (speak now)" -t 2000 &

# Record audio (3 seconds or until silence)
rec -q "$TEMP_WAV" rate 16000 channels 1 silence 1 0.5 2% 1 2.0 2% trim 0 10 2>/dev/null || true

# Check if file exists
if [[ ! -f "$TEMP_WAV" ]] || [[ ! -s "$TEMP_WAV" ]]; then
    notify-send "Vocoder" "No audio recorded"
    exit 1
fi

# Transcribe
response=$(curl -s -X POST \
    -F "file=@$TEMP_WAV" \
    -F "format=text" \
    "$WHISPER_URL" 2>/dev/null)

if [[ -z "$response" ]]; then
    notify-send "Vocoder" "No speech detected"
    exit 0
fi

# Copy to clipboard
echo -n "$response" | wl-copy

notify-send "Vocoder" "Text copied! Press Ctrl+V to paste" -t 3000

echo "Transcribed: $response"