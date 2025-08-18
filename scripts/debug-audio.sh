#!/bin/bash
# Debug script to test audio recording and transcription

echo "=== Audio Debug Script ==="
echo

# Test 1: Simple recording
echo "Test 1: Recording 3 seconds of audio..."
echo "SPEAK NOW!"
rec /tmp/debug_test1.wav rate 16000 channels 1 trim 0 3 2>/dev/null

# Check file size
size1=$(stat -c%s /tmp/debug_test1.wav 2>/dev/null)
echo "File size: $size1 bytes"

# Check audio properties
echo "Audio properties:"
soxi /tmp/debug_test1.wav 2>/dev/null || echo "Could not read properties"

# Test transcription
echo "Transcribing..."
result1=$(curl -s -X POST -F "file=@/tmp/debug_test1.wav" -F "format=json" http://127.0.0.1:8765/v1/transcribe)
echo "Result: $result1"
echo

# Test 2: Recording with higher volume
echo "Test 2: Recording with gain boost..."
echo "SPEAK NOW!"
rec /tmp/debug_test2.wav rate 16000 channels 1 trim 0 3 gain +10 2>/dev/null

size2=$(stat -c%s /tmp/debug_test2.wav 2>/dev/null)
echo "File size: $size2 bytes"

echo "Transcribing with gain..."
result2=$(curl -s -X POST -F "file=@/tmp/debug_test2.wav" -F "format=json" http://127.0.0.1:8765/v1/transcribe)
echo "Result: $result2"
echo

# Test 3: Check if audio has actual sound
echo "Test 3: Checking audio levels..."
sox /tmp/debug_test1.wav -n stat 2>&1 | grep -E "Maximum amplitude|RMS"
echo

# Test 4: Convert to different format
echo "Test 4: Converting audio format..."
ffmpeg -i /tmp/debug_test1.wav -ar 16000 -ac 1 -f wav /tmp/debug_test3.wav -y 2>/dev/null
echo "Transcribing converted audio..."
result3=$(curl -s -X POST -F "file=@/tmp/debug_test3.wav" -F "format=json" http://127.0.0.1:8765/v1/transcribe)
echo "Result: $result3"
echo

# Test 5: Direct API test with known working file
echo "Test 5: Testing with the previous working file..."
if [ -f /tmp/test_audio.wav ]; then
    result4=$(curl -s -X POST -F "file=@/tmp/test_audio.wav" -F "format=json" http://127.0.0.1:8765/v1/transcribe)
    echo "Known good file result: $result4"
else
    echo "Previous test file not found"
fi

echo
echo "=== Debug Complete ==="
echo "Check which tests produced transcriptions"