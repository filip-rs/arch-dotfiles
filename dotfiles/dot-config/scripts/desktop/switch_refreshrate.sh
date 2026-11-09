#!/usr/bin/env bash
# Toggle the laptop panel between 60 Hz and 120 Hz, keeping its current
# resolution, position and scale. Bound to SUPER + CTRL + SHIFT + 6.

source "$HOME/.config/scripts/lib/compositor.sh"

OUTPUT="eDP-1"

read -r WIDTH HEIGHT RATE X Y SCALE < <(monitors_json | jq -r --arg o "$OUTPUT" \
    '.[] | select(.name == $o) | "\(.width) \(.height) \(.refreshRate | round) \(.x) \(.y) \(.scale)"')
[ -n "$RATE" ] || { notify-send "Refresh rate" "$OUTPUT not found"; exit 1; }

if [ "$RATE" -gt 90 ]; then NEW=60; else NEW=120; fi

set_output "$OUTPUT" "${WIDTH}x${HEIGHT}@${NEW}" "$X" "$Y" "$SCALE"
notify-send "Set refreshrate to ${NEW}hz"
