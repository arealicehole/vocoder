#!/bin/bash
# Test vocoder end-to-end

echo "Testing vocoder system..."
echo "1. Checking service status..."
systemctl --user is-active vocoder.service || exit 1

echo "2. Testing recording with simple audio..."
# Start recording
python3 bin/vocoderctl toggle
echo "Recording started, speaking test..."

# Generate test audio (simple beep)
( speaker-test -t sine -f 800 -l 1 ) >/dev/null 2>&1 &

# Wait a bit
sleep 3

# Stop recording  
python3 bin/vocoderctl toggle
echo "Recording stopped"

echo "3. Checking status..."
python3 bin/vocoderctl status

echo "Test complete - check if any text was typed"