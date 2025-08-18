#!/usr/bin/env bash
# setup-keybinding.sh - Configure GNOME keybinding for vocoder dictation

set -euo pipefail

# Get the absolute path to the dictation script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/whisper-dictate.sh"

# Check if script exists
if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: whisper-dictate.sh not found at $SCRIPT_PATH"
    exit 1
fi

# Make sure script is executable
chmod +x "$SCRIPT_PATH"

# Define keybinding path
KEYBIND_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/vocoder/"
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"

echo "Setting up GNOME keybinding for Vocoder..."
echo "Script path: $SCRIPT_PATH"
echo "Keybinding: Super+D"

# Get existing custom keybindings
EXISTING=$(gsettings get ${SCHEMA} custom-keybindings 2>/dev/null || echo "@as []")

# Add our binding if not present
if [[ "$EXISTING" != *"$KEYBIND_PATH"* ]]; then
    if [[ "$EXISTING" == "@as []" ]] || [[ "$EXISTING" == "[]" ]]; then
        NEW="['$KEYBIND_PATH']"
    else
        # Remove closing bracket and add our path
        NEW="${EXISTING%]}, '$KEYBIND_PATH']"
    fi
    gsettings set ${SCHEMA} custom-keybindings "$NEW"
    echo "✓ Added vocoder to custom keybindings list"
else
    echo "✓ Vocoder already in custom keybindings list"
fi

# Configure the keybinding details
gsettings set ${SCHEMA}.custom-keybinding:"$KEYBIND_PATH" name 'Vocoder Dictation'
gsettings set ${SCHEMA}.custom-keybinding:"$KEYBIND_PATH" command "$SCRIPT_PATH"
gsettings set ${SCHEMA}.custom-keybinding:"$KEYBIND_PATH" binding '<Super>d'

echo ""
echo "✅ Keybinding configured successfully!"
echo ""
echo "Usage:"
echo "  • Press Super+D to start dictation"
echo "  • Speak naturally"
echo "  • Stop speaking for 2 seconds to trigger transcription"
echo "  • Text will be typed at cursor position"
echo ""
echo "To test manually:"
echo "  $SCRIPT_PATH"
echo ""
echo "To remove keybinding:"
echo "  gsettings reset-recursively ${SCHEMA}.custom-keybinding:$KEYBIND_PATH"