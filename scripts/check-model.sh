#!/usr/bin/env bash
# check-model.sh - Show which Whisper model is being used

echo "======================================"
echo "   Whisper Model Configuration"
echo "======================================"
echo ""

echo "Option A (bash script):"
grep -A1 "model=" scripts/whisper-dictate.sh | grep model || echo "  No model specified (uses API default)"
echo ""

echo "Option B (daemon):"
grep "'model':" bin/vocoder | head -1 || echo "  No model specified (uses API default)"
echo ""

echo "Available Whisper models (fastest to most accurate):"
echo "  • tiny    - Fastest, 39M params, good for dictation"
echo "  • base    - 74M params"
echo "  • small   - 244M params"
echo "  • medium  - 769M params"
echo "  • large   - 1550M params (large-v3 recommended)"
echo ""

echo "To change model:"
echo "  Option A: Edit scripts/whisper-dictate.sh line 99"
echo "  Option B: Edit bin/vocoder line 202"
echo "  Then restart: systemctl --user restart vocoder.service"
echo ""

echo "Note: 'tiny' is recommended for dictation - it's fast and accurate enough"
echo "======================================"