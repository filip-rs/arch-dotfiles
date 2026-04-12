#!/bin/bash
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
FILENAME="$SAVE_DIR/Screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

SLURP_ARGS="-b 1B1F2844 -c E06B74ff -s C778DD0D -w 2"
GEOMETRY=$(slurp $SLURP_ARGS) || exit 0
grim -g "$GEOMETRY" "$FILENAME"

if [ -s "$FILENAME" ]; then
    notify-send -a "Screenshot" -i "$FILENAME" "Screenshot Saved" "$(basename "$FILENAME")"
fi
