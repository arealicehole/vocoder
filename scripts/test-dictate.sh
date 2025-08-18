#!/bin/bash
# Simple test script for dictation

echo "Recording for 3 seconds... Speak now!"
rec -q /tmp/test_dictate.wav rate 16000 channels 1 trim 0 3 gain +15

echo "Recording complete. Transcribing..."
result=$(curl -s -X POST -F "file=@/tmp/test_dictate.wav" -F "format=text" http://127.0.0.1:8765/v1/transcribe)

if [[ -n "$result" ]]; then
    echo "Transcribed: $result"
    echo -n "$result" | wl-copy
    echo "Text copied to clipboard!"
else
    echo "No speech detected"
fi

rm -f /tmp/test_dictate.wav