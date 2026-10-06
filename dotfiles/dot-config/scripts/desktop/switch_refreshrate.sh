#!/usr/bin/env bash
# Toggle the laptop panel between 60 Hz and 120 Hz.
# Bound to SUPER + CTRL + SHIFT + 6.

source "$HOME/.config/scripts/lib/compositor.sh"

OUTPUT="eDP-1"

CURRENT=$(monitors_json | jq --arg o "$OUTPUT" '.[] | select(.name == $o) | .refreshRate | round')
[ -n "$CURRENT" ] || { notify-send "Refresh rate" "$OUTPUT not found"; exit 1; }

if [ "$CURRENT" -gt 90 ]; then
    RATE=60
else
    RATE=120
fi

set_output "$OUTPUT" "1920x1200@${RATE}" 0 0 1
notify-send "Set refreshrate to ${RATE}hz"
