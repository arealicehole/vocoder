#!/usr/bin/env bash
# check-status.sh - Show which vocoder option is active

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "======================================"
echo "   Vocoder Status Check"
echo "======================================"
echo ""

# 1. Check which hotkey is configured
echo -e "${BLUE}1. HOTKEY CONFIGURATION:${NC}"
BINDING=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding 2>/dev/null | tr -d "'")
COMMAND=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command 2>/dev/null | tr -d "'")

echo "   Hotkey: $BINDING"
if [[ "$COMMAND" == *"whisper-dictate.sh"* ]]; then
    echo -e "   Using: ${YELLOW}Option A${NC} (bash script)"
    echo "   Path: $COMMAND"
elif [[ "$COMMAND" == *"vocoderctl"* ]]; then
    echo -e "   Using: ${GREEN}Option B${NC} (daemon)"
    echo "   Path: $COMMAND"
else
    echo -e "   Using: ${RED}Unknown${NC}"
    echo "   Command: $COMMAND"
fi
echo ""

# 2. Check daemon status
echo -e "${BLUE}2. OPTION B DAEMON STATUS:${NC}"
if systemctl --user is-active vocoder.service &>/dev/null; then
    echo -e "   Service: ${GREEN}Running${NC}"
    PID=$(systemctl --user show vocoder.service --property=MainPID --value)
    echo "   PID: $PID"
    
    # Check socket
    SOCKET="/run/user/$(id -u)/vocoder.sock"
    if [[ -S "$SOCKET" ]]; then
        echo -e "   Socket: ${GREEN}Active${NC} at $SOCKET"
    else
        echo -e "   Socket: ${RED}Not found${NC}"
    fi
    
    # Test vocoderctl
    if python3 "$(dirname "$0")/../bin/vocoderctl" status 2>/dev/null | grep -q "running"; then
        echo -e "   Control: ${GREEN}vocoderctl working${NC}"
    else
        echo -e "   Control: ${YELLOW}vocoderctl not responding${NC}"
    fi
else
    echo -e "   Service: ${RED}Not running${NC}"
    if [[ -f "$HOME/.config/systemd/user/vocoder.service" ]]; then
        echo "   To start: systemctl --user start vocoder.service"
    else
        echo "   Not installed. Run: ./scripts/setup-option-b.sh"
    fi
fi
echo ""

# 3. Check which would actually run
echo -e "${BLUE}3. ACTUAL EXECUTION TEST:${NC}"
echo "   If you press $BINDING now, it will run:"
if [[ "$COMMAND" == *"whisper-dictate.sh"* ]]; then
    echo -e "   ${YELLOW}Option A${NC} - Takes 1-2 seconds to start"
    echo "   - Creates new rec process"
    echo "   - Connects to Whisper API fresh"
    echo "   - Types with ydotool/wtype"
elif [[ "$COMMAND" == *"vocoderctl"* ]]; then
    echo -e "   ${GREEN}Option B${NC} - Instant response (< 50ms)"
    echo "   - Uses running daemon"
    echo "   - Persistent Whisper connection"
    echo "   - Same typing method as Option A"
fi
echo ""

# 4. How to switch
echo -e "${BLUE}4. HOW TO SWITCH:${NC}"
if [[ "$COMMAND" == *"whisper-dictate.sh"* ]]; then
    echo "   Currently on Option A. To switch to Option B:"
    echo ""
    echo "   a) First ensure daemon is running:"
    echo "      systemctl --user status vocoder.service"
    echo ""
    echo "   b) Update keybinding to use daemon:"
    echo "      gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command \"python3 $PWD/bin/vocoderctl toggle\""
    echo ""
    echo "   c) Or use the setup script option:"
    echo "      ./scripts/setup-option-b.sh"
    echo "      (Choose option B when asked about keybindings)"
else
    echo "   Currently on Option B. To switch back to Option A:"
    echo ""
    echo "   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command \"$PWD/scripts/whisper-dictate.sh\""
fi
echo ""

# 5. Settings location
echo -e "${BLUE}5. CONFIGURATION FILES:${NC}"
echo "   Option A settings: Built into script"
echo "   - Audio gain: +15 (hardcoded)"
echo "   - Silence: 2 seconds (hardcoded)"
echo ""
echo "   Option B settings: config/vocoder.yaml"
if [[ -f "config/vocoder.yaml" ]]; then
    echo "   - Audio gain: $(grep gain_db config/vocoder.yaml | awk '{print $2}')"
    echo "   - Silence threshold: $(grep stop_threshold config/vocoder.yaml | awk '{print $2}')"
    echo "   Edit with: nano config/vocoder.yaml"
    echo "   Then restart: systemctl --user restart vocoder.service"
else
    echo "   - Using defaults (same as Option A)"
fi
echo ""

echo "======================================"