#!/bin/bash

STATE_FILE="$HOME/.config/hypr/scripts/toggle_state"

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "60" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [ "$STATE" = "60" ]; then
    hyprctl keyword monitor "eDP-1, 1920x1200@120, 0x0"
    notify-send "Set refreshrate to 120hz"

    echo "120" > "$STATE_FILE"

else
    hyprctl keyword monitor "eDP-1, 1920x1200@60, 0x0"
    notify-send "Set refreshrate to 60hz"

    echo "60" > "$STATE_FILE"
fi




