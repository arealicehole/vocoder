#!/usr/bin/env bash
# Wayland-safe GNOME hotkeys for Vocoder (toggle/start/stop)
# Usage: ./scripts/gnome_hotkey.sh
set -euo pipefail

VOCODERCTL="${HOME}/whisper-dictation/vocoderctl"
if [[ ! -x "$VOCODERCTL" ]]; then
  echo "Error: $VOCODERCTL not found or not executable." >&2
  exit 1
fi

SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
K_TOGGLE="$BASE/custom-vocoder-toggle/"
K_START="$BASE/custom-vocoder-start/"
K_STOP="$BASE/custom-vocoder-stop/"

# Desired bindings
BIND_TOGGLE='<Super><Shift>d'
BIND_START='<Super><Shift>s'
BIND_STOP='<Super><Shift>x'

# Read current list (gsettings returns a Python-ish list)
current="$(gsettings get ${SCHEMA} custom-keybindings)"

# Function: ensure a path is present in the custom-keybindings list
ensure_path() {
  local path="$1"
  if [[ "$current" == *"'$path'"* ]]; then
    return 0
  fi
  if [[ "$current" == "@as []" || "$current" == "[]" ]]; then
    current="['$path']"
  else
    # Insert before final ]
    current="${current%]*}, '$path']"
  fi
}

ensure_path "$K_TOGGLE"
ensure_path "$K_START"
ensure_path "$K_STOP"

# Write merged list back
gsettings set "${SCHEMA}" custom-keybindings "$current"

# Helper to set one binding triple
set_binding() {
  local key_path="$1" name="$2" cmd="$3" bind="$4"
  gsettings set ${SCHEMA}.custom-keybinding:"$key_path" name "$name"
  gsettings set ${SCHEMA}.custom-keybinding:"$key_path" command "$cmd"
  gsettings set ${SCHEMA}.custom-keybinding:"$key_path" binding "$bind"
}

set_binding "$K_TOGGLE" "Vocoder Toggle" "$VOCODERCTL toggle" "$BIND_TOGGLE"
set_binding "$K_START"  "Vocoder Start"  "$VOCODERCTL start"  "$BIND_START"
set_binding "$K_STOP"   "Vocoder Stop"   "$VOCODERCTL stop"   "$BIND_STOP"

echo "Hotkeys configured:"
echo "  Toggle: $BIND_TOGGLE -> $VOCODERCTL toggle"
echo "  Start:  $BIND_START  -> $VOCODERCTL start"
echo "  Stop:   $BIND_STOP   -> $VOCODERCTL stop"