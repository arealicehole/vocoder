#!/usr/bin/env bash
# install-deps.sh - Check and install dependencies for vocoder dictation

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "Vocoder Dictation - Dependency Checker"
echo "======================================"
echo ""

# Track if all dependencies are met
ALL_DEPS_MET=true

# Function to check command availability
check_command() {
    local cmd="$1"
    local package="$2"
    local required="${3:-true}"
    
    if command -v "$cmd" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $cmd is installed"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            echo -e "${RED}✗${NC} $cmd is missing (install with: sudo dnf install $package)"
            ALL_DEPS_MET=false
        else
            echo -e "${YELLOW}⚠${NC} $cmd is optional but recommended (install with: sudo dnf install $package)"
        fi
        return 1
    fi
}

# Function to check Whisper API
check_whisper_api() {
    local url="http://127.0.0.1:8765/health"
    echo -n "Checking Whisper API at $url... "
    
    if curl -s -f -m 2 "$url" &>/dev/null; then
        local response=$(curl -s "$url")
        if echo "$response" | grep -q '"ok"'; then
            echo -e "${GREEN}✓ API is healthy${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ API responded but may not be healthy${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ API is not accessible${NC}"
        echo "  Make sure the Whisper service is running:"
        echo "  systemctl --user status whisper-api.service"
        ALL_DEPS_MET=false
        return 1
    fi
}

echo "Checking Core Dependencies:"
echo "--------------------------"
check_command "sox" "sox" "true"
check_command "rec" "sox" "true"  # rec is part of sox
check_command "curl" "curl" "true"
check_command "jq" "jq" "true"

echo ""
echo "Checking Typing Tools (need at least one):"
echo "------------------------------------------"
TYPING_AVAILABLE=false

if check_command "wtype" "wtype" "false"; then
    TYPING_AVAILABLE=true
fi

if check_command "ydotool" "ydotool" "false"; then
    TYPING_AVAILABLE=true
    # Check if ydotoold daemon is available
    if systemctl --user list-unit-files | grep -q ydotoold; then
        echo "  ydotoold service is available"
    else
        echo -e "  ${YELLOW}Note: ydotoold daemon needs to be running for ydotool${NC}"
    fi
fi

if [[ "$TYPING_AVAILABLE" == "false" ]]; then
    echo -e "${RED}✗ No typing tool available!${NC}"
    echo "  Install at least one of: wtype or ydotool"
    ALL_DEPS_MET=false
fi

echo ""
echo "Checking Optional Dependencies:"
echo "-------------------------------"
check_command "notify-send" "libnotify" "false"
check_command "paplay" "pulseaudio-utils" "false"
check_command "wl-copy" "wl-clipboard" "false"

echo ""
echo "Checking Audio System:"
echo "---------------------"
if pactl info &>/dev/null; then
    echo -e "${GREEN}✓${NC} PulseAudio is running"
else
    echo -e "${YELLOW}⚠${NC} PulseAudio may not be running"
fi

# Test audio recording capability
echo -n "Testing audio recording... "
TEST_FILE="/tmp/vocoder-test-$$.wav"
if timeout 1s rec -q "$TEST_FILE" 2>/dev/null; then
    true  # Timeout is expected
fi
if [[ -f "$TEST_FILE" ]] && [[ -s "$TEST_FILE" ]]; then
    echo -e "${GREEN}✓ Audio recording works${NC}"
    rm -f "$TEST_FILE"
else
    echo -e "${RED}✗ Audio recording may not work${NC}"
    echo "  Check your microphone permissions and audio settings"
    ALL_DEPS_MET=false
fi

echo ""
echo "Checking Whisper Service:"
echo "------------------------"
check_whisper_api

echo ""
echo "Checking GNOME Environment:"
echo "--------------------------"
if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    echo -e "${GREEN}✓${NC} Running on Wayland"
else
    echo -e "${YELLOW}⚠${NC} Not running on Wayland (detected: ${XDG_SESSION_TYPE:-unknown})"
fi

if [[ "$DESKTOP_SESSION" == *"gnome"* ]] || [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
    echo -e "${GREEN}✓${NC} GNOME desktop detected"
else
    echo -e "${YELLOW}⚠${NC} GNOME not detected (keybindings may not work)"
fi

echo ""
echo "======================================"
if [[ "$ALL_DEPS_MET" == "true" ]]; then
    echo -e "${GREEN}✅ All required dependencies are met!${NC}"
    echo ""
    echo "You can now:"
    echo "1. Set up the keybinding: ./scripts/setup-keybinding.sh"
    echo "2. Test manually: ./scripts/whisper-dictate.sh"
else
    echo -e "${RED}❌ Some dependencies are missing${NC}"
    echo ""
    echo "Install missing dependencies with:"
    echo "sudo dnf install sox curl jq wtype"
    echo ""
    echo "For the Whisper service, check:"
    echo "systemctl --user status whisper-api.service"
fi
echo "======================================"