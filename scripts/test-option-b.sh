#!/usr/bin/env bash
# test-option-b.sh - Test that Option B daemon works correctly

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Option B Daemon Test Suite"
echo "======================================"
echo ""

PYTHON_CMD="${PYTHON_CMD:-python3}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test 1: Python dependencies
echo "1. Checking Python dependencies..."

# Check numpy
if $PYTHON_CMD -c "import numpy" 2>/dev/null; then
    echo -e "${GREEN}✓ numpy installed${NC}"
else
    echo -e "${RED}✗ numpy missing${NC}"
    echo "Install with: pip3 install numpy"
    exit 1
fi

# Check httpx
if $PYTHON_CMD -c "import httpx" 2>/dev/null; then
    echo -e "${GREEN}✓ httpx installed${NC}"
else
    echo -e "${RED}✗ httpx missing${NC}"
    echo "Install with: pip3 install httpx"
    exit 1
fi

# Check sounddevice (and PortAudio)
if $PYTHON_CMD -c "import sounddevice" 2>/dev/null; then
    echo -e "${GREEN}✓ sounddevice installed and PortAudio found${NC}"
else
    # Check if it's a PortAudio issue
    ERROR=$($PYTHON_CMD -c "import sounddevice" 2>&1)
    if echo "$ERROR" | grep -q "PortAudio"; then
        echo -e "${YELLOW}⚠ sounddevice installed but PortAudio library missing${NC}"
        echo "Install with: sudo dnf install portaudio portaudio-devel"
        echo "This is a system library required for audio recording"
        exit 1
    else
        echo -e "${RED}✗ sounddevice missing${NC}"
        echo "Install with: pip3 install sounddevice"
        exit 1
    fi
fi

# Test 2: Daemon can start
echo ""
echo "2. Testing daemon startup..."
timeout 3s $PYTHON_CMD "$PROJECT_DIR/bin/vocoder" &>/dev/null &
DAEMON_PID=$!
sleep 1

if kill -0 $DAEMON_PID 2>/dev/null; then
    echo -e "${GREEN}✓ Daemon starts successfully${NC}"
    
    # Test 3: Socket is created
    echo ""
    echo "3. Checking Unix socket..."
    SOCKET="/run/user/$(id -u)/vocoder.sock"
    if [[ -S "$SOCKET" ]]; then
        echo -e "${GREEN}✓ Socket created at $SOCKET${NC}"
    else
        echo -e "${RED}✗ Socket not found${NC}"
    fi
    
    # Test 4: vocoderctl communication
    echo ""
    echo "4. Testing vocoderctl..."
    if $PYTHON_CMD "$PROJECT_DIR/bin/vocoderctl" status | grep -q "running"; then
        echo -e "${GREEN}✓ vocoderctl can communicate with daemon${NC}"
    else
        echo -e "${RED}✗ vocoderctl communication failed${NC}"
    fi
    
    # Clean up daemon
    kill $DAEMON_PID 2>/dev/null || true
    wait $DAEMON_PID 2>/dev/null || true
else
    echo -e "${RED}✗ Daemon failed to start${NC}"
    echo "Debug with: $PYTHON_CMD $PROJECT_DIR/bin/vocoder"
    exit 1
fi

# Test 5: Check typing tool
echo ""
echo "5. Checking typing tool preference..."
if command -v ydotool &>/dev/null; then
    echo -e "${GREEN}✓ ydotool available (preferred)${NC}"
    if pgrep -x ydotoold &>/dev/null; then
        echo -e "${GREEN}✓ ydotoold daemon running${NC}"
    else
        echo -e "${YELLOW}⚠ ydotoold not running${NC}"
        echo "  Start with: systemctl --user start ydotoold"
    fi
elif command -v wtype &>/dev/null; then
    echo -e "${YELLOW}⚠ Only wtype available (may not work on GNOME)${NC}"
else
    echo -e "${RED}✗ No typing tool found${NC}"
fi

# Test 6: Audio system
echo ""
echo "6. Checking audio system..."
if pactl info &>/dev/null; then
    echo -e "${GREEN}✓ PulseAudio available${NC}"
else
    echo -e "${RED}✗ PulseAudio not available${NC}"
fi

# Test 7: Whisper API
echo ""
echo "7. Checking Whisper API..."
if curl -s -f "http://127.0.0.1:8765/health" &>/dev/null; then
    echo -e "${GREEN}✓ Whisper API is running${NC}"
else
    echo -e "${RED}✗ Whisper API not accessible${NC}"
    echo "  Start with: systemctl --user start whisper-api.service"
fi

# Test 8: Systemd service (if installed)
echo ""
echo "8. Checking systemd service..."
if systemctl --user list-unit-files | grep -q vocoder.service; then
    if systemctl --user is-active vocoder.service &>/dev/null; then
        echo -e "${GREEN}✓ vocoder.service is running${NC}"
    else
        echo -e "${YELLOW}⚠ vocoder.service installed but not running${NC}"
        echo "  Start with: systemctl --user start vocoder.service"
    fi
else
    echo -e "${YELLOW}⚠ vocoder.service not installed${NC}"
    echo "  Install with: ./scripts/setup-option-b.sh"
fi

# Summary
echo ""
echo "======================================"
echo "Test Summary"
echo "======================================"
echo ""

ALL_GOOD=true

if ! $PYTHON_CMD -c "import numpy, sounddevice, httpx" 2>/dev/null; then
    echo -e "${RED}✗ Fix: Install Python dependencies${NC}"
    ALL_GOOD=false
fi

if ! command -v ydotool &>/dev/null && ! command -v wtype &>/dev/null; then
    echo -e "${RED}✗ Fix: Install ydotool or wtype${NC}"
    ALL_GOOD=false
fi

if ! curl -s -f "http://127.0.0.1:8765/health" &>/dev/null; then
    echo -e "${RED}✗ Fix: Start Whisper API service${NC}"
    ALL_GOOD=false
fi

if [[ "$ALL_GOOD" == "true" ]]; then
    echo -e "${GREEN}✅ All core components working!${NC}"
    echo ""
    echo "Ready to use Option B:"
    echo "  1. Run setup: ./scripts/setup-option-b.sh"
    echo "  2. Or test manually: python3 bin/vocoder"
else
    echo -e "${RED}Fix the issues above before using Option B${NC}"
fi

echo "======================================"