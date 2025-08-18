#!/bin/bash
# Debug version to see what's happening with text

WHISPER_URL="http://127.0.0.1:8765/v1/transcribe"
TEMP_WAV="/tmp/debug_dictate.wav"

echo "Recording for 3 seconds... Say: 'Here's the test of my poop 1234567'"
rec -q "$TEMP_WAV" rate 16000 channels 1 trim 0 3 gain +15

echo "File created: $(stat -c%s "$TEMP_WAV") bytes"

# Get raw response
echo "Getting raw response..."
response=$(curl -s -X POST \
    -F "file=@$TEMP_WAV" \
    -F "format=json" \
    -F "language=en" \
    -F "diarize=false" \
    "$WHISPER_URL")

echo "Raw response:"
echo "$response"
echo

# Extract text using jq
echo "Extracting text with jq..."
text=$(echo "$response" | jq -r '.text // empty' 2>/dev/null)
echo "After jq: [$text]"
echo "Length: ${#text}"
echo

# Try without cleanup
echo "Raw text: [$text]"

# Try with original cleanup
text_cleaned=$(echo "$text" | tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
echo "After cleanup: [$text_cleaned]"
echo "Length after cleanup: ${#text_cleaned}"

rm -f "$TEMP_WAV"