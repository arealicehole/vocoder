#!/bin/bash
# Test multiple times to check for intermittent issues

for i in {1..5}; do
    echo "Test $i:"
    
    # Record
    rec -q /tmp/multi_test_$i.wav rate 16000 channels 1 trim 0 2 gain +15 2>/dev/null
    
    # Transcribe
    result=$(curl -s -X POST -F "file=@/tmp/multi_test_$i.wav" -F "format=json" http://127.0.0.1:8765/v1/transcribe)
    
    # Check result
    text=$(echo "$result" | jq -r '.text // empty')
    duration=$(echo "$result" | jq -r '.duration // 0')
    
    echo "  Duration: $duration, Text: '$text'"
    
    if [[ -z "$text" ]]; then
        echo "  WARNING: Empty result!"
        echo "  Full response: $result"
    fi
    
    sleep 1
done

rm -f /tmp/multi_test_*.wav