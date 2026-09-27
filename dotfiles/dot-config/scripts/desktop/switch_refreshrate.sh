#!/usr/bin/env bash
# Toggle the laptop panel between 60 Hz and 120 Hz.
# Bound to SUPER + CTRL + SHIFT + 6.

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-refreshrate"
mkdir -p "$(dirname "$STATE_FILE")"

[ -f "$STATE_FILE" ] || echo "60" > "$STATE_FILE"
STATE=$(cat "$STATE_FILE")

if [ "$STATE" = "60" ]; then
    RATE=120
else
    RATE=60
fi

hyprctl eval "hl.monitor({ output = 'eDP-1', mode = '1920x1200@${RATE}', position = '0x0', scale = 1 })"
notify-send "Set refreshrate to ${RATE}hz"
echo "$RATE" > "$STATE_FILE"
